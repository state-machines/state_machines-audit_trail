# frozen_string_literal: true

require 'rails/generators'

module StateMachines
  class AuditTrailGenerator < Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')

    argument :source_model
    argument :state_attribute, default: 'state'
    argument :transition_model, default: ''

    def create_model
      args = [transition_class_name,
              "#{source_model.demodulize.tableize.singularize}:references",
              'namespace:string',
              'event:string',
              'from:string',
              'to:string',
              'created_at:timestamp',
              '--no-timestamps',
              '--no-fixtures']
      # inline: true runs the model generator in-process (via Rails::Command.invoke)
      # instead of shelling out to `bin/rails`, which isn't guaranteed to exist
      # relative to the destination_root used by generator tests.
      generate 'model', args.join(' '), inline: true
    end

    protected

    def transition_class_name
      transition_model.blank? ? "#{source_model.camelize}#{state_attribute.camelize}Transition" : transition_model
    end
  end
end
