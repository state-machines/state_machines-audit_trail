# frozen_string_literal: true

module StateMachines
  module AuditTrail
    Backend = Struct.new(:transition_class, :owner_class, :options) do
      autoload :ActiveRecord, 'state_machines/audit_trail/backend/active_record'

      #
      # Resolve field values and #persist
      #   - object: the object being watched by the state_machines observer
      #   - transition: state machine transition object that state machine passes to after/before transition callbacks
      #
      def log(object, transition)
        namespace = if transition.machine.presence
                      # full transition object
                      transition.machine.namespace
                    else
                      # initial state open struct
                      transition.namespace
                    end
        fields = { namespace: namespace, event: transition.event&.to_s, from: transition.from,
                   to: transition.to }
        [*options[:context]].each do |field|
          fields[field] = resolve_context(object, field, transition)
        end

        # begin
        persist(object, fields)
        # rescue => e
        #   puts "\nUncaught #{e.class} persisting audit_trail: #{e.message}"
        #   puts "\t" + e.backtrace.join($/ + "\t")
        #   raise e
        # end
      end

      #
      # Creates an instance of the Backend class which does the actual persistence of transition state information.
      #   - transition_class: the Class which holds the audit trail
      #
      # To add a new ORM, implement something similar to lib/state_machines/audit_trail/backend/active_record.rb
      # and return from here the appropriate object based on which ORM the transition_class is using
      #
      def self.create_for(transition_class, owner_class, options = {})
        unless Object.const_defined?('ActiveRecord') && transition_class.ancestors.include?(::ActiveRecord::Base)
          raise 'Only ActiveRecord is supported. transition_class must inherit from ActiveRecord::Base.'
        end

        StateMachines::AuditTrail::Backend::ActiveRecord.new(transition_class, owner_class, options)
      end

      # Exists in case ORM layer has a different way of answering this question, but works for most.
      def new_record?(object)
        object.new_record?
      end

      protected

      def persist(_object, _fields)
        raise 'Not implemented. Implement in a subclass.'
      end

      def resolve_context(object, context, transition)
        if object.method(context).arity.zero?
          object.send(context)
        else
          object.send(context, transition)
        end
      end
    end
  end
end
