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
# An audit row is written by the owner save that writes the state change it
# records, inside that save's database transaction, so the two land together
# or not at all:
#
# * audit_trail registers a before_transition that notes every transition
#   started on the record.  Before callbacks run on every path that changes
#   state, including the preview a validation runs for a transition generated
#   mid-save (whose around callbacks only run after the save).
# * The owner's +after_save+ writes each noted transition whose state change
#   is in place (Transition#persisted?): the transition the save is the action
#   of, one generated during the save, and any committed earlier without a save
#   (a machine without an action, <tt>event(false)</tt>).  A transition refused
#   before its state change, or rolled back, is never persisted, so no
#   callback halting or raising - before or after the change - can make the
#   trail disagree with the state saved.
# * The null => initial entry of a new record is written from the owner's
#   +after_create+, on every create attempt, from the state the record had
#   before its first transition.  A rolled back attempt takes its rows with it
#   and leaves the record new, so +:if+ and +:context+ are evaluated for the
#   attempt that writes them.
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
        before_transition { |object, transition| transition.machine.send(:audit_note, object, transition) }

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

      # The before callback: notes the transition for the save that writes it.
      # Another copy of this callback (a parent's, cloned into a subclass's
      # machine) may already have noted it.  An earlier attempt that never
      # changed the state is over: an attempt runs to its outcome before the
      # next on the same machine starts.
      def audit_note(object, transition)
        noted = audit_trail_of(object).noted
        return if noted.any? { |earlier| earlier.equal?(transition) }

        noted.select!(&:persisted?)
        noted << transition
      end

      # Owner after_create: the null => initial entry.  The state before the
      # first transition that changed it, else the state the record is
      # created in.
      def audit_owner_created(object)
        return unless @audit_trail_options[:initial] && !action.nil? && audit_loggable?(object)

        first = audit_trail_of(object).noted.find(&:persisted?)
        initial = first ? first.from : read(object, :state)
        backend.log(object, Trails::InitialTransition.new(namespace: namespace, to: initial)) unless initial.nil?
      end

      # Owner after_save: every noted transition whose state change this save
      # writes, oldest first, once per database transaction.
      def audit_owner_saved(object)
        trail = audit_trail_of(object)
        pending = trail.noted.select { |transition| transition.persisted? && !trail.written?(transition) }
        pending.each do |transition|
          backend.log(object, transition) if audit_loggable?(object, transition)
          trail.written << transition
        end
      end

      # Owner after_commit: the written transitions are recorded for good
      def audit_owner_committed(object)
        trail = audit_trail_of(object)
        trail.noted.reject! { |transition| trail.written?(transition) }
        trail.written.clear
      end

      # Owner after_rollback: the rows went with the transaction; a transition
      # still in place is written again by the save that writes its state
      def audit_owner_rolled_back(object)
        audit_trail_of(object).written.clear
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
        owner_class.after_commit { |object| dispatch.call(object, :audit_owner_committed) }
        owner_class.after_rollback { |object| dispatch.call(object, :audit_owner_rolled_back) }
      end

      def default_transition_class
        owner_class_or_base_class = owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
        name = "#{owner_class_or_base_class.name}#{attribute.to_s.camelize}Transition"
        name.constantize
      end
    end
  end
end
