source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

gem 'rails', '~> 7.0.0'

gem 'sprockets-rails'
# gem 'pg', '~> 1.1'
gem 'puma', '~> 5.0'
gem 'jsbundling-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'cssbundling-rails'
gem 'redis', '~> 4.0'
# gem 'bcrypt', '~> 3.1.7'
gem 'bootsnap', require: false
gem 'sassc-rails'

gem 'slim'
# gem 'addressable'
gem 'colorize'
# gem 'omniauth-google-oauth2'

# Elasticsearch
gem 'elasticsearch-rails'
gem 'elasticsearch-persistence'
gem 'elasticsearch-dsl'

group :production do
  gem 'elastic-apm'
  # gem 'sd_notify'
end

group :development do
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'mail_interceptor'
  gem 'prettier'
end
