source 'https://rubygems.org'

gem 'rails'
gem 'tzinfo-data' # needed by windows
gem 'mysql2'
gem 'refinerycms'
gem 'refinerycms-authentication-devise'
gem 'refinerycms-wymeditor'
# We use this version of refinerycms-i18n because of the crash in story 1831.
# IT MUST BE REMOVED on bump of refinery to version 5
gem 'refinerycms-i18n', '4.0.2', git: 'https://github.com/refinery/refinerycms-i18n',
                                 ref: '30059ea'
# See above
gem 'mongoid'
gem 'mongo'
gem 'execjs'
# gem 'libv8'
gem 'mobvious'
gem 'formtastic'
# gem 'therubyracer', platforms: :ruby # avoid loading on windows
gem 'airbrake'
#  gem 'bcrypt', git: 'https://github.com/codahale/bcrypt-ruby'
gem 'bcrypt'
gem 'text'
gem 'json'
gem 'pry'
gem 'pry-byebug'
gem 'email_veracity'
gem 'unicode'
gem 'kaminari'
gem 'kaminari-mongoid'
gem 'gretel'
gem 'geocoder', '1.3.7' # appears to be a regression in 1.4
gem 'bourbon'
gem 'mail-logger'
gem 'devise'
gem 'devise-encryptable'
gem 'nokogiri', '>= 1.13.6'
gem 'osgb', git: 'https://github.com/FreeUKGen/osgb.git'
gem 'rubyzip'
gem 'zip-zip'
gem 'rspec-rails'
gem 'carrierwave-mongoid', require: 'carrierwave/mongoid'
gem 'simple_form'
gem 'newrelic_rpm'
gem 'octokit'
gem 'traceroute'
gem 'sass-rails' # ,   '~> 3.2.3'
gem 'coffee-rails' # , '~> 3.2.1'
gem 'uglifier' # , '>= 1.0.3'
gem 'jquery-rails'
gem 'font_awesome5_rails'
gem 'refinerycms-county_pages', path: 'vendor/extensions'
gem 'rubocop-rails'
gem 'rubocop', '~> 1.23.0', require: false
gem 'browser'

group :development, :test do
  gem 'letter_opener'
  gem 'erb-formatter'

  gem 'solargraph-reek'

  gem 'capybara'
  gem 'selenium-webdriver'
 
  gem 'shoulda-matchers'
  gem 'faker', require: false # for sample data in development
end

group :development do
  gem 'web-console'
end
