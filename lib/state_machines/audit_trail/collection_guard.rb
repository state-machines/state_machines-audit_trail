# frozen_string_literal: true

module StateMachines
  module AuditTrail
    # Prepended to StateMachines::TransitionCollection.  A transition refused
    # by an exception (e.g. raised from a before callback) gets no refusal and
    # runs no after_failure, so nothing else tells its journal it is over.
    # Once core has unwound the collection, its audited transitions whose
    # state change is not in place are forgotten.  Only this collection's
    # transitions: an outer transition whose callback rescues the error is
    # still running and stays noted.
    module CollectionGuard
      def perform(...)
        super
      rescue Exception # rubocop:disable Lint/RescueException -- cleans up, then re-raises whatever it was
        each do |transition|
          Journal.of(transition.object).forget(transition) if transition.machine.audit_trail?
        end
        raise
      end
    end
  end
end
