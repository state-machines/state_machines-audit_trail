require 'mongoid'

### Setup test database
Mongoid.load!(File.expand_path('../mongoid.yml', __FILE__), :test)

# We probably want to provide a generator for this model and the accompanying migration.
class MongoidTestModelStateTransition
  include Mongoid::Document
  include Mongoid::Timestamps
  belongs_to :mongoid_test_model

  field :namespace, type: String
  field :event, type: String
  field :from,  type: String
  field :to,    type: String
end

class MongoidTestModelWithMultipleStateMachinesFirstTransition
  include Mongoid::Document
  include Mongoid::Timestamps
  belongs_to :mongoid_test_model

  field :namespace, type: String
  field :event, type: String
  field :from,  type: String
  field :to,    type: String
end

class MongoidTestModelWithMultipleStateMachinesSecondTransition
  include Mongoid::Document
  include Mongoid::Timestamps
  belongs_to :mongoid_test_model

  field :namespace, type: String
  field :event, type: String
  field :from,  type: String
  field :to,    type: String
end

class MongoidTestModel
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  state_machine :state, initial: :waiting do # log initial state?
    audit_trail :orm => :mongoid

    event :start do
      transition [:waiting, :stopped] => :started
    end
    
    event :stop do
      transition :started => :stopped
    end
  end
end

class MongoidTestModelDescendant < MongoidTestModel
  include Mongoid::Timestamps
end

class MongoidTestModelWithMultipleStateMachines
  
  include Mongoid::Document
  include Mongoid::Timestamps

  state_machine :first, initial: :beginning do
    audit_trail

    event :begin_first do
      transition :beginning => :end
    end
  end
  
  state_machine :second do
    audit_trail

    event :begin_second do
      transition nil => :beginning_second
    end
  end
end
