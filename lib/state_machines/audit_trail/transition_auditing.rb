#
# This module inserts hooks into the state machine.
# The transition_class is the class (optionally specified with the :class option) for the model which
# records audit information from one single transition i.e. SubscriptionStateTransition.
#
# Multiple `SubscriptionStateTransition`s compose the 'audit_trail'.
#
module StateMachines::AuditTrail::TransitionAuditing
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
  #
  def audit_trail(options = {})
    state_machine = self
    if options[:class].presence
      raise ":class option[#{options[:class]}] must be a class (not a string)." unless options[:class].is_a? Class
    end
    transition_class = options[:class] || default_transition_class
    owner_class = options[:owner_class] || self.owner_class

    # backend implements #log to store transition information
    @backend = StateMachines::AuditTrail::Backend.create_for(transition_class, owner_class, options.slice(:context, :as))

    # Initial state logging can be turned off. Very useful for a model with multiple state_machines using a single TransitionState object for logging
    unless options[:initial] == false
      unless state_machine.action == nil
        # Log the initial transition from null => initial (upon object instantiation)
        state_machine.owner_class.after_initialize do |object|
          if state_machine.backend.new_record? object
            current_state = object.send(state_machine.attribute)
            if !current_state.nil?
              state_machine.backend.log(object, InitialTransition.new(namespace: state_machine.namespace, to: current_state))
            end
          end
        end
      end
    end

    # Log any transition (other than initial)
    state_machine.after_transition do |object, transition|
      state_machine.backend.log(object, transition)
    end
  end

  # Public returns an instance of the class which does the actual audit trail logging
  def backend
    @backend
  end

  private

  def default_transition_class
    owner_class_or_base_class = owner_class.respond_to?(:base_class) ? owner_class.base_class : owner_class
    name = "#{owner_class_or_base_class.name}#{attribute.to_s.camelize}Transition"
    name.constantize
  end
end
