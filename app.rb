$: << File.expand_path(File.dirname(__FILE__) + '/lib')
require 'rubygems'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/reloader'
require 'sinatra/session'
require 'logger'
require 'rack-flash'
require 'core_ext/kernel'
require 'core_ext/string'
require 'core_ext/nil_class'
require 'core_ext/fixnum'
require 'core_ext/ipaddr'
require 'erubis'
require 'attributes_to_liquid_methods_mapper'
require 'uuidtools'
require 'active_record'
require 'activerecord-postgres-hstore'
require 'activerecord-postgres-hstore/activerecord'
require 'optopus'
require 'tire'
require 'tire_monkey_patches'
require 'liquid'
require 'postgres_ext'

module Optopus
  class App < Sinatra::Base
    register Sinatra::ConfigFile
    register Sinatra::Session
    config_file ENV['OPTOPUS_CONFIG_FILE'] || File.expand_path(File.dirname(__FILE__) + '/config/application.yaml')
    set :root, File.dirname(__FILE__)
    enable :logging
    enable :sessions
    enable :method_override
    use Rack::Flash

    register Optopus::Auth
    register do
      def auth(role_name)
        condition do
          handle_unauthorized_access unless (role_name == :user) ? is_user? : is_authorized?(role_name)
        end
      end
    end

    register Optopus::Plugins

    db_config_file = ENV['OPTOPUS_DATABASE_CONFIG_FILE'] || File.join(File.dirname(__FILE__), 'config', 'databases.yaml')
    db_config = YAML::load(File.open(db_config_file))[Optopus::App.environment.to_s]
    ActiveRecord::Base.establish_connection(db_config)
    Tire::Configuration.url settings.elasticsearch[:url]

    # Override the default find_template method so that we search through each plugins views_path
    set :views, settings.optopus_plugins.inject([]) { |v, p| v << p[:views_path] if p.include?(:views_path) } << 'views'
    helpers do
      def find_template(views, name, engine, &block)
        Array(views).each { |v| super(v, name, engine, &block) }
      end

      def node_partials
        settings.partials[:node]
      end
    end
  end
end

require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'
