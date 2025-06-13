# frozen_string_literal: true

require_relative 'boot'
require 'rails/all'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.eager_load = false
    config.secret_key_base = 'test'
    config.active_support.test_order = :random

    # Set root path for dummy app
    config.root = File.expand_path('..', __dir__)

    # Force test environment
    config.cache_classes = true
    config.public_file_server.enabled = false
    config.consider_all_requests_local = true
    config.cache_store = :null_store
    config.action_dispatch.show_exceptions = false
    config.action_controller.allow_forgery_protection = false

    # Disable logging for tests
    config.logger = Logger.new(nil)
    config.log_level = :fatal

    # Generator configuration
    config.generators do |g|
      g.test_framework :minitest
      g.orm :active_record
    end
  end
end
