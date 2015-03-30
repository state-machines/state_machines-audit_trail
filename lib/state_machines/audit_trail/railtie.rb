class StateMachines::AuditTrail::Railtie < ::Rails::Railtie
  generators do
    require 'state_machines/audit_trail_generator'
  end
end
