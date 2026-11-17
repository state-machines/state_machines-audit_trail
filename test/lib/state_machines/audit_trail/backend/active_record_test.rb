# frozen_string_literal: true

# reset integrations so that something like Mongoid is not loaded and conflicting
require 'state_machines'
StateMachines::Integrations.reset

require 'test_helper'
require 'state_machines-activerecord'
require 'helpers/active_record'

class ActiveRecordBackendTest < Minitest::Test
  def setup
    AuditTrailTestSchema.create!
  end

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

  def test_destroying_owner_should_destroy_state_transitions
    # Uses ARModelWithContext (rather than ARModel) because other tests in this file
    # deliberately call create_for(ARModelWithContextStateTransition, ARModel) with a
    # mismatched owner/transition pair to exercise create_for's naming logic. That leaves
    # a bogus has_many on ARModel for the remainder of the process. ARModelWithContext is
    # never touched by such a mismatched pairing, so this assertion isn't order-dependent.
    target = ARModelWithContext.create!
    target.start!
    target_id = target.id

    assert_equal 2, ARModelWithContextStateTransition.where(ar_model_with_context_id: target_id).count

    target.destroy

    assert_equal 0, ARModelWithContextStateTransition.where(ar_model_with_context_id: target_id).count
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

  def test_transition_table_without_namespace_column_does_not_raise
    target = ARModelWithoutNamespaceColumn.new
    # initial transition is built but not saved
    assert_predicate target, :new_record?
    assert_equal 0, target.ar_model_without_namespace_column_state_transitions.count

    target.save!

    refute_predicate target, :new_record?
    assert_equal 1, target.ar_model_without_namespace_column_state_transitions.count
    state_transition = target.ar_model_without_namespace_column_state_transitions.first

    assert_transition state_transition, nil, nil, 'waiting'
    refute_includes ARModelWithoutNamespaceColumnStateTransition.column_names, 'namespace'

    target.start!

    assert_equal :started, target.state_name
    assert_equal 2, target.ar_model_without_namespace_column_state_transitions.count
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

    refute target.stop

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
    target.start && target.stop && target.start

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started], %w[stop started stopped],
                  %w[start stopped started]], audit_rows(target)
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
    assert_equal [[nil, nil, 'beginning']], audit_rows(machine, ARModelWithMultipleStateMachinesFirstTransition)
    assert_equal [['begin_third', nil, 'beginning_third'], %w[end_third beginning_third done_third]],
                 audit_rows(machine, ARModelWithMultipleStateMachinesThirdTransition)
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
    # Logged once (to the base class's transitions), though the subclass's
    # machine carries both its own audit callbacks and those cloned from ARModel's
    assert_equal [[nil, nil, 'new'], %w[complete new completed]],
                 ARModelStateTransition.where(ar_model_id: m.id).order(:id).pluck(:event, :from, :to)
  end

  def test_sti_descendant_sharing_the_parent_machine_logs_once
    m = ARModelDescendant.new
    m.start!

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]],
                 ARModelStateTransition.where(ar_model_id: m.id).order(:id).pluck(:event, :from, :to)
  end

  def test_dup_of_new_record_does_not_share_held_transitions
    original = ARModelWithMultipleStateMachines.new
    original.begin_third
    copy = original.dup
    copy.save!
    original.save!

    assert_equal [['begin_third', nil, 'beginning_third']],
                 audit_rows(original, ARModelWithMultipleStateMachinesThirdTransition)
    assert_empty audit_rows(copy, ARModelWithMultipleStateMachinesThirdTransition)
  end

  def test_new_record_with_held_transitions_can_be_marshaled
    target = ARModelWithMultipleStateMachines.new
    target.begin_third

    assert_instance_of ARModelWithMultipleStateMachines, Marshal.load(Marshal.dump(target))
  end

  def test_context_is_resolved_at_save_time_not_at_new_time
    target = ARModelWithContextBasedOnOtherField.new(other_field: 'initial_other_field_value')
    # initial transition is built but not saved, so mutating the attribute
    # afterwards must still affect what gets logged.
    assert_predicate target, :new_record?
    assert_equal 0, target.ar_model_with_context_based_on_other_field_state_transitions.count

    target.other_field = 'real_other_field_value'
    target.save!

    last_transition = ARModelWithContextBasedOnOtherFieldStateTransition
                      .where(ar_model_with_context_based_on_other_field_id: target.id).last

    refute_nil last_transition
    assert_equal 'real_other_field_value', last_transition.context
    refute_equal 'initial_other_field_value', last_transition.context
  end

  def test_conditional_audit_trail_skips_initial_transition_when_condition_false
    # should_log_transition? is false while state is :waiting (the initial state)
    target = ARModelConditionalAuditTrail.create!

    assert_equal 0, target.ar_model_conditional_audit_trail_state_transitions.count
  end

  def test_conditional_audit_trail_skips_transition_when_condition_false
    target = ARModelConditionalAuditTrail.create!
    # start: waiting -> started; should_log_transition? is still false (state != 'stopped')
    target.start!

    assert_equal 'started', target.state
    assert_equal 0, target.ar_model_conditional_audit_trail_state_transitions.count
  end

  def test_conditional_audit_trail_logs_transition_when_condition_becomes_true
    target = ARModelConditionalAuditTrail.create!
    target.start!
    # stop: started -> stopped; should_log_transition? becomes true (state == 'stopped')
    target.stop!

    assert_equal 'stopped', target.state
    assert_equal 1, target.ar_model_conditional_audit_trail_state_transitions.count
    last_transition = target.ar_model_conditional_audit_trail_state_transitions.last

    assert_equal 'stop', last_transition.event
    assert_equal 'started', last_transition.from
    assert_equal 'stopped', last_transition.to
  end

  def test_invalid_audit_record_fails_and_rolls_back_the_transition
    target = ARModelWithValidatedContext.create!

    error = assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.start }
    assert_same target, error.record
    assert_includes error.audit_record.errors[:context], "can't be blank"
    assert_equal 'waiting', target.state
    refute_empty target.errors[:ar_model_with_validated_context_state_transitions]
    assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.start! }

    assert_equal 'waiting', target.reload.state
    assert_equal 0, ARModelWithValidatedContextStateTransition.where(ar_model_with_validated_context_id: target.id).count

    target.context = 'Some context'
    target.start!

    assert_equal 'started', target.reload.state
    rows = ARModelWithValidatedContextStateTransition.where(ar_model_with_validated_context_id: target.id)

    assert_equal [['start', 'waiting', 'started', 'Some context']], rows.order(:id).pluck(:event, :from, :to, :context)
  end

  def test_invalid_audit_record_without_the_action_fails_the_save_that_writes_it
    target = ARModelWithValidatedContext.create!

    assert target.start(false)
    assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.save }

    assert_equal 'waiting', target.reload.state
    assert_equal 0, ARModelWithValidatedContextStateTransition.where(ar_model_with_validated_context_id: target.id).count
  end

  def test_retried_create_logs_the_initial_transition_once
    target = ARModelAbortingFirstCreate.new(other_field: 'aborted_attempt')
    target.abort_create = true

    refute target.save

    target.other_field = 'successful_attempt'

    assert target.save

    transitions = ARModelAbortingFirstCreateStateTransition.where(ar_model_aborting_first_create_id: target.id)

    assert_equal 1, transitions.count
    assert_transition transitions.first, nil, nil, 'waiting'
    assert_equal 'successful_attempt', transitions.first.context
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

  def test_event_on_new_record_logs_the_initial_state_then_the_event
    target = ARModel.new
    target.start!

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_state_event_on_create_logs_the_initial_state_then_the_event
    target = ARModel.create!(state_event: 'start')

    assert_equal 'started', target.state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_state_event_validated_before_create_logs_the_initial_state_then_the_event
    target = ARModel.new(state_event: 'start')

    assert_predicate target, :valid?
    target.save!

    assert_equal 'started', target.state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_action_less_events_on_new_record_log_the_initial_state_then_each_event
    target = ARModelWithMultipleStateMachines.new
    target.begin_first(false)
    target.save!

    assert_equal 'end', target.first
    assert_equal [[nil, nil, 'beginning'], %w[begin_first beginning end]],
                 audit_rows(target, ARModelWithMultipleStateMachinesFirstTransition)
  end

  def test_branch_after_halt_does_not_skip_the_audit
    target = ARModelHaltingCallbacks.create!

    assert target.branch_after_halt

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[branch_after_halt waiting started]], audit_rows(target)
  end

  def test_machine_after_halt_declared_before_audit_trail_does_not_skip_the_audit
    target = ARModelHaltingCallbacks.create!

    assert target.machine_after_halt

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[machine_after_halt waiting started]], audit_rows(target)
  end

  def test_inner_around_halting_after_yield_does_not_skip_the_audit
    target = ARModelHaltingCallbacks.create!

    assert target.around_halt

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[around_halt waiting started]], audit_rows(target)
  end

  def test_inner_around_halting_after_yield_does_not_skip_the_audit_without_the_action
    target = ARModelHaltingCallbacks.create!

    assert target.around_halt(false)
    assert_equal 'started', target.state
    # Not saved yet: neither is the state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal [[nil, nil, 'waiting'], %w[around_halt waiting started]], audit_rows(target)
  end

  def test_after_halt_on_new_record_does_not_skip_the_audit
    target = ARModelHaltingCallbacks.new

    assert target.branch_after_halt

    assert_equal [[nil, nil, 'waiting'], %w[branch_after_halt waiting started]], audit_rows(target)
  end

  def test_transition_generated_mid_create_logs_its_machine_initial_state_then_the_event
    target = ARModelDeferred.new
    target.start!

    assert_equal %w[started final], [target.state, target.phase]
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
    assert_equal [[nil, nil, 'draft'], %w[advance draft final]], audit_rows(target, ARModelDeferredPhaseTransition)
  end

  def test_transition_generated_mid_save_is_logged
    target = ARModelDeferred.create!
    target.start!

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
    assert_equal [[nil, nil, 'draft'], %w[advance draft final]], audit_rows(target, ARModelDeferredPhaseTransition)
  end

  def test_around_raising_after_yield_without_the_action_still_logs_on_save
    target = ARModelHaltingCallbacks.new

    assert_raises(ArgumentError) { target.around_raise(false) }
    assert_equal 'started', target.state

    target.save!

    assert_equal [[nil, nil, 'waiting'], %w[around_raise waiting started]], audit_rows(target)
  end

  def test_around_raising_after_yield_without_the_action_on_persisted_record_logs_on_save
    target = ARModelHaltingCallbacks.create!

    assert_raises(ArgumentError) { target.around_raise(false) }
    target.save!

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[around_raise waiting started]], audit_rows(target)
  end

  def test_transition_rolled_back_with_an_outer_transaction_is_logged_by_the_save_that_writes_it
    target = ARModel.create!
    ARModel.transaction do
      target.start!
      raise ActiveRecord::Rollback
    end

    assert_equal 'waiting', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_failed_audit_write_rolls_back_an_enclosing_transaction
    target = ARModelWithValidatedContext.create!

    assert_raises(StateMachines::AuditTrail::RecordNotAudited) do
      ARModelWithValidatedContext.transaction { target.start }
    end

    assert_equal 'waiting', target.state
    assert_equal 'waiting', ARModelWithValidatedContext.find(target.id).state
    assert_equal 0, ARModelWithValidatedContextStateTransition.where(ar_model_with_validated_context_id: target.id).count
  end

  def test_failed_audit_write_on_create_rolls_back_an_enclosing_transaction
    target = ARModelWithValidatedInitialContext.new
    existing = ARModelWithValidatedInitialContext.count

    assert_raises(StateMachines::AuditTrail::RecordNotAudited) do
      ARModelWithValidatedInitialContext.transaction { target.save }
    end

    assert_predicate target, :new_record?
    assert_equal existing, ARModelWithValidatedInitialContext.count
  end

  def test_nested_event_in_a_before_callback_keeps_the_outer_transition
    target = ARModelNestedEvent.create!
    target.start!

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[wait waiting waiting], %w[start waiting started]], audit_rows(target)
  end

  def test_savepoint_rollback_does_not_rewrite_rows_that_survived
    target = ARModel.create!
    ARModel.transaction do
      target.start!
      ARModel.transaction(requires_new: true) do
        target.stop!
        raise ActiveRecord::Rollback
      end
    end
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_discards_unsaved_transitions
    target = ARModel.create!
    target.start(false)
    target.reload
    target.save!

    assert_equal 'waiting', target.reload.state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)
  end

  def test_machines_sharing_an_audit_class_write_rows_in_transition_order
    target = ARModelShared.create!
    target.advance
    target.start!

    assert_equal [%w[advance draft final], %w[start waiting started]],
                 audit_rows(target, ARModelSharedAuditTransition)
  end

  def test_rows_written_inside_a_non_joinable_transaction_survive_its_rollback
    target = ARModel.create!
    ARModel.transaction(joinable: false) do
      target.start!
      raise ActiveRecord::Rollback
    end

    assert_equal 'waiting', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.state_will_change!
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_clone_shares_the_journal_with_the_record_it_shares_attributes_with
    target = ARModel.create!
    copy = target.clone
    copy.start(false)
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_failed_attempts_do_not_accumulate_in_the_journal
    target = ARModelWithValidatedContext.create!

    3.times { assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.start } }

    assert_operator StateMachines::AuditTrail::Journal.of(target).entries.size, :<=, 1

    target.context = 'Some context'
    target.start!

    assert_empty StateMachines::AuditTrail::Journal.of(target).entries
  end

  def test_audit_trail_declared_on_a_subclass_before_its_parent_logs_once
    target = ARLateChild.create!
    target.start!

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]],
                 ARLateParentStateTransition.where(ar_late_parent_id: target.id).order(:id).pluck(:event, :from, :to)
  end

  def test_database_constraint_violation_raises_record_not_audited
    target = ARModelWithRequiredContext.create!

    error = assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.start }
    assert_kind_of ActiveRecord::StatementInvalid, error.cause
    assert_same target, error.record
    assert_equal 'waiting', target.state
    assert_equal 'waiting', ARModelWithRequiredContext.find(target.id).state
  end

  def test_clone_of_a_loaded_record_shares_its_journal
    target = ARModel.find(ARModel.create!.id)
    copy = target.clone
    copy.start(false)
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reloading_a_clone_keeps_the_journal_of_the_other
    target = ARModel.create!
    copy = target.clone
    target.start(false)
    copy.reload
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_dup_transitioning_during_its_initialization_keeps_its_own_journal
    target = ARModelDupInit.create!
    begin
      ARModelDupInit.start_on_initialize = true
      copy = target.dup
    ensure
      ARModelDupInit.start_on_initialize = false
    end
    target.save!
    copy.save!

    assert_equal 'waiting', ARModelDupInit.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(copy)
  end

  def test_rows_committed_by_a_non_joinable_transaction_leave_the_journal
    target = ARModel.create!
    ARModel.transaction(joinable: false) { target.start! }
    target.stop(false)

    assert_equal(%w[stop], StateMachines::AuditTrail::Journal.of(target).entries.map { |entry| entry.transition.event.to_s })
  end

  def test_transition_whose_before_callback_raises_leaves_the_journal
    target = ARModelRaisingBefore.create!

    assert_raises(ArgumentError) { target.explode }
    assert_empty StateMachines::AuditTrail::Journal.of(target).entries
  end

  def test_rescued_raise_in_a_nested_event_keeps_the_outer_transition
    target = ARModelRaisingBefore.create!
    target.start!

    assert_equal 'started', target.reload.state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
    assert_empty StateMachines::AuditTrail::Journal.of(target).entries
  end

  def test_clone_stops_sharing_pending_transitions_once_the_other_saves
    target = ARModel.create!
    copy = target.clone
    target.start!
    copy.stop(false)
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)

    copy.save!

    assert_equal 'stopped', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started], %w[stop started stopped]], audit_rows(target)
  end

  def test_becomes_shares_pending_transitions
    target = ARModel.create!
    cast = target.becomes(ARModelDescendant)
    cast.start(false)
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_adopts_transitions_made_while_finding_the_fresh_record
    target = ARModelStartOnFind.create!
    begin
      ARModelStartOnFind.start_on_find = true
      target.reload
    ensure
      ARModelStartOnFind.start_on_find = false
    end

    assert_equal 'started', target.state
    target.save!

    assert_equal 'started', ARModelStartOnFind.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  %i[start_with_lock start_lock_around start_lock_before start_with_lock_before].each do |event|
    define_method(:"test_#{event}_reloading_the_record_mid_transition_keeps_it_audited") do
      target = ARModelLocking.create!
      target.public_send(:"#{event}!")

      assert_equal 'started', ARModelLocking.find(target.id).state
      assert_equal [[nil, nil, 'waiting'], [event.to_s, 'waiting', 'started']], audit_rows(target)
    end
  end

  def test_reload_drops_completed_unsaved_transitions_but_not_running_ones
    target = ARModelLocking.create!
    target.start_lock_before(false)
    target.reload
    target.save!

    assert_equal 'waiting', ARModelLocking.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)
  end

  def test_transition_after_the_create_is_written_by_the_next_save
    target = ARModelLateStart.new(start_after_create: true)
    target.save!

    assert_equal 'started', target.state
    assert_equal 'waiting', ARModelLateStart.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal 'started', ARModelLateStart.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_transition_in_an_earlier_after_save_is_written_by_the_next_save
    target = ARModelLateStart.create!
    begin
      ARModelLateStart.start_after_save = true
      target.save!
    ensure
      ARModelLateStart.start_after_save = false
    end

    assert_equal 'waiting', ARModelLateStart.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal 'started', ARModelLateStart.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_in_an_earlier_after_save_keeps_the_saved_transition
    target = ARModelReloadAfterSave.create!
    target.start!

    assert_equal 'started', ARModelReloadAfterSave.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_in_an_earlier_after_create_keeps_the_initial_state_and_the_event
    target = ARModelReloadAfterCreate.new
    target.start!

    assert_equal 'started', ARModelReloadAfterCreate.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_rolled_back_nested_save_does_not_cost_the_outer_save_its_rows
    target = ARModelNestedSavepointSave.create!
    target.nest_once = true
    target.start!

    assert_equal 'started', ARModelNestedSavepointSave.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  [ARModelReloadAfterAudit, ARModelReloadAfterSave].each do |model|
    define_method(:"test_#{model.name.underscore}_reload_keeps_rows_an_enclosing_rollback_takes") do
      target = model.create!
      model.transaction do
        target.start!
        raise ActiveRecord::Rollback
      end

      assert_equal 'waiting', model.find(target.id).state
      assert_equal [[nil, nil, 'waiting']], audit_rows(target)

      target.save!

      assert_equal target.state, model.find(target.id).state
      expected = [[nil, nil, 'waiting']]
      expected << %w[start waiting started] if target.state == 'started'

      assert_equal expected, audit_rows(target)
    end
  end

  def test_reload_after_audit_without_an_enclosing_transaction_settles_the_journal
    target = ARModelReloadAfterAudit.create!
    target.start!

    assert_equal 'started', ARModelReloadAfterAudit.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
    assert_empty StateMachines::AuditTrail::Journal.of(target).entries
  end

  def test_reload_after_audit_inside_a_rolled_back_savepoint_keeps_the_trail_consistent
    target = ARModelReloadAfterAudit.create!
    ARModelReloadAfterAudit.transaction do
      target.start!
      ARModelReloadAfterAudit.transaction(requires_new: true) do
        target.stop!
        raise ActiveRecord::Rollback
      end
    end
    target.save!

    assert_equal 'started', ARModelReloadAfterAudit.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_after_a_rolled_back_nested_save_keeps_the_rewritten_row_tracked
    target = ARModelNestedThenReload.create!
    target.nest_once = true
    ARModelNestedThenReload.transaction do
      target.start!
      raise ActiveRecord::Rollback
    end

    assert_equal 'waiting', ARModelNestedThenReload.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal 'started', ARModelNestedThenReload.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_reload_after_a_rolled_back_nested_save_without_an_enclosing_transaction
    target = ARModelNestedThenReload.create!
    target.nest_once = true
    target.start!

    assert_equal 'started', ARModelNestedThenReload.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
    assert_empty StateMachines::AuditTrail::Journal.of(target).entries
  end

  def test_rolled_back_destroy_keeps_a_pending_transition
    target = ARModel.create!
    target.start(false)
    ARModel.transaction do
      target.destroy!
      raise ActiveRecord::Rollback
    end
    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_rolled_back_destroy_keeps_tracking_a_row_written_in_its_transaction
    target = ARModel.create!
    ARModel.transaction do
      target.start!
      target.destroy!
      raise ActiveRecord::Rollback
    end

    assert_equal 'waiting', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)

    target.save!

    assert_equal 'started', ARModel.find(target.id).state
    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], audit_rows(target)
  end

  def test_save_inside_a_refused_loopback_logs_nothing
    target = ARModelNestedSave.create!

    refute target.wait
    assert_empty audit_rows(target)
  end

  def test_loaded_audit_association_reads_the_new_rows
    target = ARModel.create!

    loaded_rows = -> { target.ar_model_state_transitions.map { |row| [row.event, row.from, row.to] } }

    assert_equal [[nil, nil, 'waiting']], loaded_rows.call

    target.start!

    assert_equal [[nil, nil, 'waiting'], %w[start waiting started]], loaded_rows.call
  end

  def test_failed_initial_audit_write_is_recovered_by_a_later_save
    target = ARModelWithValidatedInitialContext.new

    assert_raises(StateMachines::AuditTrail::RecordNotAudited) { target.save }
    assert_predicate target, :new_record?
    refute_empty target.errors[:ar_model_with_validated_initial_context_state_transitions]
    assert_equal 0, ARModelWithValidatedInitialContextStateTransition.count

    target.context = 'Some context'

    assert target.save
    rows = ARModelWithValidatedInitialContextStateTransition.where(ar_model_with_validated_initial_context_id: target.id)

    assert_equal [[nil, nil, 'waiting', 'Some context']], rows.order(:id).pluck(:event, :from, :to, :context)
  end

  def test_retried_create_rechecks_the_if_condition
    target = ARModelConditionalRetry.new
    target.abort_create = true
    target.log_transitions = true

    refute target.save

    target.log_transitions = false

    assert target.save
    assert_empty audit_rows(target)
  end

  def test_retried_create_logs_the_initial_transition_after_a_false_if_condition
    target = ARModelConditionalRetry.new
    target.abort_create = true

    refute target.save

    target.log_transitions = true

    assert target.save
    assert_equal [[nil, nil, 'waiting']], audit_rows(target)
  end

  def test_retried_create_after_resetting_the_audit_association_logs_the_initial_transition
    target = ARModelAbortingFirstCreate.new(other_field: 'aborted_attempt')
    target.abort_create = true

    refute target.save

    target.association(:ar_model_aborting_first_create_state_transitions).reset
    target.other_field = 'successful_attempt'

    assert target.save
    rows = ARModelAbortingFirstCreateStateTransition.where(ar_model_aborting_first_create_id: target.id)

    assert_equal [[nil, nil, 'waiting', 'successful_attempt']], rows.order(:id).pluck(:event, :from, :to, :context)
  end

  private

  # [event, from, to] of every audit row the record owns, oldest first
  def audit_rows(target, transition_class = nil)
    transition_class ||= "#{target.class.name}StateTransition".constantize
    foreign_key = target.class.name.foreign_key
    transition_class.where(foreign_key => target.id).order(:id).pluck(:event, :from, :to)
  end

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
