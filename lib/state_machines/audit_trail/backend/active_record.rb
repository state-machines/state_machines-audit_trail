# frozen_string_literal: true

require 'state_machines-activerecord'

module StateMachines
  module AuditTrail
    class Backend
      class ActiveRecord < StateMachines::AuditTrail::Backend
        def initialize(transition_class, owner_class, options = {})
          super
          @association = transition_class.to_s.tableize.split('/').last.to_sym
          assoc_options = { class_name: transition_class.to_s, dependent: :destroy }.merge(options.slice(:as, :dependent))
          owner_class.has_many(@association, **assoc_options) unless owner_class.reflect_on_association(@association)
        end

        # Inserts the audit record right away; the owner is always persisted by
        # now (TransitionAuditing holds a new record's entries until it is
        # created).  The record takes the owner's keys from the association's
        # scope but is never added to the association's target (which
        # +scope.new+ / +build+ would do): a target entry outlives a
        # rolled back owner save as an unsaved record, which the owner's next
        # save would insert with the stale fields.  A loaded association is
        # reset so it reads the new row.
        #
        # A record that fails its validations fails the owner: the error is
        # reported on the owner and ActiveRecord::RecordInvalid raised for it,
        # which rolls back the owner's save (whose +save+ then returns false).
        def persist(object, fields)
          fields.delete(:namespace) unless namespace_column_present?(object)

          association = object.association(@association)
          # Let ActiveRecord manage the timestamp for us so it does the right thing with regards to timezones.
          record = association.klass.new(association.scope.scope_for_create.merge(fields.stringify_keys))
          association.set_inverse_instance(record)
          unless record.save
            object.errors.add(@association, :invalid)
            raise ::ActiveRecord::RecordInvalid, object
          end

          association.reset if association.loaded?
          record
        end

        private

        # Does the namespace column exist on the transition table for the provided object?
        def namespace_column_present?(object)
          object.class.reflect_on_association(@association).klass.column_names.include?('namespace')
        end
      end
    end
  end
end
