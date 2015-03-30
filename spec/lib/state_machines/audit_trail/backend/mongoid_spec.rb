# reset integrations so that something like ActiveRecord is not loaded and conflicting
require 'state_machines'
StateMachines::Integrations.reset

require 'spec_helper'
require 'state_machines-mongoid'
require 'helpers/mongoid'

describe StateMachines::AuditTrail::Backend::Mongoid do

  context '#create_for' do
    it 'should create a Mongoid backend' do
      backend = StateMachines::AuditTrail::Backend.create_for(MongoidTestModelStateTransition, MongoidTestModel)
      expect(backend).to be_instance_of(StateMachines::AuditTrail::Backend::Mongoid)
    end
  end

  context 'single state machine' do
    let!(:target) { MongoidTestModel.create! }

    it 'should populate all fields' do
      target.start!
      last_transition = MongoidTestModelStateTransition.where(:mongoid_test_model_id => target.id).last

      expect(last_transition.event).to eq 'start'
      expect(last_transition.from).to eq 'waiting'
      expect(last_transition.to).to eq 'started'
      expect(last_transition.created_at).to be_within(10.seconds).of(DateTime.now)
    end

    it 'should log multiple events' do
      expect { target.start && target.stop && target.start }.to change(MongoidTestModelStateTransition, :count).by(3)
    end

    it 'do nothing on failed transition' do
      expect { target.stop }.not_to change(MongoidTestModelStateTransition, :count)
    end
  end

  context 'multiple state machines' do
    let!(:target) { MongoidTestModelWithMultipleStateMachines.create! }

    it 'should log a state transition for the affected state machine' do
      expect { target.begin_first! }.to change(MongoidTestModelWithMultipleStateMachinesFirstTransition, :count).by(1)
    end

    it 'should not log a state transition for the unaffected state machine' do
      expect { target.begin_first! }.not_to change(MongoidTestModelWithMultipleStateMachinesSecondTransition, :count)
    end
  end

  context 'on an object with a state machine having an initial state' do
    let(:target_class) { MongoidTestModelWithMultipleStateMachines }
    let(:state_transition_class) { MongoidTestModelWithMultipleStateMachinesFirstTransition }

    it 'should log a state transition for the inital state' do
      expect { target_class.create! }.to change(state_transition_class, :count).by(1)
    end

    it 'should only set the :to state for the initial transition' do
      target_class.create!
      initial_transition = state_transition_class.last
      expect(initial_transition.event).to be_nil
      expect(initial_transition.from).to be_nil
      expect(initial_transition.to).to eq 'beginning'
      expect(initial_transition.created_at).to be_within(10.seconds).of(DateTime.now)
    end
  end

  context 'on an object with a state machine not having an initial state' do
    let(:target_class) { MongoidTestModelWithMultipleStateMachines }
    let(:state_transition_class) { MongoidTestModelWithMultipleStateMachinesSecondTransition }

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
      expect(first_transition.created_at).to be_within(10.seconds).of(DateTime.now)
    end
  end

  context 'on a class using STI' do
    it 'should properly grab the class name from STI models' do
      m = MongoidTestModelDescendant.create!
      expect { m.start! }.not_to raise_error
    end
  end
end
