# frozen_string_literal: true

require 'active_record'

### Setup test database
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class ARModelStateTransition < ApplicationRecord
  belongs_to :ar_model, class_name: 'ARModel'
end

class ARModelWithNamespaceFooStateTransition < ApplicationRecord
  belongs_to :ar_model_with_namespace, class_name: 'ARModelWithNamespace'
end

class ARModelNoInitialStateTransition < ApplicationRecord
  belongs_to :ar_model_no_initial, class_name: 'ARModelNoInitial'
end

class ARModelWithoutNamespaceColumnStateTransition < ApplicationRecord
  belongs_to :ar_model_without_namespace_column, class_name: 'ARModelWithoutNamespaceColumn'
end

class ARModelConditionalAuditTrailStateTransition < ApplicationRecord
  belongs_to :ar_model_conditional_audit_trail, class_name: 'ARModelConditionalAuditTrail'
end

class ARModelWithContextStateTransition < ApplicationRecord
  belongs_to :ar_model_with_context, class_name: 'ARModelWithContext'
end

class ARModelWithMultipleContextStateTransition < ApplicationRecord
  belongs_to :ar_model_with_multiple_context, class_name: 'ARModelWithMultipleContext'
end

class ARModelWithContextBasedOnOtherFieldStateTransition < ApplicationRecord
  belongs_to :ar_model_with_context_based_on_other_field, class_name: 'ARModelWithContextBasedOnOtherField'
end

class ARModelWithMultipleStateMachinesFirstTransition < ApplicationRecord
  belongs_to :ar_model_with_multiple_state_machines, class_name: 'ARModelWithMultipleStateMachines'
end

class ARModelWithMultipleStateMachinesSecondTransition < ApplicationRecord
  belongs_to :ar_model_with_multiple_state_machines, class_name: 'ARModelWithMultipleStateMachines'
end

class ARModelWithMultipleStateMachinesThirdTransition < ApplicationRecord
  belongs_to :ar_model_with_multiple_state_machines, class_name: 'ARModelWithMultipleStateMachines'
end

class ARModel < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end
end

class ARModelNoInitial < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail initial: false

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end
end

class ARModelWithoutNamespaceColumn < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end
end

class ARModelConditionalAuditTrail < ApplicationRecord
  state_machine :state, initial: :waiting do
    # Only log a transition once the model has reached :stopped. This exercises
    # the audit_trail `if:` option for both the initial-transition path
    # (after_initialize) and the regular per-event transition path.
    audit_trail if: :should_log_transition?

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end

  private

  def should_log_transition?
    state == 'stopped'
  end
end

class ARModelWithNamespace < ApplicationRecord
  state_machine :foo_state, initial: :waiting, namespace: :foo do
    audit_trail

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end
end

class ARModelWithContext < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail context: :context

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end

  def context
    'Some context'
  end
end

class ARModelWithMultipleContext < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail context: %i[context second_context context_with_args]

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end

  def context
    'Some context'
  end

  def second_context
    'Extra context'
  end

  def context_with_args(transition)
    id = transition.args.last.delete(:id) if transition.args.present?
    id
  end
end

class ARModelWithContextBasedOnOtherField < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail context: :context

    event :start do
      transition %i[waiting stopped] => :started
    end

    event :stop do
      transition started: :stopped
    end
  end

  # Context intentionally reads a mutable attribute so tests can prove it is
  # resolved at save time, not at `.new` time (issue #22).
  def context
    other_field
  end
end

class ARModelWithValidatedContextStateTransition < ApplicationRecord
  belongs_to :ar_model_with_validated_context, class_name: 'ARModelWithValidatedContext'
  validates :context, presence: true
end

class ARModelWithValidatedContext < ApplicationRecord
  attr_accessor :context

  state_machine :state, initial: :waiting do
    audit_trail initial: false, context: :context

    event :start do
      transition waiting: :started
    end
  end
end

class ARModelAbortingFirstCreateStateTransition < ApplicationRecord
  belongs_to :ar_model_aborting_first_create, class_name: 'ARModelAbortingFirstCreate'
end

class ARModelAbortingFirstCreate < ApplicationRecord
  attr_accessor :abort_create

  state_machine :state, initial: :waiting do
    audit_trail context: :context

    event :start do
      transition waiting: :started
    end
  end

  before_create do
    if abort_create
      self.abort_create = false
      throw :abort
    end
  end

  def context
    other_field
  end
end

class ARModelWithValidatedInitialContextStateTransition < ApplicationRecord
  belongs_to :ar_model_with_validated_initial_context, class_name: 'ARModelWithValidatedInitialContext'
  validates :context, presence: true
end

# Unlike ARModelWithValidatedContext, logs the initial transition, so the
# audit record's validation runs on the owner's create.
class ARModelWithValidatedInitialContext < ApplicationRecord
  attr_accessor :context

  state_machine :state, initial: :waiting do
    audit_trail context: :context

    event :start do
      transition waiting: :started
    end
  end
end

class ARModelConditionalRetryStateTransition < ApplicationRecord
  belongs_to :ar_model_conditional_retry, class_name: 'ARModelConditionalRetry'
end

# Aborts its next create when abort_create is set, and logs only while
# log_transitions is set, so a test can flip the `if:` condition between
# create attempts.
class ARModelConditionalRetry < ApplicationRecord
  attr_accessor :abort_create, :log_transitions

  state_machine :state, initial: :waiting do
    audit_trail if: :log_transitions

    event :start do
      transition waiting: :started
    end
  end

  before_create do
    if abort_create
      self.abort_create = false
      throw :abort
    end
  end
end

class ARModelHaltingCallbacksStateTransition < ApplicationRecord
  belongs_to :ar_model_halting_callbacks, class_name: 'ARModelHaltingCallbacks'
end

# Each event commits its transition, then a callback halts the rest of the
# after phase: a per-transition `after:` (which runs before every machine
# after callback), a machine after callback declared before audit_trail, or
# an around callback declared after audit_trail halting after its yield.
class ARModelHaltingCallbacks < ApplicationRecord
  state_machine :state, initial: :waiting do
    after_transition(on: :machine_after_halt) { throw :halt }

    audit_trail

    around_transition(on: :around_halt) do |_object, _transition, block|
      block.call
      throw :halt
    end

    around_transition(on: :around_raise) do |_object, _transition, block|
      block.call
      raise ArgumentError, 'raised after the state change'
    end

    event :branch_after_halt do
      transition waiting: :started, after: proc { throw :halt }
    end

    event :machine_after_halt do
      transition waiting: :started
    end

    event :around_halt do
      transition waiting: :started
    end

    event :around_raise do
      transition waiting: :started
    end
  end
end

class ARModelDeferredStateTransition < ApplicationRecord
  belongs_to :ar_model_deferred, class_name: 'ARModelDeferred'
end

class ARModelDeferredPhaseTransition < ApplicationRecord
  belongs_to :ar_model_deferred, class_name: 'ARModelDeferred'
end

# Starting sets the phase machine's event attribute from a before callback, so
# the phase transition is generated mid-save: previewed by the validation
# (its around callbacks not entered) and completed after the save.
class ARModelDeferred < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    before_transition(on: :start) { |record| record.phase_event = 'advance' }

    event :start do
      transition waiting: :started
    end
  end

  state_machine :phase, initial: :draft do
    audit_trail

    event :advance do
      transition draft: :final
    end
  end
end

class ARModelNestedSaveStateTransition < ApplicationRecord
  belongs_to :ar_model_nested_save, class_name: 'ARModelNestedSave'
end

# A machine without an action or transactions whose before callback, declared
# after audit_trail, saves the record and then refuses the transition.
class ARModelNestedSave < ApplicationRecord
  state_machine :state, initial: :waiting, action: nil, use_transactions: false do
    audit_trail

    before_transition(on: :wait) do |record|
      record.save!
      throw :halt
    end

    event :wait do
      transition waiting: :waiting
    end
  end
end

class ARModelNestedEventStateTransition < ApplicationRecord
  belongs_to :ar_model_nested_event, class_name: 'ARModelNestedEvent'
end

# Starting first runs a loopback event of the same machine from a before
# callback, so one transition is noted while another is still in flight.
class ARModelNestedEvent < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    before_transition(on: :start) { |record, _transition| record.wait! }

    event :start do
      transition waiting: :started
    end

    event :wait do
      transition waiting: :waiting
    end
  end
end

class ARModelSharedAuditTransition < ApplicationRecord
  belongs_to :ar_model_shared, class_name: 'ARModelShared'
end

# Two machines logging to one audit class; the phase machine has no action,
# so its transitions are written by the next save.
class ARModelShared < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail class: ARModelSharedAuditTransition, initial: false

    event :start do
      transition waiting: :started
    end
  end

  state_machine :phase, initial: :draft, action: nil do
    audit_trail class: ARModelSharedAuditTransition, initial: false

    event :advance do
      transition draft: :final
    end
  end
end

class ARModelWithRequiredContextStateTransition < ApplicationRecord
  belongs_to :ar_model_with_required_context, class_name: 'ARModelWithRequiredContext'
end

# Its transitions' context column is NOT NULL in the database, with no model
# validation in front of it
class ARModelWithRequiredContext < ApplicationRecord
  attr_accessor :context

  state_machine :state, initial: :waiting do
    audit_trail initial: false, context: :context

    event :start do
      transition waiting: :started
    end
  end
end

class ARLateParentStateTransition < ApplicationRecord
  belongs_to :ar_late_parent, class_name: 'ARLateParent'
end

# audit_trail declared on the subclass before its parent declares it
class ARLateParent < ApplicationRecord
end

class ARLateChild < ARLateParent
  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition waiting: :started
    end
  end
end

class ARLateParent
  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition waiting: :started
    end
  end
end

class ARModelDupInitStateTransition < ApplicationRecord
  belongs_to :ar_model_dup_init, class_name: 'ARModelDupInit'
end

# Starts itself (without saving) from after_initialize while the class flag
# is set, so a dup transitions during its own initialization
class ARModelDupInit < ApplicationRecord
  class_attribute :start_on_initialize, default: false

  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition waiting: :started
    end
  end

  after_initialize { start(false) if self.class.start_on_initialize && can_start? }
end

class ARModelRaisingBeforeStateTransition < ApplicationRecord
  belongs_to :ar_model_raising_before, class_name: 'ARModelRaisingBefore'
end

# explode's before callback (declared after audit_trail, so the transition is
# noted first) raises; start runs explode from its own before callback and
# rescues the error
class ARModelRaisingBefore < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    before_transition(on: :explode) { raise ArgumentError, 'refused by raising' }
    before_transition(on: :start) do |record, _transition|
      record.explode
    rescue ArgumentError
      nil
    end

    event :start do
      transition waiting: :started
    end

    event :explode do
      transition waiting: :exploded
    end
  end
end

class ARModelStartOnFindStateTransition < ApplicationRecord
  belongs_to :ar_model_start_on_find, class_name: 'ARModelStartOnFind'
end

# Starts itself (without saving) from after_find while the class flag is set
class ARModelStartOnFind < ApplicationRecord
  class_attribute :start_on_find, default: false

  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition waiting: :started
    end
  end

  after_find { start(false) if self.class.start_on_find && can_start? }
end

class ARModelLockingStateTransition < ApplicationRecord
  belongs_to :ar_model_locking, class_name: 'ARModelLocking'
end

# Each event reloads the record (pessimistic lock) after audit_trail noted the
# transition: from an around callback, with with_lock or lock!, or from a
# before callback
class ARModelLocking < ApplicationRecord
  state_machine :state, initial: :waiting do
    audit_trail

    around_transition(on: :start_with_lock) { |record, _transition, block| record.with_lock { block.call } }
    around_transition(on: :start_lock_around) do |record, _transition, block|
      record.lock!
      block.call
    end
    before_transition(on: :start_lock_before) { |record, _transition| record.lock! }
    before_transition(on: :start_with_lock_before) { |record, _transition| record.with_lock { nil } }

    %i[start_with_lock start_lock_around start_lock_before start_with_lock_before].each do |name|
      event(name) { transition waiting: :started }
    end
  end
end

class ARModelLateStartStateTransition < ApplicationRecord
  belongs_to :ar_model_late_start, class_name: 'ARModelLateStart'
end

# Starts (without saving) after the row is written: from after_create, or from
# an after_save declared before audit_trail's while the class flag is set
class ARModelLateStart < ApplicationRecord
  class_attribute :start_after_save, default: false

  after_save { start(false) if self.class.start_after_save && can_start? }

  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition waiting: :started
    end
  end

  attr_accessor :start_after_create

  after_create { start(false) if start_after_create }
end

class ARModelDescendant < ARModel
end

class ARModelDescendantWithOwnStateMachinesStateTransition < ApplicationRecord
end

class ARModelDescendantWithOwnStateMachines < ARModel
  state_machine :state, initial: :new do
    audit_trail

    event :complete do
      transition [:new] => :completed
    end
  end
end

class ARModelWithMultipleStateMachines < ApplicationRecord
  state_machine :first, initial: :beginning do
    audit_trail

    event :begin_first do
      transition beginning: :end
    end
  end

  state_machine :second do
    audit_trail

    event :begin_second do
      transition nil => :beginning_second
    end
  end

  state_machine :third, action: nil do
    audit_trail

    event :begin_third do
      transition nil => :beginning_third
    end

    event :end_third do
      transition beginning_third: :done_third
    end
  end
end

class ARResourceStateTransition < ApplicationRecord
  belongs_to :ar_resource, polymorphic: true
end

class ARFirstModelWithPolymorphicStateTransition < ApplicationRecord
  state_machine :state, initial: :pending do
    audit_trail class: ARResourceStateTransition, as: :ar_resource

    event :start do
      transition pending: :in_progress
    end

    event :finish do
      transition in_progress: :complete
    end
  end
end

class ARSecondModelWithPolymorphicStateTransition < ApplicationRecord
  state_machine :state, initial: :pending do
    audit_trail class: ARResourceStateTransition, as: :ar_resource

    event :start do
      transition pending: :in_progress
    end

    event :finish do
      transition in_progress: :complete
    end
  end
end

module SomeModule
  class ARModelStateTransition < ApplicationRecord
    belongs_to :ar_model, class_name: 'SomeModule::ARModel'
  end

  class ARModel < ApplicationRecord
    state_machine :state, initial: :waiting do
      audit_trail

      event :start do
        transition %i[waiting stopped] => :started
      end

      event :stop do
        transition started: :stopped
      end
    end
  end
end

#
# Generate tables
#
# NOTE: schema creation is deferred to AuditTrailTestSchema.create! (called
# from each test's #setup) rather than run here at require-time. Under
# padded_cell, requires happen once in the parent process before it forks a
# fresh worker per test; ActiveRecord transparently reconnects after fork and
# a fresh :memory: SQLite connection is an empty database, so any tables
# created here at load time would silently vanish by the time a forked test
# runs. Creating them in #setup guarantees they run inside the (possibly
# forked) process that actually executes the test.
module AuditTrailTestSchema
  class << self
    def create_model_table(owner_class, multiple_state_machines = false, state_column = nil, additional_field = nil)
      ActiveRecord::Base.connection.create_table(owner_class.name.tableize) do |t|
        if state_column.presence
          t.string state_column
        else
          t.string :state unless multiple_state_machines
        end
        t.string :type

        if multiple_state_machines
          t.string :first
          t.string :second
          t.string :third
        end

        t.string additional_field if additional_field

        t.timestamps null: false
      end
    end

    def create_transition_table(owner_class_name, state, add_context: false, polymorphic: false, add_namespace: true)
      class_name = "#{owner_class_name}#{state.to_s.camelize}Transition"
      ActiveRecord::Base.connection.create_table(class_name.tableize) do |t|
        t.references owner_class_name.demodulize.underscore.to_s, index: false, polymorphic: polymorphic
        # t.integer owner_class_name.foreign_key
        t.string :namespace if add_namespace
        t.string :event
        t.string :from
        t.string :to

        t.string :context if add_context
        t.string :second_context if add_context
        t.string :context_with_args if add_context
        t.datetime :created_at
      end
    end

    def create_model_tables
      %w[ARModel ARModelNoInitial ARModelWithContext ARModelWithMultipleContext ARModelWithValidatedContext
         ARModelWithoutNamespaceColumn ARModelConditionalAuditTrail ARModelWithValidatedInitialContext
         ARModelConditionalRetry ARModelHaltingCallbacks ARModelNestedSave ARModelNestedEvent
         ARModelWithRequiredContext ARLateParent ARModelDupInit ARModelRaisingBefore
         ARModelStartOnFind ARModelLocking ARModelLateStart
         ARFirstModelWithPolymorphicStateTransition ARSecondModelWithPolymorphicStateTransition].each do |name|
        create_model_table(name.constantize)
      end

      create_model_table(ARModelWithNamespace, false, :foo_state)
      create_model_table(ARModelWithMultipleStateMachines, true)
      create_model_table(ARModelWithContextBasedOnOtherField, false, :state, :other_field)
      create_model_table(ARModelAbortingFirstCreate, false, :state, :other_field)
      create_model_table(ARModelDeferred, false, :state, :phase)
      create_model_table(ARModelShared, false, :state, :phase)
    end

    # Its context column is NOT NULL, unlike create_transition_table's
    def create_required_context_transition_table
      ActiveRecord::Base.connection.create_table(:ar_model_with_required_context_state_transitions) do |t|
        t.references :ar_model_with_required_context, index: false
        t.string :namespace
        t.string :event
        t.string :from
        t.string :to
        t.string :context, null: false
        t.datetime :created_at
      end
    end

    def create!
      return if @created

      create_model_tables
      %w[ARModel ARModelNoInitial ARModelConditionalAuditTrail ARModelConditionalRetry
         ARModelHaltingCallbacks ARModelDeferred ARModelNestedSave ARModelNestedEvent ARLateParent
         ARModelDupInit ARModelRaisingBefore ARModelStartOnFind
         ARModelLocking ARModelLateStart].each do |name|
        create_transition_table(name, :state)
      end
      create_required_context_transition_table
      create_transition_table('ARModelShared', :audit)
      create_transition_table('ARModelDeferred', :phase)

      create_transition_table('ARModelWithoutNamespaceColumn', :state, add_namespace: false)
      create_transition_table('ARModelWithNamespace', :foo_state, add_context: false)
      %w[ARModelWithContext ARModelWithMultipleContext ARModelWithContextBasedOnOtherField
         ARModelWithValidatedContext ARModelWithValidatedInitialContext ARModelAbortingFirstCreate].each do |name|
        create_transition_table(name, :state, add_context: true)
      end
      create_transition_table('ARModelWithMultipleStateMachines', :first)
      create_transition_table('ARModelWithMultipleStateMachines', :second)
      create_transition_table('ARModelWithMultipleStateMachines', :third)
      create_transition_table('ARResource', :state, polymorphic: true)
      create_transition_table('ARModelDescendantWithOwnStateMachines', :state)

      @created = true
    end
  end
end
