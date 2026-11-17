# frozen_string_literal: true

require 'state_machines'

module StateMachines
  module AuditTrail
    def self.setup
      StateMachines::Machine.include StateMachines::AuditTrail::TransitionAuditing
      StateMachines::TransitionCollection.prepend StateMachines::AuditTrail::CollectionGuard
    end
  end
end

require 'state_machines/audit_trail/version'
require 'state_machines/audit_trail/journal'
require 'state_machines/audit_trail/save'
require 'state_machines/audit_trail/owner'
require 'state_machines/audit_trail/collection_guard'
require 'state_machines/audit_trail/transition_auditing'
require 'state_machines/audit_trail/backend'
require 'state_machines/audit_trail/railtie' if defined?(Rails)

StateMachines::AuditTrail.setup
