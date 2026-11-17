# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # The callbacks audit_trail installs on the model owning the machines, once
    # per class hierarchy.  They act on the record's Journal as a whole, so the
    # rows of several machines (possibly sharing one audit class) are written
    # in the order their transitions started.
    module Owner
      HOOKED = :@state_machines_audit_trail_hooked

      # A dup is a new record with new attributes, and a reload gives the
      # reloaded instance new attributes: both detach onto a fresh journal.  A
      # clone shares the attributes, and so keeps sharing the journal (also
      # when the other copy is reloaded).
      module Record
        def reload(*)
          super.tap { Journal.detach(self) }
        end

        # Before super: the dup's after_initialize callbacks run inside it
        def initialize_dup(other)
          Journal.detach(self)
          super
        end
      end

      class << self
        # Installs the callbacks on the owner class, once per class.  A class
        # whose ancestor installs them later (a subclass declaring audit_trail
        # before its parent) inherits a second set; only the set installed
        # highest in the record's class hierarchy acts.
        def install(owner_class)
          return if owner_class.instance_variable_get(HOOKED)

          owner_class.instance_variable_set(HOOKED, true)
          owner_class.prepend(Record)
          # Created with the record, so a clone made before any transition shares it
          owner_class.after_initialize { |record| Journal.of(record) }
          owner_class.after_create { |record| Owner.created(record) if Owner.acting?(record, owner_class) }
          owner_class.after_save { |record| Owner.saved(record) if Owner.acting?(record, owner_class) }
          owner_class.after_commit { |record| Owner.committed(record) if Owner.acting?(record, owner_class) }
        end

        def acting?(record, installer)
          record.class.ancestors.reverse_each.find { |ancestor| ancestor.instance_variable_get(HOOKED) }.equal?(installer)
        end

        # The record's commit callbacks also run when a savepoint inside a
        # non-joinable transaction is released, while that transaction can
        # still roll its rows back: the entries then wait for the transaction
        # still open to commit (a rollback drops the callback and leaves them
        # lost).  The public after-commit hooks treat a non-joinable
        # transaction as absent, so this registers on the connection's
        # current transaction itself.
        def committed(record)
          journal = Journal.of(record)
          record.class.with_connection do |connection|
            if connection.transaction_open?
              connection.current_transaction.after_commit { committed(record) }
            else
              journal.prune(false)
            end
          end
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
          journal.prune(true)
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
