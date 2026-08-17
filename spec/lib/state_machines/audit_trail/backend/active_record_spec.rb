# reset integrations so that something like Mongoid is not loaded and conflicting
require 'state_machines'
StateMachines::Integrations.reset

require 'spec_helper'
require 'state_machines-activerecord'
require 'helpers/active_record'

describe StateMachines::AuditTrail::Backend::ActiveRecord do

  context ':initial option' do
    context 'default' do
      it 'new object' do
        target = ARModel.new
        # initial transition is built but not saved
        expect(target.new_record?).to be_truthy
        expect(target.ar_model_state_transitions.count).to eq 0
        target.save!

        # initial transition is saved and should be present
        expect(target.new_record?).to be_falsey
        expect(target.ar_model_state_transitions.count).to eq 1
        state_transition = target.ar_model_state_transitions.first
        assert_transition state_transition, nil, nil, 'waiting'
      end

      it 'create object' do
        target = ARModel.create!
        # initial transition is saved and should be present
        expect(target.new_record?).to be_falsey
        expect(target.ar_model_state_transitions.count).to eq 1
        state_transition = target.ar_model_state_transitions.first
        assert_transition state_transition, nil, nil, 'waiting'

        # ensure we don't have a second initial state transition logged (issue #4)
        target = target.reload()
        expect(target.ar_model_state_transitions.count).to eq 1
        state_transition = target.ar_model_state_transitions.first
        assert_transition state_transition, nil, nil, 'waiting'
      end
    end

    it 'false skips log' do
      target = ARModelNoInitial.new
      # initial transition is not-built
      expect(target.new_record?).to be_truthy
      expect(target.ar_model_no_initial_state_transitions.count).to eq 0
      target.save!

      # after save, initial transition is not-saved
      expect(target.new_record?).to be_falsey
      expect(target.ar_model_no_initial_state_transitions.count).to eq 0
    end
  end

  context 'namespaced state_machine' do
    it 'should log namespace' do
      target = ARModelWithNamespace.create!

      # initial transition is saved and should be present
      expect(target.new_record?).to be_falsey
      expect(target.ar_model_with_namespace_foo_state_transitions.count).to eq 1
      state_transition = target.ar_model_with_namespace_foo_state_transitions.first
      expect(state_transition.namespace).to eq 'foo'
      expect(state_transition.from).to be_nil
      expect(state_transition.to).to eq 'waiting'
      expect(state_transition.event).to be_nil
    end

    it 'should not log namespace if namespace column doesn\'t exist' do
      target = ARModel.create!
      expect(target.new_record?).to be_falsey
      expect(target.ar_model_state_transitions.count).to eq 1
      state_transition = target.ar_model_state_transitions.first
      expect(state_transition.from).to be_nil
      expect(state_transition.to).to eq 'waiting'
      expect(state_transition.event).to be_nil
    end
  end

  context '#create_for' do
    it 'should be Backend::ActiveRecord' do
      backend = StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModel)
      expect(backend).to be_instance_of(StateMachines::AuditTrail::Backend::ActiveRecord)
    end

    it 'should create a has many association on the state machine owner' do
      StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModel)
      expect(ARModel.reflect_on_association(:ar_model_state_transitions).collection?).to be_truthy
    end

    it 'should handle models within modules' do
      StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, SomeModule::ARModel)
      expect(SomeModule::ARModel.reflect_on_association(:ar_model_state_transitions).collection?).to be_truthy
    end

    it 'should handle state transition models within modules' do
      StateMachines::AuditTrail::Backend.create_for(SomeModule::ARModelStateTransition, ARModel)
      expect(ARModel.reflect_on_association(:ar_model_state_transitions).collection?).to be_truthy
    end
  end

  context 'single state machine' do
    shared_examples 'audit trail with context' do
      it 'should populate all fields' do

        # state_transition =target.state_transitions.first
        # expect(state_transition.from).to be_nil

        expect(target.state_name).to eq :waiting
        target.start!
        expect(target.state_name).to eq :started

        last_transition = ARModelWithContextStateTransition.where(:ar_model_with_context_id => target.id).last

        expect(last_transition).not_to be_nil
        expect(last_transition.event).to eq 'start'
        expect(last_transition.from).to eq 'waiting'
        expect(last_transition.to).to eq 'started'
        expect(last_transition.context).not_to be_nil
        expect(last_transition.created_at).to be_within(10.seconds).of(Time.now.utc)
      end

      it 'do nothing on failed transition' do
        expect { target.stop }.not_to change(ARModelWithContextStateTransition, :count)
      end
    end

    context 'on created model' do
      let!(:target) { ARModelWithContext.create! }
      include_examples 'audit trail with context'

      it 'should log multiple events' do
        expect { target.start && target.stop && target.start }.to change(ARModelWithContextStateTransition, :count).by(3)
      end
    end

    context 'on new model' do
      let!(:target) { ARModelWithContext.new }
      include_examples 'audit trail with context'

      it 'should log multiple events including the first event from save' do
        expect { target.start && target.stop && target.start }.to change(ARModelWithContextStateTransition, :count).by(4)
      end
    end

    context 'wants to log a single context' do
      before(:each) do
        StateMachines::AuditTrail::Backend.create_for(ARModelWithContextStateTransition, ARModelWithContext, context: :context)
      end

      let!(:target) { ARModelWithContext.create! }

      it 'should populate all fields' do
        target.start!
        last_transition = ARModelWithContextStateTransition.where(:ar_model_with_context_id => target.id).last
        expect(last_transition.context).to eq target.context
      end
    end

    context 'wants to log multiple context fields' do
      before(:each) do
        StateMachines::AuditTrail::Backend.create_for(ARModelWithMultipleContextStateTransition, ARModelWithMultipleContext, context: [:context, :second_context, :context_with_args])
      end

      let!(:target) { ARModelWithMultipleContext.create! }

      it 'should populate all fields' do
        target.start!
        last_transition = ARModelWithMultipleContextStateTransition.where(:ar_model_with_multiple_context_id => target.id).last
        expect(last_transition.context).to eq target.context
        expect(last_transition.second_context).to eq target.second_context
      end

      it 'should log an event with passed arguments' do
        target.start!('one', 'two', 'three', 'for', id: 1)
        last_transition = ARModelWithMultipleContextStateTransition.where(:ar_model_with_multiple_context_id => target.id).last
        expect(last_transition.context_with_args).to eq '1'
      end
    end

  end


  context 'multiple state machines' do
    let!(:target) { ARModelWithMultipleStateMachines.create! }

    it 'should log a state transition for the affected state machine' do
      expect { target.begin_first! }.to change(ARModelWithMultipleStateMachinesFirstTransition, :count).by(1)
    end

    it 'should not log a state transition for the unaffected state machine' do
      expect { target.begin_first! }.not_to change(ARModelWithMultipleStateMachinesSecondTransition, :count)
    end
  end

  context 'with an initial state' do
    let(:target_class) { ARModelWithMultipleStateMachines }
    let(:state_transition_class) { ARModelWithMultipleStateMachinesFirstTransition }

    it 'should log a state transition for the inital state' do
      expect { target_class.create! }.to change(state_transition_class, :count).by(1)
    end

    it 'should only set the :to state for the initial transition' do
      target_class.create!
      initial_transition = state_transition_class.last
      expect(initial_transition.event).to be_nil
      expect(initial_transition.from).to be_nil
      expect(initial_transition.to).to eq 'beginning'
      expect(initial_transition.created_at).to be_within(10.seconds).of(Time.now.utc)
    end
  end

  context 'without an initial state' do
    let(:target_class) { ARModelWithMultipleStateMachines }
    let(:state_transition_class) { ARModelWithMultipleStateMachinesSecondTransition }

    it 'should not log a transition when the object is created' do
      expect { target_class.create! }.not_to change(state_transition_class, :count)
    end

    it 'should log a transition for the first event' do
      expect { target_class.create.begin_second! }.to change(state_transition_class, :count).by(1)
    end

    it 'should not set a value for the :from state on the first transition' do
      target_class.create.begin_second!
      first_transition = state_transition_class.last
      expect(first_transition.event).to eq 'begin_second'
      expect(first_transition.from).to be_nil
      expect(first_transition.to).to eq 'beginning_second'
      expect(first_transition.created_at).to be_within(10.seconds).of(Time.now.utc)
    end

    it 'should be fine transitioning before saved on an :action => nil state machine' do
      expect {
        machine = target_class.new
        machine.begin_third
        machine.save!
      }.to change(ARModelWithMultipleStateMachinesThirdTransition, :count).by(1)
    end

    it 'should queue up transitions to be saved before being saved on an :action => nil state machine' do
      expect {
        machine = target_class.new
        machine.begin_third
        machine.end_third
        machine.save!
      }.to change(ARModelWithMultipleStateMachinesThirdTransition, :count).by(2)
    end
  end

  context 'STI' do
    it 'resolve class name' do
      m = ARModelDescendant.create!
      expect { m.start! }.not_to raise_error
    end

    it 'resolve class name on own state machine' do
      m = ARModelDescendantWithOwnStateMachines.create!
      expect { m.complete! }.not_to raise_error
    end
  end

  context 'polymorphic' do
    it 'creates polymorphic state transitions' do
      m1 = ARFirstModelWithPolymorphicStateTransition.create!
      m2 = ARSecondModelWithPolymorphicStateTransition.create!
      m2.start!
      m2.finish!

      expect(m1.ar_resource_state_transitions.count).to eq(1)
      expect(m2.ar_resource_state_transitions.count).to eq(3)
      expect(ARResourceStateTransition.count).to eq(4)
    end
  end

  private

  def assert_transition(state_transition, event, from, to)
    # expect(state_transition.namespace).to eq namespace
    expect(state_transition.event).to eq event
    expect(state_transition.from).to eq from
    expect(state_transition.to).to eq to
  end
end
