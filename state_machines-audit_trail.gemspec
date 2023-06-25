require_relative '' 'lib/state_machines/audit_trail/version'

Gem::Specification.new do |s|
  s.name        = 'state_machines-audit_trail'
  s.version     = StateMachines::AuditTrail::VERSION
  s.authors     = ['Kevin Ross', 'Willem van Bergen', 'Jesse Storimer']
  s.email       = ['kevin.ross@alienfast.com', 'willem@shopify.com', 'jesse@shopify.com']

  s.homepage    = 'https://github.com/state-machines/state_machines-audit_trail'
  s.summary     = %q{Log transitions on a state_machines to support auditing and business process analytics.}
  s.description = %q{Log transitions on a state_machines to support auditing and business process analytics.}
  s.license     = 'MIT'

  s.add_runtime_dependency('state_machines')
  s.add_development_dependency('state_machines-activerecord')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec', '>= 3.0.0')
  s.add_development_dependency('generator_spec')
  s.add_development_dependency('appraisal', '~> 2.2.0')

  s.files = Dir["{lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]
  s.require_paths = ['lib']
end
