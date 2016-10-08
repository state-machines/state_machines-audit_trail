class StateMachines::AuditTrail::Backend < Struct.new(:transition_class, :owner_class, :context)

  autoload :Mongoid, 'state_machines/audit_trail/backend/mongoid'
  autoload :ActiveRecord, 'state_machines/audit_trail/backend/active_record'

  #
  # Resolve field values and #persist
  #   - object: the object being watched by the state_machines observer
  #   - transition: state machine transition object that state machine passes to after/before transition callbacks
  #
  def log(object, transition)

    if transition.machine.presence
      # full transition object
      namespace = transition.machine.namespace
    else
      # initial state open struct
      namespace = transition.namespace
    end
    fields = {namespace: namespace, event: transition.event ? transition.event.to_s : nil, from: transition.from, to: transition.to}
    [context].flatten(1).each { |field|
      fields[field] = resolve_context(object, field, transition)
    } unless self.context.nil?

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
    if Object.const_defined?('ActiveRecord') && transition_class.ancestors.include?(::ActiveRecord::Base)
      return StateMachines::AuditTrail::Backend::ActiveRecord.new(transition_class, owner_class, options)
    elsif Object.const_defined?('Mongoid') && transition_class.ancestors.include?(::Mongoid::Document)
      return StateMachines::AuditTrail::Backend::Mongoid.new(transition_class, owner_class, options)
    else
      raise 'Not implemented. Only support for ActiveRecord and Mongoid is implemented. Pull requests welcome.'
    end
  end

  # Exists in case ORM layer has a different way of answering this question, but works for most.
  def new_record?(object)
    object.new_record?
  end

  protected

  def persist(object, fields)
    raise 'Not implemented. Implement in a subclass.'
  end

  def resolve_context(object, context, transition)
    if object.method(context).arity != 0
      object.send(context, transition)
    else
      object.send(context)
    end
  end
end
