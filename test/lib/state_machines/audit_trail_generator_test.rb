# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'rails/generators/test_case'
require 'state_machines/audit_trail_generator'

class AuditTrailGeneratorTest < Rails::Generators::TestCase
  tests StateMachines::AuditTrailGenerator
  destination File.expand_path('../../../tmp', __dir__)

  setup do
    prepare_destination
  end

  def test_generator_with_default_state_attribute
    run_generator %w[User]

    assert_file 'app/models/user_state_transition.rb' do |content|
      assert_match(/class UserStateTransition < ApplicationRecord/, content)
    end

    assert_migration 'db/migrate/create_user_state_transitions.rb' do |content|
      assert_match(/create_table :user_state_transitions/, content)
      assert_match(/t\.references :user/, content)
      assert_match(/t\.string :namespace/, content)
      assert_match(/t\.string :event/, content)
      assert_match(/t\.string :from/, content)
      assert_match(/t\.string :to/, content)
      assert_match(/t\.timestamp :created_at/, content)
    end
  end

  def test_generator_with_custom_state_attribute
    run_generator %w[Order status]

    assert_file 'app/models/order_status_transition.rb' do |content|
      assert_match(/class OrderStatusTransition < ApplicationRecord/, content)
    end

    assert_migration 'db/migrate/create_order_status_transitions.rb' do |content|
      assert_match(/create_table :order_status_transitions/, content)
      assert_match(/t\.references :order/, content)
    end
  end

  def test_generator_with_custom_transition_model
    run_generator %w[Subscription state SubscriptionEvent]

    assert_file 'app/models/subscription_event.rb' do |content|
      assert_match(/class SubscriptionEvent < ApplicationRecord/, content)
    end

    assert_migration 'db/migrate/create_subscription_events.rb' do |content|
      assert_match(/create_table :subscription_events/, content)
      assert_match(/t\.references :subscription/, content)
    end
  end

  def test_generator_with_namespaced_model
    run_generator %w[SomeModule::Account]

    assert_file 'app/models/some_module/account_state_transition.rb' do |content|
      assert_match(/class SomeModule::AccountStateTransition < ApplicationRecord/, content)
    end

    assert_migration 'db/migrate/create_some_module_account_state_transitions.rb' do |content|
      assert_match(/create_table :some_module_account_state_transitions/, content)
      assert_match(/t\.references :account/, content)
    end
  end

  private

  def assert_migration(file, &)
    migration_file = Dir[File.join(destination_root, file.gsub(/^\d+_/, '*'))].first

    assert migration_file, "Expected migration #{file} to exist"
    assert_file(migration_file, &)
  end
end
