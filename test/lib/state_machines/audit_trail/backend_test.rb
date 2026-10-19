# frozen_string_literal: true

require 'test_helper'
require 'state_machines-activerecord'
require 'helpers/active_record'

class BackendTest < Minitest::Test
  # Stand-in for a real StateMachines::Transition: exposes only the reader
  # methods that Backend#log touches (machine, namespace, event, from, to).
  TransitionStub = Struct.new(:namespace, :from, :to, :event, :machine)

  def setup
    AuditTrailTestSchema.create!
  end

  def test_log_removes_all_nil_attributes_from_fields
    backend = StateMachines::AuditTrail::Backend.new(ARModelWithContextStateTransition, ARModel, {})

    def backend.persist(object, fields)
      @captured = [object, fields]
    end

    transition = TransitionStub.new('foo', nil, 'waiting', nil, nil)

    backend.log(ARModel, transition)

    captured = backend.instance_variable_get(:@captured)

    refute_nil captured

    object, fields = captured

    assert_equal ARModel, object
    assert_equal({ namespace: 'foo', to: 'waiting' }, fields)
  end
end
