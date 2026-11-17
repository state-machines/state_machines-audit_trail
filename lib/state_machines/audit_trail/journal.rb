# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # A record's pending audit entries: every transition started on it (by any
    # audited machine) whose audit row is not committed yet, in the order the
    # transitions started.
    #
    # It holds live transitions of the in-memory record's attributes: it is
    # created with the record (Owner's after_initialize), so a +clone+ (which
    # shares the attributes) shares it, while a +dup+ (a new record) and a
    # +reload+ (new attributes for that instance only) detach onto a fresh one
    # (see Owner::Record).  A Marshal round trip (e.g. a cache write) drops it.
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

        # Whether its row is committed for good: written in a real transaction
        # that committed, or in a savepoint that was released when no
        # transaction is left open (a rollback of an enclosing transaction
        # would have rolled the savepoint back too)
        def written_row_final?(transaction_open)
          return false unless written?

          state = written_in.state
          state.fully_committed? || (state.committed? && !transaction_open)
        end
      end

      def self.of(record)
        record.instance_variable_get(IVAR) || record.instance_variable_set(IVAR, new)
      end

      # Gives the record a fresh journal, leaving the one it shared (with a
      # clone) to the other copies
      def self.detach(record)
        record.instance_variable_set(IVAR, new)
      end

      attr_reader :entries

      def initialize
        @entries = []
      end

      # Notes a transition (once, however many copies of the noting callback run)
      def note(transition)
        prune(transition.object.class.with_connection(&:transaction_open?))
        entries << Entry.new(transition) unless entry_for(transition)
      end

      # Drops the entries that are done: rows committed for good, and
      # transitions core refused (Transition#refusal) whose state change is
      # not in place.  A transition still running has no refusal (each perform
      # clears it), so this never drops one that a save happening inside its
      # callbacks would otherwise miss; one refused by an exception is
      # forgotten as the exception leaves its collection (see CollectionGuard).
      def prune(transaction_open)
        entries.reject! do |entry|
          entry.written_row_final?(transaction_open) || (entry.transition.refusal && !entry.transition.persisted?)
        end
      end

      # Drops a refused transition, unless its state change is in place after all
      def forget(transition)
        entries.reject! { |entry| entry.transition.equal?(transition) && !entry.transition.persisted? }
      end

      # The first transition of the named machine whose state change is in place
      def first_persisted(machine_name)
        entries.map(&:transition).find { |transition| transition.machine.name == machine_name && transition.persisted? }
      end

      def marshal_dump
        nil
      end

      def marshal_load(_)
        @entries = []
      end

      private

      def entry_for(transition)
        entries.find { |entry| entry.transition.equal?(transition) }
      end
    end
  end
end
