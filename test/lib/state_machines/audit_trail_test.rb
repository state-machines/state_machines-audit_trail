# frozen_string_literal: true

require 'test_helper'

class AuditTrailTest < Minitest::Test
  def test_should_include_auditing_module_into_state_machines_machine
    assert_includes StateMachines::Machine.included_modules, StateMachines::AuditTrail::TransitionAuditing
  end
end
