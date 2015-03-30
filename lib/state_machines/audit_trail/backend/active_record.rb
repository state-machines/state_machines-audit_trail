require 'state_machines-activerecord'

class StateMachines::AuditTrail::Backend::ActiveRecord < StateMachines::AuditTrail::Backend
  attr_accessor :context

  def initialize(transition_class, owner_class, context = nil)
    @association = transition_class.to_s.tableize.split('/').last.to_sym
    super transition_class, owner_class
    self.context = context # FIXME: actually not sure why we need to do this, but tests fail otherwise. Something with super's Struct?
    owner_class.has_many(@association, class_name: transition_class.to_s) unless owner_class.reflect_on_association(@association)
  end

  def persist(object, fields)
    # Let ActiveRecord manage the timestamp for us so it does the right thing with regards to timezones.
    if object.new_record?
      object.send(@association).build(fields)
    else
      object.send(@association).create(fields)
    end

    nil
  end
end
