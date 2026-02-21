# frozen_string_literal: true

module StateMachines
  module AuditTrail
    class Railtie < Rails::Railtie
      generators do
        require 'state_machines/audit_trail_generator'
      end
    end
  end
end
