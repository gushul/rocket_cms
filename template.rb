rails_spec = (Gem.loaded_specs["railties"] || Gem.loaded_specs["rails"])
version = rails_spec.version.to_s

mongoid = options[:skip_active_record]

if Gem::Version.new(version) < Gem::Version.new('4.1.0')
  puts "You are using an old version of Rails (#{version})"
  puts "Please update"
  puts "Stopping"
  exit 1
end

remove_file 'Gemfile'
create_file 'Gemfile' do <<-TEXT
source 'https://rubygems.org'

gem 'rails', '4.1.8'
#{if mongoid then "gem 'mongoid', '~> 4.0.0'" else "gem 'pg'" end}

gem 'sass', '~> 3.4.4'

#{if mongoid then "gem 'rocket_cms_mongoid'" else "gem 'rocket_cms_activerecord'" end}, '~> 0.5.5'

gem 'sass-rails', github: 'rails/sass-rails', ref: '3a9e47db7d769221157c82229fc1bade55b580f0'
gem 'compass-rails', '~> 2.0.0'
gem 'compass', '~> 1.0.0'

gem 'slim-rails'
gem 'rs_russian'
gem 'cancancan'

gem 'cloner'
gem 'unicorn'
gem 'x-real-ip'

gem 'sentry-raven'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry-rails'
  gem 'spring'

  gem 'capistrano', '~> 3.2.0', require: false
  gem 'rvm1-capistrano3', require: false
  gem 'glebtv-capistrano-unicorn', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rails', require: false

  gem 'hipchat'
  gem 'coffee-rails-source-maps'
  gem 'compass-rails-source-maps'
end

group :test do
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'email_spec'
  #{if mongoid then "gem 'glebtv-mongoid-rspec'" else "" end}
  gem 'ffaker'
  gem 'factory_girl_rails'
end

TEXT
end

remove_file '.gitignore'
create_file '.gitignore' do <<-TEXT
# See https://help.github.com/articles/ignoring-files for more about ignoring files.
#
# If you find yourself ignoring temporary files generated by your text editor
# or operating system, you probably want to add a global ignore instead:
#   git config --global core.excludesfile '~/.gitignore_global'

/.bundle
/log/*.log
/tmp
/public/system
/public/ckeditor_assets
/public/assets
#{if mongoid then '/config/mongoid.yml' else '/config/database.yml' end}
/config/secrets.yml
TEXT
end

create_file 'extra/.gitkeep', ''

if mongoid
remove_file 'config/initializers/cookies_serializer.rb'
create_file 'config/initializers/cookies_serializer.rb' do  <<-TEXT
# Be sure to restart your server when you modify this file.
# json serializer breaks Devise + Mongoid. DO NOT ENABLE
# See https://github.com/plataformatec/devise/pull/2882
# Rails.application.config.action_dispatch.cookies_serializer = :json
Rails.application.config.action_dispatch.cookies_serializer = :marshal
TEXT
end
end

remove_file 'app/controllers/application_controller.rb'
create_file 'app/controllers/application_controller.rb' do <<-TEXT
class ApplicationController < ActionController::Base
  include RocketCMS::Controller
end
TEXT
end

create_file 'config/navigation.rb' do <<-TEXT
# empty file to please simple_navigation, we are not using it
# See https://github.com/rs-pro/rocket_cms/blob/master/app/controllers/concerns/rs_menu.rb
TEXT
end

create_file 'README.md', "## #{app_name}\nProject generated by RocketCMS\nORM: #{if mongoid then 'Mongoid' else 'ActiveRecord' end}\n\n"

create_file '.ruby-version', "2.1.5\n"
create_file '.ruby-gemset', "#{app_name}\n"

run 'bundle install --without production'

if mongoid
create_file 'config/mongoid.yml' do <<-TEXT
development:
  sessions:
    default:
      database: #{app_name.downcase}_development
      hosts:
          - localhost:27017
test:
  sessions:
    default:
      database: #{app_name.downcase}_test
      hosts:
          - localhost:27017
TEXT
end
else
remove_file 'config/database.yml'
create_file 'config/database.yml' do <<-TEXT
development:
  adapter: postgresql
  encoding: unicode
  database: #{app_name.downcase}_development
  pool: 5
  username: #{app_name.downcase}
  password: #{app_name.downcase}
  template: template0
TEXT
end
say "Please create a PostgreSQL user #{app_name.downcase} with password #{app_name.downcase} and a database #{app_name.downcase}_development owned by him for development NOW.", :red
ask("Press <enter> when done.", true)
end

unless mongoid
  generate 'simple_captcha'
end

generate "devise:install"
generate "devise", "User"
remove_file "config/locales/devise.en.yml"
remove_file "config/locales/en.yml"

gsub_file 'app/models/user.rb', '# :confirmable, :lockable, :timeoutable and :omniauthable', '# :confirmable, :registerable, :timeoutable and :omniauthable'
gsub_file 'app/models/user.rb', ':registerable,', ' :lockable,'
if mongoid
gsub_file 'app/models/user.rb', '# field :failed_attempts', 'field :failed_attempts'
gsub_file 'app/models/user.rb', '# field :unlock_token', 'field :unlock_token'
gsub_file 'app/models/user.rb', '# field :locked_at', 'field :locked_at'
end

if mongoid
  generate "ckeditor:install", "--orm=mongoid", "--backend=paperclip"
else
  generate "ckeditor:install", "--orm-active_record", "--backend=paperclip"
end

unless mongoid
  generate "rocket_cms:migration"
  generate "rails_admin_settings:migration"
end

generate "rocket_cms:admin"
generate "rocket_cms:ability"
generate "rocket_cms:layout"

unless mongoid
  rake "db:migrate"
end

generate "rspec:install"

remove_file 'config/routes.rb'
create_file 'config/routes.rb' do <<-TEXT
Rails.application.routes.draw do
  devise_for :users
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  mount Ckeditor::Engine => '/ckeditor'

  get 'contacts' => 'contacts#new', as: :contacts
  post 'contacts' => 'contacts#create', as: :create_contacts
  get 'contacts/sent' => 'contacts#sent', as: :contacts_sent

  get 'search' => 'search#index', as: :search

  resources :news, only: [:index, :show]

  root to: 'home#index'

  get '*slug' => 'pages#show'
  resources :pages, only: [:show]
end
TEXT
end

create_file 'config/locales/ru.yml' do <<-TEXT
ru:
  attributes:
    is_default: По умолчанию
  mongoid:
    models:
      item: Товар
    attributes:
      item:
        price: Цена
TEXT
end

remove_file 'db/seeds.rb'

require 'securerandom'
admin_pw = SecureRandom.urlsafe_base64(6)
create_file 'db/seeds.rb' do <<-TEXT
admin_pw = "#{admin_pw}"
User.destroy_all
User.create!(email: 'admin@#{app_name.dasherize.downcase}.ru', password: admin_pw, password_confirmation: admin_pw)
TEXT
end

create_file 'config/initializers/rack.rb' do <<-TEXT
if Rails.env.development?
  module Rack
    class CommonLogger
      alias_method :log_without_assets, :log
      #{'ASSETS_PREFIX = "/#{Rails.application.config.assets.prefix[/\A\/?(.*?)\/?\z/, 1]}/"'}
      def log(env, status, header, began_at)
        unless env['REQUEST_PATH'].start_with?(ASSETS_PREFIX) || env['REQUEST_PATH'].start_with?('/uploads')  || env['REQUEST_PATH'].start_with?('/system')
          log_without_assets(env, status, header, began_at)
        end
      end
    end
  end
end
TEXT
end

create_file 'app/assets/stylesheets/rails_admin/custom/theming.css.sass' do <<-TEXT
body.rails_admin .form-horizontal textarea
  width: 563px
  height: 120px

.page-header
  display: none !important

body > .container-fluid > .row-fluid > .span3
  max-width: 140px

@media screen and (min-width: 910px)
  body > .container-fluid > .row-fluid > .span9
    width: 81.5%

@media screen and (min-width: 1005px)
  body > .container-fluid > .row-fluid > .span9
    width: 83%

@media screen and (min-width: 1150px)
  body > .container-fluid > .row-fluid > .span9
    width: 85%

body.rails_admin .form-horizontal
  .string_type input, .integer_type input, .text_type textarea
    width: 60%

body.rails_admin .modal
  margin-left: -495px !important
  width: 990px !important
  
input[type=checkbox]
  width: 30px !important
TEXT
end

remove_file 'public/robots.txt'
create_file 'public/robots.txt' do <<-TEXT
User-Agent: *
Disallow: /
TEXT
end

port = rand(100..999) * 10

create_file 'unicorn.conf' do <<-TEXT
listen #{port}
worker_processes 1
timeout 120
TEXT
end


remove_file 'app/views/layouts/application.html.erb'


remove_file 'config/application.rb'
create_file 'config/application.rb' do <<-TEXT
require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require "active_model/railtie"
#{'#' if mongoid}require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module #{app_name.camelize}
  class Application < Rails::Application
    config.generators do |g|
      g.test_framework :rspec
      g.view_specs false
      g.helper_specs false
      g.feature_specs false
      g.template_engine :slim
      g.stylesheets false
      g.javascripts false
      g.helper false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
    end

    config.i18n.locale = :ru
    config.i18n.default_locale = :ru
    config.i18n.available_locales = [:ru, :en]
    config.i18n.enforce_available_locales = true
    #{'config.active_record.schema_format = :sql' unless mongoid}

    #{'config.autoload_paths += %W(#{config.root}/extra)'}
    #{'config.eager_load_paths += %W(#{config.root}/extra)'}

    config.time_zone = 'Europe/Moscow'
    config.assets.paths << Rails.root.join("app", "assets", "fonts")
  end
end

TEXT
end

remove_file 'app/assets/stylesheets/application.css'
create_file 'app/assets/stylesheets/application.css.sass' do <<-TEXT
@import 'compass'
@import 'rocket_cms'

#wrapper
  width: 960px
  margin: 0 auto
  #sidebar
    float: left
    width: 200px
  #content
    float: right
    width: 750px

@import "compass/layout/sticky-footer"
+sticky-footer(50px)
TEXT
end

remove_file 'app/assets/javascripts/application.js'
create_file 'app/assets/javascripts/application.js.coffee' do <<-TEXT
#= require rocket_cms
TEXT
end

if mongoid
  FileUtils.cp(Pathname.new(destination_root).join('config', 'mongoid.yml').to_s, Pathname.new(destination_root).join('config', 'mongoid.yml.example').to_s)
else
  FileUtils.cp(Pathname.new(destination_root).join('config', 'database.yml').to_s, Pathname.new(destination_root).join('config', 'database.yml.example').to_s)
end

FileUtils.cp(Pathname.new(destination_root).join('config', 'secrets.yml').to_s, Pathname.new(destination_root).join('config', 'secrets.yml.example').to_s)

unless mongoid
  generate "paper_trail:install"
  generate "friendly_id"
  rake "db:migrate"
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }

