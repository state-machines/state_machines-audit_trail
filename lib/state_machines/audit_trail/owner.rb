# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # The callbacks audit_trail installs on the model owning the machines, once
    # per class hierarchy.  They act on the record's Journal as a whole, so the
    # rows of several machines (possibly sharing one audit class) are written
    # in the order their transitions started.
    module Owner
      HOOKED = :@state_machines_audit_trail_hooked

      # The points where ActiveRecord gives a record a new attribute set for
      # the same row; its journal entries follow (Journal.migrate).  The ones
      # that hand out a set built elsewhere - reload (the fresh find's),
      # becomes (shared), clone (shared), dup / new / find (a new one) - need
      # nothing: the journal is the set's.
      module Record
        def reload(*)
          from = @attributes
          super.tap { Journal.carry_over(self, from, @attributes) }
        end

        def freeze
          from = @attributes
          super.tap { Journal.migrate(self, from, @attributes) }
        end

        private

        # ActiveModel::Dirty: changes_applied (during a save, right after the
        # row is written and before the after_create / after_save callbacks)
        # and clear_changes_information
        def forget_attribute_assignments
          from = @attributes
          super.tap do
            Journal.migrate(self, from, @attributes)
            Save.current(self)&.row_written(self, Journal.of(self))
          end
        end

        # ActiveRecord: one save, callbacks included
        def create_or_update(...)
          Save.around(self) { super }
        end

        # ActiveRecord::Transactions, when a rolled back save restores the record
        def restore_transaction_record_state(...)
          from = @attributes
          super.tap { Journal.migrate(self, from, @attributes) }
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
          Journal.guard_copies
          # A copy per class: a subclass that installed first would otherwise
          # carry the same module twice in its ancestors, and TruffleRuby's
          # super from the outer copy re-enters it forever.
          owner_class.prepend(Record.dup)
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

        # Writes, inside the save's database transaction, the rows of the
        # transitions this save audits (see Save)
        def saved(record)
          journal = Journal.of(record)
          journal.prune(true)
          save = Save.current(record)
          return unless save

          transaction = record.class.with_connection(&:current_transaction)
          writing, dropping = save.take(journal)
          writing.each do |entry|
            entry.transition.machine.send(:audit_write, record, entry.transition)
            entry.written_in = transaction
          end
          journal.entries.reject! { |entry| dropping.include?(entry) }
        end
      end
    end
  end
end
