require 'spec_helper'

describe StateMachines::AuditTrail do
  
  it 'should include the auditing module into StateMachines::Machine' do
    expect(StateMachines::Machine.included_modules).to include(StateMachines::AuditTrail::TransitionAuditing)
  end
end
