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
# records, inside that save's database transaction (see Owner):
#
# * audit_trail registers a before_transition that notes every transition
#   started on the record in its Journal, in order across machines.  Before
#   callbacks run on every path that changes state, including the preview a
#   validation runs for a transition generated mid-save.
# * The owner's +after_save+ writes a row for every noted transition whose
#   state change is in place (Transition#persisted?), whichever machine it
#   belongs to and whether or not that save was its action.  A refused or
#   rolled back transition never is, so nothing halting or raising before or
#   after the change can make the trail disagree with the saved state.
# * The owner's +after_create+ writes each machine's null => initial entry,
#   from the state before its first persisted transition.
# * A row that cannot be written fails the save with RecordNotAudited (an
#   ActiveRecord::RecordNotSaved), which rolls back the save - and any
#   transaction enclosing it - instead of returning false from a save whose
#   UPDATE an enclosing transaction would still commit.
#
module StateMachines
  module AuditTrail
    module TransitionAuditing
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
        before_transition { |object, transition| Journal.of(object).note(transition) }
        # Best effort: keeps the journal from collecting refused transitions
        # (correctness rests on Transition#persisted?, not on this running)
        after_failure { |object, transition| Journal.of(object).forget(transition) }

        Owner.install(owner_class)
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

      # The null => initial entry: the state before this machine's first
      # transition whose state change is in place, else the state the record
      # is created in
      def audit_initial(object)
        return unless @audit_trail_options[:initial] && !action.nil? && audit_loggable?(object)

        first = Journal.of(object).first_persisted(name)
        initial = first ? first.from : read(object, :state)
        backend.log(object, Journal::InitialTransition.new(namespace: namespace, to: initial)) unless initial.nil?
      end

      def audit_write(object, transition)
        backend.log(object, transition) if audit_loggable?(object, transition)
      end

      # The :if option, given the transition's event arguments (none for the initial entry)
      def audit_loggable?(object, transition = nil)
        condition = @audit_trail_options[:if]
        condition.nil? || evaluate_method_with_event_args(object, condition, transition&.args || [])
      end

      def default_transition_class
        owner_class_or_base_class = owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
        name = "#{owner_class_or_base_class.name}#{attribute.to_s.camelize}Transition"
        name.constantize
      end
    end
  end
end
