module PbsSite
  class App < Padrino::Application
    register WillPaginate::Sinatra
    register CoffeeInitializer
    register ScssInitializer
    register Padrino::Rendering
    register Padrino::Mailer
    register Padrino::Helpers
    register Padrino::Admin::AccessControl

    enable :sessions
    enable :absolute_redirects

    # Authentication.
    enable :authentication
    enable :store_location
    set    :login_page, "/sessions/new"

    # Remote server.
    set    :worker_server, 'druby://localhost:5555'

    access_control.roles_for :any do |role|
      role.allow    "/sessions"
      role.allow    "/accounts/new"
      role.allow    "/accounts/create"
      role.allow    "/jobs/response"
      role.allow    "/jobs/completed"
      role.protect  "/accounts"
      role.protect  "/jobs"
      role.protect  "/irap"

      # Only for demo purposes.
      role.allow    "/jobs/job"
      role.allow    "/jobs/transcript"
      role.allow    "/jobs/protein"
    end

    set :delivery_method, :smtp => {
      :address              => "smtp.gmail.com",
      :port                 => 587,
      :user_name            => settings.main_conf['notification']['email'],
      :password             => settings.main_conf['notification']['password'],
      :authentication       => :plain,
      :enable_starttls_auto => true
    }

    ##
    # Caching support.
    #
    # register Padrino::Cache
    # enable :caching
    #
    # You can customize caching store engines:
    #
    # set :cache, Padrino::Cache.new(:LRUHash) # Keeps cached values in memory
    # set :cache, Padrino::Cache.new(:Memcached) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Memcached, '127.0.0.1:11211', :exception_retry_limit => 1)
    # set :cache, Padrino::Cache.new(:Memcached, :backend => memcached_or_dalli_instance)
    # set :cache, Padrino::Cache.new(:Redis) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Redis, :host => '127.0.0.1', :port => 6379, :db => 0)
    # set :cache, Padrino::Cache.new(:Redis, :backend => redis_instance)
    # set :cache, Padrino::Cache.new(:Mongo) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Mongo, :backend => mongo_client_instance)
    # set :cache, Padrino::Cache.new(:File, :dir => Padrino.root('tmp', app_name.to_s, 'cache')) # default choice

    ##
    # Application configuration options.
    #
    # set :raise_errors, true       # Raise exceptions (will stop application) (default for test)
    # set :dump_errors, true        # Exception backtraces are written to STDERR (default for production/development)
    # set :show_exceptions, true    # Shows a stack trace in browser (default for development)
    # set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
    # set :public_folder, 'foo/bar' # Location for static assets (default root/public)
    # set :reload, false            # Reload application files (default in development)
    # set :default_builder, 'foo'   # Set a custom form builder (default 'StandardFormBuilder')
    # set :locale_path, 'bar'       # Set path for I18n translations (default your_apps_root_path/locale)
    # disable :sessions             # Disabled sessions by default (enable if needed)
    # disable :flash                # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
    layout  :main            # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
    #

    ##
    # You can configure for a specified environment like:
    #
    #   configure :development do
    #     set :foo, :bar
    #     disable :asset_stamp # no asset timestamping for dev
    #   end
    #

    error(403) { @title = "Error 403"; render('errors/403') }
    error(404) { @title = "Error 404"; render('errors/404') }
    error(500) { @title = "Error 500"; render('errors/500') }

    ##
    # You can manage errors like:
    #
    #   error 404 do
    #     render 'errors/404'
    #   end
    #
    #   error 505 do
    #     render 'errors/505'
    #   end
    #
  end
end
