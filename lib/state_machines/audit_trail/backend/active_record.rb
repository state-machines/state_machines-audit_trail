# frozen_string_literal: true

require 'state_machines-activerecord'

module StateMachines
  module AuditTrail
    class Backend
      class ActiveRecord < StateMachines::AuditTrail::Backend
        def initialize(transition_class, owner_class, options = {})
          super
          @association = transition_class.to_s.tableize.split('/').last.to_sym
          assoc_options = { class_name: transition_class.to_s }.merge(options.slice(:as))
          owner_class.has_many(@association, **assoc_options) unless owner_class.reflect_on_association(@association)
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
    end
  end
end
