# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # One save of a record (ActiveRecord's create_or_update), and which noted
    # transitions it audits: those whose state change was in place when it
    # wrote the record's row (changes_applied, just after the INSERT/UPDATE
    # and before the after_create / after_save callbacks).  A transition made
    # later in the same save waits for the next one.
    #
    # Saves nest (an after_save saving the record again), so each record keeps
    # a stack of them on the instance; a nested save rolled back in a
    # savepoint loses only the rows it wrote, which the save around it, whose
    # row still holds those states, writes again.
    class Save
      IVAR = :@state_machines_audit_trail_saves

      class << self
        def stack(record)
          record.instance_variable_get(IVAR) || record.instance_variable_set(IVAR, [])
        end

        def current(record)
          record.instance_variable_get(IVAR)&.last
        end

        def around(record)
          stack(record).push(new)
          yield
        ensure
          saves = stack(record)
          saves.pop
          record.remove_instance_variable(IVAR) if saves.empty?
        end

        # The entries the open saves of the record still owe a row: what each
        # one's after_save will write (see #owed)
        def owed(record)
          (record.instance_variable_get(IVAR) || []).flat_map(&:owed)
        end
      end

      attr_reader :to_write, :to_drop

      def initialize
        @to_write = []
        @to_drop = []
      end

      # The record's row has just been written.  A row lost to a rolled back
      # transaction is written again only if this row writes its machine's
      # state again: a savepoint rollback does not restore the in-memory
      # record, so a save after it may not write that state at all.
      def row_written(record, journal)
        @to_write = []
        @to_drop = []
        journal.entries.each do |entry|
          transition = entry.transition
          next unless transition.persisted?

          if !entry.written?
            @to_write << entry
          elsif entry.written_row_lost?
            (record.saved_change_to_attribute?(transition.machine.attribute) ? @to_write : @to_drop) << entry
          end
        end
      end

      # What this save's after_save will write: entries still in place whose
      # row is not written, or was written by a nested save that rolled back
      def owed
        to_write.select { |entry| entry.transition.persisted? && (!entry.written? || entry.written_row_lost?) }
      end

      # The after_save: what to write now, and what to drop.  Only entries
      # still in the record's journal - the one record of what is owed; the
      # frame only points at them.
      def take(journal)
        tracked = ->(entry) { journal.entries.any? { |noted| noted.equal?(entry) } }
        writing = owed.select(&tracked)
        dropping = to_drop.select(&:written_row_lost?)
        @to_write = []
        @to_drop = []
        [writing, dropping]
      end
    end
  end
end
