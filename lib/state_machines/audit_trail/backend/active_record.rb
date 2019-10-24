require 'state_machines-activerecord'

class StateMachines::AuditTrail::Backend::ActiveRecord < StateMachines::AuditTrail::Backend
  def initialize(transition_class, owner_class, options = {})
    super
    @association = transition_class.to_s.tableize.split('/').last.to_sym
    assoc_options = {class_name: transition_class.to_s}.merge(options.slice(:as))
    owner_class.has_many(@association, assoc_options) unless owner_class.reflect_on_association(@association)
  end

  def persist(object, fields)
    fields.delete(:namespace) unless namespace_column_present?(object)

    # Let ActiveRecord manage the timestamp for us so it does the right thing with regards to timezones.
    if object.new_record?
      object.send(@association).build(fields)
    else
      object.send(@association).create(fields)
    end

    nil
  end

  private

  # Does the namespace column exist on the transition table for the provided object?
  def namespace_column_present?(object)
    object.class.reflect_on_association(@association).klass.column_names.include?('namespace')
  end
end
