# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # A record's audit bookkeeping, one Trail per machine name.  It holds live
    # transitions of this one in-memory record, so it belongs to the record it
    # was made for: a +dup+ (which copies instance variables) starts its own,
    # and a Marshal round trip (e.g. a cache write) drops it.
    class Trails
      # Instance variable holding a record's Trails
      IVAR = :@state_machines_audit_trail

      # The null => initial entry of a new record
      InitialTransition = Data.define(:namespace, :to) do
        def from = nil
        def event = nil
        def machine = nil
        def args = nil
      end

      # A transition committed on a new record, written when it is created
      UnsavedTransition = Data.define(:transition, :loggable)

      # * in_flight - transitions inside the audit around callback, whose
      #   outcome is not known yet
      # * unsaved - transitions committed while the record was new, oldest first
      Trail = Data.define(:in_flight, :unsaved) do
        def initialize(in_flight: [], unsaved: []) = super
      end

      def self.of(object)
        trails = object.instance_variable_get(IVAR)
        return trails if trails&.owned_by?(object)

        object.instance_variable_set(IVAR, new(object))
      end

      def initialize(owner)
        @owner = owner
        @trails = {}
      end

      def [](machine_name)
        @trails[machine_name] ||= Trail.new
      end

      def owned_by?(object)
        @owner.equal?(object)
      end

      def marshal_dump
        nil
      end

      def marshal_load(_)
        @owner = nil
        @trails = {}
      end
    end
  end
end
