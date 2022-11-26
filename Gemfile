source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.1'

gem 'rails', '~> 6.1.4'

gem 'puma', '~> 5.0'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'mini_racer', platforms: :ruby
gem 'jquery-rails', '~> 4.3', '>= 4.3.1'
gem 'slim'
gem 'addressable'
gem 'colorize'
# gem 'omniauth-google-oauth2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

# Elasticsearch
gem 'elasticsearch-rails'
gem 'elasticsearch-persistence'
gem 'elasticsearch-dsl'

group :production do
  # gem 'elastic-apm'
  gem 'sd_notify'
end

group :staging, :development do
  gem 'mail_interceptor'
end

group :development do
  gem 'listen', '>= 3.3.0'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'better_errors'
  gem 'binding_of_caller'
  # gem 'prettier'
  # gem 'eslint-rails'
end
