require 'active_record'

### Setup test database
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

class ARModelStateTransition < ActiveRecord::Base
  belongs_to :ar_model
end

class ARModelWithNamespaceFooStateTransition < ActiveRecord::Base
  belongs_to :ar_model_with_namespace
end

class ARModelNoInitialStateTransition < ActiveRecord::Base
  belongs_to :ar_model_no_initial
end

class ARModelWithContextStateTransition < ActiveRecord::Base
  belongs_to :ar_model_with_context
end

class ARModelWithMultipleContextStateTransition < ActiveRecord::Base
  belongs_to :ar_model_with_multiple_context
end

class ARModelWithMultipleStateMachinesFirstTransition < ActiveRecord::Base
  belongs_to :ar_model_with_multiple_state_machines
end

class ARModelWithMultipleStateMachinesSecondTransition < ActiveRecord::Base
  belongs_to :ar_model_with_multiple_state_machines
end

class ARModelWithMultipleStateMachinesThirdTransition < ActiveRecord::Base
  belongs_to :ar_model_with_multiple_state_machines
end

class ARModel < ActiveRecord::Base

  state_machine :state, initial: :waiting do
    audit_trail

    event :start do
      transition [:waiting, :stopped] => :started
    end

    event :stop do
      transition :started => :stopped
    end
  end
end

class ARModelNoInitial < ActiveRecord::Base

  state_machine :state, initial: :waiting do
    audit_trail initial: false

    event :start do
      transition [:waiting, :stopped] => :started
    end

    event :stop do
      transition :started => :stopped
    end
  end
end

class ARModelWithNamespace < ActiveRecord::Base

  state_machine :foo_state, initial: :waiting, namespace: :foo do
    audit_trail

    event :start do
      transition [:waiting, :stopped] => :started
    end

    event :stop do
      transition :started => :stopped
    end
  end
end

#
class ARModelWithContext < ActiveRecord::Base
  state_machine :state, initial: :waiting do
    audit_trail context: :context

    event :start do
      transition [:waiting, :stopped] => :started
    end

    event :stop do
      transition :started => :stopped
    end
  end

  def context
    'Some context'
  end
end

class ARModelWithMultipleContext < ActiveRecord::Base
  state_machine :state, initial: :waiting do
    audit_trail context: [:context, :second_context, :context_with_args]

    event :start do
      transition [:waiting, :stopped] => :started
    end

    event :stop do
      transition :started => :stopped
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

class ARModelDescendant < ARModel
end

class ARModelDescendantWithOwnStateMachines < ARModel
  state_machine :state, :initial => :new do
    audit_trail

    event :complete do
      transition [:new] => :completed
    end
  end
end

class ARModelWithMultipleStateMachines < ActiveRecord::Base

  state_machine :first, :initial => :beginning do
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

  state_machine :third, :action => nil do
    audit_trail

    event :begin_third do
      transition nil => :beginning_third
    end

    event :end_third do
      transition :beginning_third => :done_third
    end
  end
end

class ARResourceStateTransition < ActiveRecord::Base
  belongs_to :resource, polymorphic: true
end

class ARFirstModelWithPolymorphicStateTransition < ActiveRecord::Base
  state_machine :state, :initial => :pending do
    audit_trail class: ARResourceStateTransition, as: :ar_resource

    event :start do
      transition :pending => :in_progress
    end

    event :finish do
      transition :in_progress => :complete
    end
  end
end

class ARSecondModelWithPolymorphicStateTransition < ActiveRecord::Base
  state_machine :state, :initial => :pending do
    audit_trail class: ARResourceStateTransition, as: :ar_resource

    event :start do
      transition :pending => :in_progress
    end

    event :finish do
      transition :in_progress => :complete
    end
  end
end

module SomeModule
  class ARModelStateTransition < ActiveRecord::Base
    belongs_to :ar_model
  end

  class ARModel < ActiveRecord::Base

    state_machine :state, initial: :waiting do
      audit_trail

      event :start do
        transition [:waiting, :stopped] => :started
      end

      event :stop do
        transition :started => :stopped
      end
    end
  end
end

#
# Generate tables
#
def create_model_table(owner_class, multiple_state_machines = false, state_column = nil)
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

    t.timestamps null: false
  end
end


%w(ARModel ARModelNoInitial ARModelWithContext ARModelWithMultipleContext ARFirstModelWithPolymorphicStateTransition ARSecondModelWithPolymorphicStateTransition).each do |name|
  create_model_table(name.constantize)
end

create_model_table(ARModelWithNamespace, false, :foo_state)
create_model_table(ARModelWithMultipleStateMachines, true)

def create_transition_table(owner_class_name, state, add_context: false, polymorphic: false)
  class_name = "#{owner_class_name}#{state.to_s.camelize}Transition"
  ActiveRecord::Base.connection.create_table(class_name.tableize) do |t|

    t.references "#{owner_class_name.demodulize.underscore}", index: false, polymorphic: polymorphic
    # t.integer owner_class_name.foreign_key
    t.string :namespace
    t.string :event
    t.string :from
    t.string :to

    t.string :context if add_context
    t.string :second_context if add_context
    t.string :context_with_args if add_context
    t.datetime :created_at
  end
end

%w(ARModel ARModelNoInitial).each do |name|
  create_transition_table(name, :state)
end

create_transition_table("ARModelWithNamespace", :foo_state, add_context: false)
create_transition_table("ARModelWithContext", :state, add_context: true)
create_transition_table("ARModelWithMultipleContext", :state, add_context: true)
create_transition_table("ARModelWithMultipleStateMachines", :first)
create_transition_table("ARModelWithMultipleStateMachines", :second)
create_transition_table("ARModelWithMultipleStateMachines", :third)
create_transition_table("ARResource", :state, polymorphic: true)
