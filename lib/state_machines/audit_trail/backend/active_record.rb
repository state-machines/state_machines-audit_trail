# frozen_string_literal: true

require 'state_machines-activerecord'

module StateMachines
  module AuditTrail
    # Raised (from the owner's save, and so from +save+, +save!+ and the event)
    # when an audit row cannot be written.  Unlike ActiveRecord::RecordInvalid,
    # which +save+ turns into +false+, it propagates: the owner's row is already
    # written by then, and only a raise rolls back an enclosing transaction the
    # save joined.
    class RecordNotAudited < ::ActiveRecord::RecordNotSaved
      # The audit record that failed its validations
      attr_reader :audit_record

      def initialize(owner, audit_record, reason = audit_record.errors.full_messages.to_sentence)
        @audit_record = audit_record
        super("Failed to write the audit trail: #{reason}", owner)
      end
    end

    class Backend
      class ActiveRecord < StateMachines::AuditTrail::Backend
        def initialize(transition_class, owner_class, options = {})
          super
          @association = transition_class.to_s.tableize.split('/').last.to_sym
          assoc_options = { class_name: transition_class.to_s, dependent: :destroy }.merge(options.slice(:as, :dependent))
          # An STI subclass logs to its base class's transitions (see
          # TransitionAuditing#default_transition_class), keyed like its base
          # class's rows, not by the subclass's name
          assoc_options[:foreign_key] ||= owner_class.base_class.name.foreign_key unless assoc_options[:as]
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
        # A record that fails its validations or a database constraint fails
        # the owner's save: the error is reported on the owner and
        # RecordNotAudited raised, rolling back the save and any transaction
        # enclosing it.
        def persist(object, fields)
          fields.delete(:namespace) unless namespace_column_present?(object)

          association = object.association(@association)
          # Let ActiveRecord manage the timestamp for us so it does the right thing with regards to timezones.
          record = association.klass.new(association.scope.scope_for_create.merge(fields.stringify_keys))
          association.set_inverse_instance(record)
          begin
            saved = record.save
          rescue ::ActiveRecord::StatementInvalid => e
            # A database constraint: raised with the error as its cause
            object.errors.add(@association, :invalid)
            raise RecordNotAudited.new(object, record, e.message)
          end
          unless saved
            object.errors.add(@association, :invalid)
            raise RecordNotAudited.new(object, record)
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
