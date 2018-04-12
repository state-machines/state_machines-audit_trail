require 'state_machines'
require 'spec_helper'
require 'state_machines-activerecord'
require 'helpers/active_record'

describe StateMachines::AuditTrail::Backend do

  context 'logging' do

    it 'removes all nil attributes from fields' do
      backend = StateMachines::AuditTrail::Backend.new(ARModelWithContextStateTransition, ARModel, {})

      allow(StateMachines::AuditTrail::Backend).to receive(:new).and_return(backend)
      allow(backend).to receive(:persist)

      transition = OpenStruct.new(namespace: 'foo', from: nil, to: 'waiting', event: nil)

      backend.log(ARModel.new, transition)

      expect(backend).to have_received(:persist).with(ARModel, { namespace: 'foo', to: 'waiting' })
    end
  end
end
