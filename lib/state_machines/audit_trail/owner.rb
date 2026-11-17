# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # The callbacks audit_trail installs on the model owning the machines, once
    # per class hierarchy.  They act on the record's Journal as a whole, so the
    # rows of several machines (possibly sharing one audit class) are written
    # in the order their transitions started.
    module Owner
      HOOKED = :@state_machines_audit_trail_hooked

      # A reload replaces the in-memory record, transitions included, with the
      # database's version
      module Reload
        def reload(*)
          super.tap { Journal.of(self).clear }
        end
      end

      class << self
        def install(owner_class)
          return if owner_class.ancestors.any? { |ancestor| ancestor.instance_variable_get(HOOKED) }

          owner_class.instance_variable_set(HOOKED, true)
          owner_class.prepend(Reload)
          owner_class.after_create { |record| Owner.created(record) }
          owner_class.after_save { |record| Owner.saved(record) }
          owner_class.after_commit { |record| Journal.of(record).committed }
        end

        # The null => initial entry of each audited machine, on every create
        # attempt: a rolled back attempt leaves the record new, and the next
        # one writes them again
        def created(record)
          record.class.state_machines.each_value do |machine|
            machine.send(:audit_initial, record) if machine.audit_trail?
          end
        end

        # Writes, inside the save's database transaction, a row for every noted
        # transition whose state change is in place (Transition#persisted?) and
        # whose row is not written yet.  A row written in a transaction that
        # rolled back (a savepoint, or one enclosing the save) is written again
        # only if this save writes its machine's state again; a savepoint
        # rollback does not restore the in-memory record, so a save after it
        # may not write that state at all.
        def saved(record)
          journal = Journal.of(record)
          transaction = record.class.with_connection(&:current_transaction)

          journal.entries.dup.each do |entry|
            transition = entry.transition
            next unless transition.persisted?
            next if entry.written? && !entry.written_row_lost?

            if entry.written_row_lost? && !record.saved_change_to_attribute?(transition.machine.attribute)
              journal.entries.delete(entry)
              next
            end

            transition.machine.send(:audit_write, record, transition)
            entry.written_in = transaction
          end
        end
      end
    end
  end
end
