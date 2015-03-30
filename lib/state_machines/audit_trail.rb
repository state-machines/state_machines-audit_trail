require 'state_machines'

module StateMachines
  module AuditTrail
    def self.setup
      StateMachines::Machine.send(:include, StateMachines::AuditTrail::TransitionAuditing)
    end
  end
end

require 'state_machines/audit_trail/version'
require 'state_machines/audit_trail/transition_auditing'
require 'state_machines/audit_trail/backend'
require 'state_machines/audit_trail/railtie' if defined?(::Rails)

StateMachines::AuditTrail.setup
