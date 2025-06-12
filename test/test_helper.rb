# frozen_string_literal: true

require 'minitest/autorun'
require 'state_machines-audit_trail'

module Minitest
  class Test
    def self.test(description, &)
      define_method(:"test_#{description.gsub(/\W/, '_')}", &)
    end
  end
end
