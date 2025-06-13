# frozen_string_literal: true

# reset integrations so that something like Mongoid is not loaded and conflicting
require 'state_machines'
StateMachines::Integrations.reset

require 'test_helper'
require 'state_machines-activerecord'
require 'helpers/active_record'

class ActiveRecordBackendTest < Minitest::Test
  def test_initial_option_default_new_object
    target = ARModel.new
    # initial transition is built but not saved
    assert_predicate target, :new_record?
    assert_equal 0, target.ar_model_state_transitions.count
    target.save!

    # initial transition is saved and should be present
    refute_predicate target, :new_record?
    assert_equal 1, target.ar_model_state_transitions.count
    state_transition = target.ar_model_state_transitions.first

    assert_transition state_transition, nil, nil, 'waiting'
  end

  def test_initial_option_default_create_object
    target = ARModel.create!
    # initial transition is saved and should be present
    refute_predicate target, :new_record?
    assert_equal 1, target.ar_model_state_transitions.count
    state_transition = target.ar_model_state_transitions.first

    assert_transition state_transition, nil, nil, 'waiting'

    # ensure we don't have a second initial state transition logged (issue #4)
    target = target.reload

    assert_equal 1, target.ar_model_state_transitions.count
    state_transition = target.ar_model_state_transitions.first

    assert_transition state_transition, nil, nil, 'waiting'
  end

  def test_initial_option_false_skips_log
    target = ARModelNoInitial.new
    # initial transition is not-built
    assert_predicate target, :new_record?
    assert_equal 0, target.ar_model_no_initial_state_transitions.count
    target.save!

    # after save, initial transition is not-saved
    refute_predicate target, :new_record?
    assert_equal 0, target.ar_model_no_initial_state_transitions.count
  end

  def test_namespaced_state_machine_should_log_namespace
    target = ARModelWithNamespace.create!

    # initial transition is saved and should be present
    refute_predicate target, :new_record?
    assert_equal 1, target.ar_model_with_namespace_foo_state_transitions.count
    state_transition = target.ar_model_with_namespace_foo_state_transitions.first

    assert_equal 'foo', state_transition.namespace
    assert_nil state_transition.from
    assert_equal 'waiting', state_transition.to
    assert_nil state_transition.event
  end

  def test_namespaced_state_machine_should_not_log_namespace_for_default
    target = ARModel.create!

    refute_predicate target, :new_record?
    assert_equal 1, target.ar_model_state_transitions.count
    state_transition = target.ar_model_state_transitions.first

    assert_nil state_transition.namespace
    assert_nil state_transition.from
    assert_equal 'waiting', state_transition.to
    assert_nil state_transition.event
  end

  def test_create_for_should_be_backend_active_record
    backend = StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModel)

    assert_instance_of StateMachines::AuditTrail::Backend::ActiveRecord, backend
  end

  def test_create_for_should_create_has_many_association
    StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModel)

    assert_predicate ARModel.reflect_on_association(:ar_model_state_transitions), :collection?
  end

  def test_create_for_should_handle_models_within_modules
    StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, SomeModule::ARModel)

    assert_predicate SomeModule::ARModel.reflect_on_association(:ar_model_state_transitions), :collection?
  end

  def test_create_for_should_handle_state_transition_models_within_modules
    StateMachines::AuditTrail::Backend.create_for(SomeModule::ARModelStateTransition, ARModel)

    assert_predicate ARModel.reflect_on_association(:ar_model_state_transitions), :collection?
  end

  def test_single_state_machine_created_model_should_populate_all_fields
    target = ARModelWithContext.create!

    assert_equal :waiting, target.state_name
    target.start!

    assert_equal :started, target.state_name

    last_transition = ARModelWithContextStateTransition.where(ar_model_with_context_id: target.id).last

    refute_nil last_transition
    assert_equal 'start', last_transition.event
    assert_equal 'waiting', last_transition.from
    assert_equal 'started', last_transition.to
    refute_nil last_transition.context
    assert_in_delta Time.now.utc, last_transition.created_at, 10
  end

  def test_single_state_machine_created_model_should_do_nothing_on_failed_transition
    target = ARModelWithContext.create!
    initial_count = ARModelWithContextStateTransition.count
    begin
      target.stop
    rescue StandardError
      nil
    end

    assert_equal initial_count, ARModelWithContextStateTransition.count
  end

  def test_single_state_machine_created_model_should_log_multiple_events
    target = ARModelWithContext.create!
    initial_count = ARModelWithContextStateTransition.count
    target.start && target.stop && target.start

    assert_equal initial_count + 3, ARModelWithContextStateTransition.count
  end

  def test_single_state_machine_new_model_should_populate_all_fields
    target = ARModelWithContext.new

    assert_equal :waiting, target.state_name
    target.start!

    assert_equal :started, target.state_name

    last_transition = ARModelWithContextStateTransition.where(ar_model_with_context_id: target.id).last

    refute_nil last_transition
    assert_equal 'start', last_transition.event
    assert_equal 'waiting', last_transition.from
    assert_equal 'started', last_transition.to
    refute_nil last_transition.context
    assert_in_delta Time.now.utc, last_transition.created_at, 10
  end

  def test_single_state_machine_new_model_should_log_multiple_events_including_first_save
    target = ARModelWithContext.new
    initial_count = ARModelWithContextStateTransition.count
    target.start && target.stop && target.start

    assert_equal initial_count + 4, ARModelWithContextStateTransition.count
  end

  def test_single_context_logging
    StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModelWithContext,
                                                  context: :context)
    target = ARModelWithContext.create!

    target.start!
    last_transition = ARModelWithContextStateTransition.where(ar_model_with_context_id: target.id).last

    assert_equal target.context, last_transition.context
  end

  def test_multiple_context_logging
    StateMachines::AuditTrail::Backend.create_for(ARModelWithMultipleContextStateTransition,
                                                  ARModelWithMultipleContext, context: %i[context second_context context_with_args])
    target = ARModelWithMultipleContext.create!

    target.start!
    last_transition = ARModelWithMultipleContextStateTransition.where(ar_model_with_multiple_context_id: target.id).last

    assert_equal target.context, last_transition.context
    assert_equal target.second_context, last_transition.second_context
  end

  def test_multiple_context_logging_with_arguments
    StateMachines::AuditTrail::Backend.create_for(ARModelWithMultipleContextStateTransition,
                                                  ARModelWithMultipleContext, context: %i[context second_context context_with_args])
    target = ARModelWithMultipleContext.create!

    target.start!('one', 'two', 'three', 'for', id: 1)
    last_transition = ARModelWithMultipleContextStateTransition.where(ar_model_with_multiple_context_id: target.id).last

    assert_equal '1', last_transition.context_with_args
  end

  def test_multiple_state_machines_should_log_for_affected_machine
    target = ARModelWithMultipleStateMachines.create!
    initial_count = ARModelWithMultipleStateMachinesFirstTransition.count
    target.begin_first!

    assert_equal initial_count + 1, ARModelWithMultipleStateMachinesFirstTransition.count
  end

  def test_multiple_state_machines_should_not_log_for_unaffected_machine
    target = ARModelWithMultipleStateMachines.create!
    initial_count = ARModelWithMultipleStateMachinesSecondTransition.count
    target.begin_first!

    assert_equal initial_count, ARModelWithMultipleStateMachinesSecondTransition.count
  end

  def test_with_initial_state_should_log_transition
    target_class = ARModelWithMultipleStateMachines
    state_transition_class = ARModelWithMultipleStateMachinesFirstTransition
    initial_count = state_transition_class.count
    target_class.create!

    assert_equal initial_count + 1, state_transition_class.count
  end

  def test_with_initial_state_should_only_set_to_state_for_initial_transition
    target_class = ARModelWithMultipleStateMachines
    state_transition_class = ARModelWithMultipleStateMachinesFirstTransition
    target_class.create!
    initial_transition = state_transition_class.last

    assert_nil initial_transition.event
    assert_nil initial_transition.from
    assert_equal 'beginning', initial_transition.to
    assert_in_delta Time.now.utc, initial_transition.created_at, 10
  end

  def test_without_initial_state_should_not_log_on_create
    target_class = ARModelWithMultipleStateMachines
    state_transition_class = ARModelWithMultipleStateMachinesSecondTransition
    initial_count = state_transition_class.count
    target_class.create!

    assert_equal initial_count, state_transition_class.count
  end

  def test_without_initial_state_should_log_first_event
    target_class = ARModelWithMultipleStateMachines
    state_transition_class = ARModelWithMultipleStateMachinesSecondTransition
    initial_count = state_transition_class.count
    target_class.create.begin_second!

    assert_equal initial_count + 1, state_transition_class.count
  end

  def test_without_initial_state_should_not_set_from_state_on_first_transition
    target_class = ARModelWithMultipleStateMachines
    state_transition_class = ARModelWithMultipleStateMachinesSecondTransition
    target_class.create.begin_second!
    first_transition = state_transition_class.last

    assert_equal 'begin_second', first_transition.event
    assert_nil first_transition.from
    assert_equal 'beginning_second', first_transition.to
    assert_in_delta Time.now.utc, first_transition.created_at, 10
  end

  def test_action_nil_state_machine_transition_before_save
    target_class = ARModelWithMultipleStateMachines
    initial_count = ARModelWithMultipleStateMachinesThirdTransition.count
    machine = target_class.new
    machine.begin_third
    machine.save!

    assert_equal initial_count + 1, ARModelWithMultipleStateMachinesThirdTransition.count
  end

  def test_action_nil_state_machine_queue_transitions_before_save
    target_class = ARModelWithMultipleStateMachines
    initial_count = ARModelWithMultipleStateMachinesThirdTransition.count
    machine = target_class.new
    machine.begin_third
    machine.end_third
    machine.save!

    assert_equal initial_count + 2, ARModelWithMultipleStateMachinesThirdTransition.count
  end

  def test_sti_resolve_class_name
    m = ARModelDescendant.create!
    initial_count = ARModelStateTransition.count
    m.start!

    # Should create audit trail record for STI model
    assert_equal initial_count + 1, ARModelStateTransition.count
    transition = ARModelStateTransition.last

    assert_equal 'start', transition.event
    assert_equal 'waiting', transition.from
    assert_equal 'started', transition.to
  end

  def test_sti_resolve_class_name_on_own_state_machine
    m = ARModelDescendantWithOwnStateMachines.create!

    assert_equal 'new', m.state

    # Should successfully transition without raising errors (STI class name resolution)
    m.complete!

    assert_equal 'completed', m.state
  end

  def test_polymorphic_creates_polymorphic_state_transitions
    m1 = ARFirstModelWithPolymorphicStateTransition.create!
    m2 = ARSecondModelWithPolymorphicStateTransition.create!
    m2.start!
    m2.finish!

    assert_equal 1, m1.ar_resource_state_transitions.count
    assert_equal 3, m2.ar_resource_state_transitions.count
    assert_equal 4, ARResourceStateTransition.count
  end

  private

  def assert_transition(state_transition, event, from, to)
    if event.nil?
      assert_nil state_transition.event
    else
      assert_equal event, state_transition.event
    end

    if from.nil?
      assert_nil state_transition.from
    else
      assert_equal from, state_transition.from
    end

    assert_equal to, state_transition.to
  end
end
