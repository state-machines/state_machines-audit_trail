require 'state_machines-mongoid'

#
# Populate and persist the state transition to Mongoid
#
class StateMachines::AuditTrail::Backend::Mongoid < StateMachines::AuditTrail::Backend

  def persist(object, fields)
    foreign_key_field = transition_class.relations.keys.first
    fields = fields.merge({foreign_key_field => object, created_at: Time.now})
    transition_class.create(fields)
  end
end
