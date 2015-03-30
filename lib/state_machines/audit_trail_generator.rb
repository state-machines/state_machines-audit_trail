require 'rails/generators'

class StateMachines::AuditTrailGenerator < ::Rails::Generators::Base

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
    generate 'model', args.join(' ')
  end

  protected

  def transition_class_name
    transition_model.blank? ? "#{source_model.camelize}#{state_attribute.camelize}Transition" : transition_model
  end
end
