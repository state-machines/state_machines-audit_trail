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

        def initialize(transition)
          @transition = transition
        end

        def written?
          !written_in.nil?
        end

        # Noted on the record and neither in place nor refused yet
        def running_on?(record)
          transition.object.equal?(record) && !transition.persisted? && transition.refusal.nil?
        end

        # Written in a transaction that is still open (neither committed for
        # good nor rolled back)
        def written_row_pending?(transaction_open)
          written? && !written_row_lost? && !written_row_final?(transaction_open)
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

      # The attribute set a record's attributes live in.  Rails main wraps a
      # +becomes+ copy's set in an ActiveModel::ReindexedAttributeSet whose
      # shared side is the original set; the journal is that set's.
      def self.attribute_set(attributes)
        attributes = attributes.instance_variable_get(:@shared) while reindexed?(attributes)
        attributes
      end

      def self.reindexed?(attributes)
        defined?(::ActiveModel::ReindexedAttributeSet) && attributes.is_a?(::ActiveModel::ReindexedAttributeSet)
      end

      # A copy of a set (dup, clone - e.g. LazyIndexedAttributeSet#map and
      # #deep_dup on Rails main build theirs with +dup+) is a different set:
      # it must not inherit the journal through its copied instance variables.
      # Prepended to ActiveModel::AttributeSet.
      module CopyGuard
        def initialize_copy(source)
          super
          remove_instance_variable(IVAR) if instance_variable_defined?(IVAR)
        end
      end

      def self.guard_copies
        return if ::ActiveModel::AttributeSet <= CopyGuard

        ::ActiveModel::AttributeSet.prepend(CopyGuard)
      end

      # A frozen set (a destroyed or frozen record's) cannot take a journal and
      # never writes a transition: it gets a throwaway one
      def self.for_attributes(attributes)
        attributes = attribute_set(attributes)
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
        return if from.nil?

        from = attribute_set(from)
        return if from.equal?(attribute_set(to))

        old = from.instance_variable_get(IVAR)
        return unless old

        moving, staying = old.entries.partition do |entry|
          entry.written? || entry.transition.persisted? || entry.transition.object.equal?(record)
        end
        old.entries.replace(staying)
        for_attributes(to).entries.concat(moving)
      end

      # A reload gave the record the attribute set a fresh find built, which
      # discards the state changes it had not saved but holds those the
      # database (or a transaction still open) does.  The entries that follow
      # it there:
      # * a transition still running on the record (noted, neither in place
      #   nor refused yet - e.g. one whose callback takes a lock with
      #   +with_lock+ / +lock!+);
      # * one a save under way wrote into its row and still owes a row (a reload
      #   from an after_create / after_save running before audit_trail's),
      #   including one whose row a nested save wrote and rolled back;
      # * one whose row is written in a transaction still open, which can
      #   still roll that row back (and restore the state in memory) - the
      #   next save of that state must write it again.
      # Only completed transitions never saved, and rows committed for good
      # (or already lost), stay behind.
      def self.carry_over(record, from, to)
        return if from.nil?

        from = attribute_set(from)
        return if from.equal?(attribute_set(to))

        old = from.instance_variable_get(IVAR)
        return unless old

        saving = Save.owed(record)
        transaction_open = record.class.with_connection(&:transaction_open?)
        running, staying = old.entries.partition do |entry|
          entry.running_on?(record) || saving.include?(entry) || entry.written_row_pending?(transaction_open)
        end
        old.entries.replace(staying)
        for_attributes(to).entries.concat(running)
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
