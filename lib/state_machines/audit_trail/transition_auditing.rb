# frozen_string_literal: true

#
# This module inserts hooks into the state machine.
# The transition_class is the class (optionally specified with the :class option) for the model which
# records audit information from one single transition i.e. SubscriptionStateTransition.
#
# Multiple `SubscriptionStateTransition`s compose the 'audit_trail'.
#
module StateMachines
  module AuditTrail
    module TransitionAuditing
      class InitialTransition
        attr_reader :namespace, :to

        def initialize(namespace:, to:)
          @namespace = namespace
          @to = to
        end

        def from
          nil
        end

        def event
          nil
        end

        def machine
          nil
        end

        def args
          nil
        end
      end

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
        state_machine = self
        if options[:class].presence && !options[:class].is_a?(Class)
          raise ":class option[#{options[:class]}] must be a class (not a string)."
        end

        transition_class = options[:class] || default_transition_class
        owner_class = options[:owner_class] || self.owner_class

        # backend implements #log to store transition information
        @backend = StateMachines::AuditTrail::Backend.create_for(transition_class, owner_class,
                                                                 options.slice(:context, :as))

        # Initial state logging can be turned off. Very useful for a model with multiple state_machines
        # using a single TransitionState object for logging
        if options[:initial] != false && !state_machine.action.nil?
          # Log the initial transition from null => initial.
          #
          # This hook runs on `before_create` (i.e. right before the object is actually
          # INSERTed) rather than `after_initialize`. `after_initialize` fires at `.new`
          # time, before user code has a chance to mutate any attribute that a `:context`
          # option might depend on - resolving context there bakes in stale values (see
          # issue #22). `before_create` only ever fires once, immediately before the first
          # successful INSERT of a new record, so it naturally never fires for records
          # loaded from the database, and still only logs the initial transition exactly
          # once per object - same guarantee `after_initialize` + the new_record? guard
          # provided, just resolved at the right time.
          state_machine.owner_class.before_create do |object|
            state_machine.send(:log_initial_transition, options, object)
          end
        end

        # Log any transition (other than initial)
        after_transition_args = { if: options[:if] }.compact
        state_machine.after_transition(after_transition_args) do |object, transition|
          state_machine.backend.log(object, transition)
        end
      end

      # Public returns an instance of the class which does the actual audit trail logging
      def backend
        @backend
      end

      private

      # Logs the null => initial state transition for a brand-new record, called from
      # the `before_create` hook set up in `audit_trail`. Resolving :context here (at
      # save time) rather than at `.new` time is the whole point of using before_create
      # instead of after_initialize - see the comment at the call site.
      def log_initial_transition(options, object)
        current_state = object.send(attribute)
        return if current_state.nil?

        should_log_transition = options[:if].nil? || evaluate_method(object, options[:if])
        return unless should_log_transition

        backend.log(object, InitialTransition.new(namespace: namespace, to: current_state))
      end

      def default_transition_class
        owner_class_or_base_class = owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
        name = "#{owner_class_or_base_class.name}#{attribute.to_s.camelize}Transition"
        name.constantize
      end
    end
  end
end
