# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # A record's pending audit entries: every transition started on it (by any
    # audited machine) whose audit row is not committed yet, in the order the
    # transitions started.
    #
    # What a save writes is the record's attribute set (its +@attributes+),
    # and that is what the journal belongs to: it is kept on the attribute set
    # itself, so it lives exactly as long as the set and is shared by every
    # instance holding it - a +clone+, a +becomes+ copy, a record that
    # +reload+ed into the set a find built - while a +dup+ or a freshly built
    # or loaded record gets a set, and so a journal, of its own.  Where
    # ActiveRecord gives a record a new set for the same row (see .migrate),
    # the record's entries follow it.  A Marshal round trip (e.g. a cache
    # write) drops it.
    class Journal
      # Instance variable holding an attribute set's Journal
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
        # The database transaction its row was last written in
        attr_accessor :written_in
        # Whether its state change was in place when the save under way wrote
        # the record's row (see Journal#snapshot)
        attr_accessor :in_saved_row

        def initialize(transition)
          @transition = transition
        end

        def written?
          !written_in.nil?
        end

        # What the save of +record+ under way does with it: :write its row,
        # :drop it, or leave it (nil).  Only a state change in place when the
        # save wrote the record's row is in that row.  A row written in a
        # transaction that rolled back (a savepoint, or one enclosing the save)
        # is written again only if this save writes its machine's state again:
        # a savepoint rollback does not restore the in-memory record, so a save
        # after it may not write that state at all.
        def disposition(record)
          return unless in_saved_row && transition.persisted?
          return :write unless written?
          return unless written_row_lost?

          record.saved_change_to_attribute?(transition.machine.attribute) ? :write : :drop
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
        for_attributes(record.instance_variable_get(:@attributes))
      end

      # A frozen set (a destroyed or frozen record's) cannot take a journal and
      # never writes a transition: it gets a throwaway one
      def self.for_attributes(attributes)
        attributes.instance_variable_get(IVAR) ||
          (attributes.frozen? ? new : attributes.instance_variable_set(IVAR, new))
      end

      # ActiveRecord replaced the record's attribute set +from+ with +to+ for
      # the same row: in the middle of a save (changes_applied, which runs
      # before the after_save callbacks), on a rollback, on freeze.  The
      # entries that are the record's go with it: every state change in place
      # in +from+ (the save under way is writing it, whichever holder ran
      # it), rows already written, and the transitions running on the record
      # itself.  Other holders of +from+ (clones) keep only the transitions
      # they are still running; anything they do afterwards is theirs.
      def self.migrate(record, from, to)
        return if from.nil? || from.equal?(to)

        old = from.instance_variable_get(IVAR)
        return unless old

        moving, staying = old.entries.partition do |entry|
          entry.written? || entry.transition.persisted? || entry.transition.object.equal?(record)
        end
        old.entries.replace(staying)
        for_attributes(to).entries.concat(moving)
      end

      # A reload gave the record the attribute set a fresh find built, which
      # discards the state changes it had not saved.  A transition still
      # running on the record (noted, neither in place nor refused yet - e.g.
      # one whose around callback takes a lock with +with_lock+ / +lock!+)
      # carries on in the new set, and is followed there.
      def self.carry_running(record, from, to)
        return if from.nil? || from.equal?(to)

        old = from.instance_variable_get(IVAR)
        return unless old

        running, staying = old.entries.partition do |entry|
          transition = entry.transition
          transition.object.equal?(record) && !transition.persisted? && transition.refusal.nil?
        end
        old.entries.replace(staying)
        for_attributes(to).entries.concat(running)
      end

      attr_reader :entries

      def initialize
        @entries = []
      end

      # The record's row has just been written (changes_applied): only the
      # state changes in place now are in it.  A transition made later in the
      # same save (an after_create, an earlier after_save) waits for the next.
      def snapshot
        entries.each { |entry| entry.in_saved_row = entry.transition.persisted? }
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
