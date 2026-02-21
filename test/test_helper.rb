# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'

require 'state_machines-audit_trail'

module Minitest
  class Test
    def self.test(description, &)
      define_method(:"test_#{description.gsub(/\W/, '_')}", &)
    end
  end
end
