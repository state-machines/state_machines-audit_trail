# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_machines/audit_trail/version'

Gem::Specification.new do |s|
  s.name        = 'state_machines-audit_trail'
  s.version     = StateMachines::AuditTrail::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Kevin Ross', 'Willem van Bergen', 'Jesse Storimer']
  s.email       = ['kevin.ross@alienfast.com', 'willem@shopify.com', 'jesse@shopify.com']

  s.homepage    = 'https://github.com/state-machines/state_machines-audit_trail'
  s.summary     = %q{Log transitions on a state_machines to support auditing and business process analytics.}
  s.description = %q{Log transitions on a state_machines to support auditing and business process analytics.}
  s.license     = 'MIT'

  s.add_runtime_dependency('state_machines')

  s.add_development_dependency('state_machines-activerecord')
  s.add_development_dependency('state_machines-mongoid')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec', '>= 3.0.0')
  s.add_development_dependency('activerecord', '>= 4.0.0')
  s.add_development_dependency('sqlite3')
  s.add_development_dependency('mongoid', '>= 4.0.0')
  s.add_development_dependency('bson_ext')
  s.add_development_dependency('generator_spec')
  s.add_development_dependency('rails', '>= 4.0.0')

  s.files = `git ls-files`.split($/).reject { |f| f =~ /^samples\// }
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']
end
