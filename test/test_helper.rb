# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'

# The dummy app only exists to host a bootable Rails::Application for the
# generator test; it has no db/schema.rb and nothing is ever persisted
# through it (the real ActiveRecord coverage in this suite connects its own
# `:memory:` database directly, see test/helpers/active_record.rb). Disable
# Rails' per-worker "parallel test databases" support (on by default) so
# that padded_cell's post-fork hooks don't try to reconstruct a schema that
# doesn't exist.
require 'active_support'
ActiveSupport.parallelize_test_databases = false

require 'rails/test_help'

require 'state_machines-audit_trail'

module Minitest
  class Test
    def self.test(description, &)
      define_method(:"test_#{description.gsub(/\W/, '_')}", &)
    end
  end
end
