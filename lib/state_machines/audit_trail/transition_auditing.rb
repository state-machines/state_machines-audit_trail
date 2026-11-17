# frozen_string_literal: true

#
# This module inserts hooks into the state machine.
# The transition_class is the class (optionally specified with the :class option) for the model which
# records audit information from one single transition i.e. SubscriptionStateTransition.
#
# Multiple `SubscriptionStateTransition`s compose the 'audit_trail'.
#
# == When an audit is written
#
# An audit is written for every transition that commits, at the point it
# commits, so no callback halting later can skip it:
#
# * A transition whose action is the owner's save is written from the
#   owner's +after_save+, inside the save's database transaction: the audit
#   and the state change are one write, and either both land or neither does.
#   Every after-phase callback (a branch +after:+, machine +after_transition+,
#   the code after an around's yield) runs once the action returned, so none
#   of them can skip it.
# * A transition committed without running that save (a machine without an
#   action, <tt>event(false)</tt>, a custom action) is written when the
#   around callback audit_trail registers unwinds - an +ensure+, which a
#   :halt thrown from an inner around after its yield passes through.  On a
#   persisted record it is written right away; on a new record it is held
#   until the record is created.
# * The null => initial entry of a new record is written from the owner's
#   +after_create+, on every create attempt, so its +:if+ and +:context+ are
#   evaluated for the attempt that writes it and nothing built by an aborted
#   or rolled back attempt survives into the next.
#
module StateMachines
  module AuditTrail
    module TransitionAuditing
      # Per-owner-class names of the machines whose owner callbacks are installed
      HOOKED = :@state_machines_audit_trail_hooked

      # Hook for audit_trail inside a a state_machine declaration.
      #
      # options:
      #   - :class - custom state transition class
      #   - :owner_class - the class which is to own the persisted transition objects
      #   - :context - methods to call/store in field of same name in the state transition class
      #   - :initial - if false, won't log null => initial state transition upon instantiation
      #   - :if - method/proc/symbol; only log transitions (initial and regular) when it evaluates truthy
      #
      def audit_trail(options = {})
        if options[:class].presence && !options[:class].is_a?(Class)
          raise ":class option[#{options[:class]}] must be a class (not a string)."
        end

        transition_class = options[:class] || default_transition_class
        audit_owner_class = options[:owner_class] || owner_class

        # backend implements #log to store transition information
        @backend = StateMachines::AuditTrail::Backend.create_for(transition_class, audit_owner_class,
                                                                 options.slice(:context, :as))
        # Read from the transition's machine at write time, so a machine cloned
        # into a subclass keeps auditing with the options it was cloned with
        @audit_trail_options = { initial: options[:initial] != false, if: options[:if] }.freeze

        # The transition's machine, not this one: a clone in a subclass also
        # carries this callback, and audits with its own backend
        around_transition do |object, transition, block|
          transition.machine.send(:audit_transition, object, transition, &block)
        end

        install_audit_owner_callbacks
      end

      # Public returns an instance of the class which does the actual audit trail logging
      def backend
        @backend
      end

      # Whether audit_trail was declared on this machine (or the one it was cloned from)
      def audit_trail?
        !@audit_trail_options.nil?
      end

      private

      # The around callback: tracks the transition while it runs, so the
      # owner's save can write it, and writes it on the way out if it committed
      # without that save.
      def audit_transition(object, transition)
        in_flight = audit_trail_of(object).in_flight
        # Another copy of this callback (a parent's, cloned into a subclass's
        # machine) already tracks it
        return yield if in_flight.any? { |tracked| tracked.equal?(transition) }

        in_flight << transition
        raised = false
        begin
          yield
        rescue Exception # rubocop:disable Lint/RescueException -- tells a raise apart from a :halt, then re-raises
          raised = true
          raise
        ensure
          # Still tracked unless the owner's save already wrote it
          unwritten = in_flight.reject! { |tracked| tracked.equal?(transition) }
          audit_committed(object, transition) if unwritten && !raised && committed?(transition)
        end
      end

      # A transition committed without the owner's save writing it.  If its
      # audit cannot be written, the state change is undone before the error
      # propagates: no transition stands without its audit.
      def audit_committed(object, transition)
        if object.new_record?
          audit_trail_of(object).unsaved << Trails::UnsavedTransition.new(transition, audit_loggable?(object, transition))
        elsif audit_loggable?(object, transition)
          backend.log(object, transition)
        end
      rescue StandardError
        transition.rollback
        raise
      end

      # Whether the transition ran to success: its before chain completed and
      # its action, if run, succeeded.  Core keeps this private
      # (Transition#run_callbacks reports whether the before chain ran, which
      # stays true when the action fails), so it is read where core keeps it.
      def committed?(transition)
        transition.instance_variable_get(:@success) == true
      end

      # Owner after_create: the null => initial entry, then the transitions
      # committed while the record was new.  Runs on every create attempt;
      # an attempt rolled back takes its rows with it and leaves the record
      # new, so the next attempt writes them again.
      def audit_owner_created(object)
        trail = audit_trail_of(object)

        if @audit_trail_options[:initial] && !action.nil? && audit_loggable?(object)
          first = trail.unsaved.first&.transition || trail.in_flight.first
          initial = first ? first.from : read(object, :state)
          backend.log(object, Trails::InitialTransition.new(namespace: namespace, to: initial)) unless initial.nil?
        end

        trail.unsaved.each { |unsaved| backend.log(object, unsaved.transition) if unsaved.loggable }
      end

      # Owner after_save: the transitions this save commits.  A transition
      # tracked here whose state is not the one being saved has not been
      # persisted yet (a callback saving the record before the transition's
      # own save) and is left for its own save.
      def audit_owner_saved(object)
        in_flight = audit_trail_of(object).in_flight
        state = read(object, :state)
        saved, unsaved = in_flight.partition { |transition| transition.to == state }
        in_flight.replace(unsaved)
        saved.each { |transition| backend.log(object, transition) if audit_loggable?(object, transition) }
      end

      # Owner after_commit on create: the held transitions are written for good
      def audit_owner_create_committed(object)
        audit_trail_of(object).unsaved.clear
      end

      # The :if option, given the transition's event arguments (none for the initial entry)
      def audit_loggable?(object, transition = nil)
        condition = @audit_trail_options[:if]
        condition.nil? || evaluate_method_with_event_args(object, condition, transition&.args || [])
      end

      def audit_trail_of(object)
        Trails.of(object)[name]
      end

      # One set of owner callbacks per machine name and class hierarchy: each
      # dispatches to the machine the record's class has under that name, so a
      # subclass redefining (and re-auditing) the machine is not audited twice.
      def install_audit_owner_callbacks
        machine_name = name
        return if owner_class.ancestors.any? { |ancestor| ancestor.instance_variable_get(HOOKED)&.include?(machine_name) }

        hooked = owner_class.instance_variable_get(HOOKED) || owner_class.instance_variable_set(HOOKED, [])
        hooked << machine_name

        dispatch = lambda do |object, hook|
          machine = object.class.state_machines[machine_name]
          machine.send(hook, object) if machine.audit_trail?
        end
        owner_class.after_create { |object| dispatch.call(object, :audit_owner_created) }
        owner_class.after_save { |object| dispatch.call(object, :audit_owner_saved) }
        owner_class.after_commit(on: :create) { |object| dispatch.call(object, :audit_owner_create_committed) }
      end

      def default_transition_class
        owner_class_or_base_class = owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
        name = "#{owner_class_or_base_class.name}#{attribute.to_s.camelize}Transition"
        name.constantize
      end
    end
  end
end
