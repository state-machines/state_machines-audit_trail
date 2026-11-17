# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # A record's pending audit entries: every transition started on it (by any
    # audited machine) whose audit row is not committed yet, in the order the
    # transitions started.
    #
    # It holds live transitions of this one in-memory record, so it belongs to
    # the record it was made for: a +dup+ (which copies instance variables)
    # starts its own, and a Marshal round trip (e.g. a cache write) drops it.
    class Journal
      # Instance variable holding a record's Journal
      IVAR = :@state_machines_audit_trail

      # The null => initial entry of a new record
      InitialTransition = Data.define(:namespace, :to) do
        def from = nil
        def event = nil
        def machine = nil
        def args = nil
      end

      # A noted transition, and the database transaction its row was last
      # written in (nil until written)
      class Entry
        attr_reader :transition
        attr_accessor :written_in

        def initialize(transition)
          @transition = transition
        end

        def written?
          !written_in.nil?
        end

        # Whether the transaction its row was written in rolled back (a
        # savepoint's, or one enclosing it), taking the row with it
        def written_row_lost?
          written? && written_in.state.rolledback?
        end
      end

      def self.of(record)
        journal = record.instance_variable_get(IVAR)
        return journal if journal&.owned_by?(record)

        record.instance_variable_set(IVAR, new(record))
      end

      attr_reader :entries

      def initialize(owner)
        @owner = owner
        @entries = []
      end

      def owned_by?(record)
        @owner.equal?(record)
      end

      # Notes a transition (once, however many copies of the noting callback run)
      def note(transition)
        entries << Entry.new(transition) unless entry_for(transition)
      end

      # Drops a refused transition, unless its state change is in place after all
      def forget(transition)
        entries.reject! { |entry| entry.transition.equal?(transition) && !entry.transition.persisted? }
      end

      # The first transition of the named machine whose state change is in place
      def first_persisted(machine_name)
        entries.map(&:transition).find { |transition| transition.machine.name == machine_name && transition.persisted? }
      end

      # The rows are committed: their entries are done
      def committed
        entries.reject! { |entry| entry.written? && !entry.written_row_lost? }
      end

      # Everything noted described the record as it was in memory; a reload
      # replaced that with the database's version
      def clear
        entries.clear
      end

      def marshal_dump
        nil
      end

      def marshal_load(_)
        @owner = nil
        @entries = []
      end

      private

      def entry_for(transition)
        entries.find { |entry| entry.transition.equal?(transition) }
      end
    end
  end
end
