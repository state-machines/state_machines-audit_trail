# frozen_string_literal: true

require_relative 'lib/state_machines/audit_trail/version'

Gem::Specification.new do |s|
  s.name        = 'state_machines-audit_trail'
  s.version     = StateMachines::AuditTrail::VERSION
  s.authors     = ['Kevin Ross', 'Willem van Bergen', 'Jesse Storimer']
  s.email       = ['kevin.ross@alienfast.com', 'willem@shopify.com', 'jesse@shopify.com']

  s.homepage    = 'https://github.com/state-machines/state_machines-audit_trail'
  s.summary     = 'Log transitions on a state_machines to support auditing and business process analytics.'
  s.description = 'Log transitions on a state_machines to support auditing and business process analytics. ActiveRecord integration.'
  s.license     = 'MIT'

  s.add_dependency('state_machines', '>= 0.10.0')
  s.add_development_dependency('appraisal')
  s.add_development_dependency('minitest', '~> 5.0')
  s.add_development_dependency('rake')

  s.files = Dir['{lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.require_paths = ['lib']
  s.metadata['rubygems_mfa_required'] = 'true'
end
