# FIXME: Unable to get this test to run, though the generator does work.  Someone fix me please.
#
# require 'rails'
# require 'spec_helper'
# require 'state_machines-activerecord'
# require 'rails/generators/active_model'
# require 'state_machines/audit_trail_generator'
# require 'generator_spec'
#
# describe StateMachines::AuditTrailGenerator, type: :generator do
#
#   destination File.expand_path('../../../../tmp', __FILE__)
#   arguments %w(SomeNamespace::Subscription state)
#
#   before(:all) do
#     prepare_destination
#   end
#
#   # create    db/migrate/20150326190913_create_some_namespace_subscription_state_transitions.rb
#   # create    app/models/some_namespace/subscription_state_transition.rb
#   # create    app/models/some_namespace.rb
#   # invoke    test_unit
#   # create      test/models/some_namespace/subscription_state_transition_test.rb
#   # invoke      factory_girl
#   # create        test/factories/af_core_subscription_state_transitions.rb
#
#
#   specify do
#     run_generator
#     expect(destination_root).to have_structure {
#                                   # no_file 'test.rb'
#                                   directory 'app' do
#                                     directory 'models' do
#                                       file 'some_namespace.rb' do
#                                         contains 'def self.table_name_prefix'
#                                       end
#                                       directory 'some_namespace' do
#                                         file 'subscription_state_transition.rb' do
#                                           contains 'class SomeNamespace::SubscriptionStateTransition'
#                                         end
#                                       end
#                                     end
#                                   end
#                                   directory 'db' do
#                                     directory 'migrate' do
#                                       file '123_create_some_namespace_subscription_state_transitions.rb'
#                                       migration 'create_tests' do
#                                         contains 'class TestMigration'
#                                       end
#                                     end
#                                   end
#                                 }
#   end
# end