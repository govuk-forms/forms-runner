source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: ".ruby-version"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 7.2.0"

# Use Sentry (https://sentry.io/for/ruby/?platform=sentry.ruby.rails#)
gem "sentry-rails", "~> 6"
gem "sentry-ruby", "~> 6"

gem "config"

# Use GOV.UK Nofity api to send emails
gem "govuk_notify_rails"

# Use Redis for session storage
gem "redis"
gem "redis-session-store"

# Use SolidQueue for ActiveJob
gem "solid_queue", "~> 1.4"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo"
gem "tzinfo-data"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# For requests to the forms-admin API
gem "activeresource"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"

# For GOV.UK branding
gem "govuk-components", "~> 6"
gem "govuk_design_system_formbuilder", "~> 6"

# Our own custom markdown renderer
gem "govuk-forms-markdown", github: "alphagov/govuk-forms-markdown", tag: "0.8.0"

# For compiling our frontend assets
gem "vite_rails"

# validate postcodes
gem "uk_postcode"

# For structured logging
gem "lograge"

# For distributed tracing and telemetry
gem "opentelemetry-exporter-otlp", "~> 0.32.0"
gem "opentelemetry-instrumentation-all", "~> 0.91.0"
gem "opentelemetry-propagator-xray", "~> 0.26.1"
gem "opentelemetry-sdk", "~> 1.10"

# For AWS interactions
gem "aws-sdk-cloudwatch"
gem "aws-sdk-codepipeline", "~> 1.113"
gem "aws-sdk-kms"
gem "aws-sdk-s3"
gem "aws-sdk-sesv2"
gem "aws-sdk-sqs"
gem "aws-sdk-sts"

# For managing KMS keys in production
gem "active_kms"

# For sending submissions as CSV
gem "csv"

# The autocomplete component is not currently published as a gem, if changing
# the hash, also change in package.json
gem "dfe-autocomplete", require: "dfe/autocomplete", github: "DFE-Digital/dfe-autocomplete", ref: "1d4cc65039e11cc3ba9e7217a719b8128d0e4d53"

gem "rails-i18n", "~> 8.1"

# IDNA conversion needed for validating email addresses
gem "uri-idna"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  gem "factory_bot_rails"
  gem "faker"

  # Support for locale tasks tests
  gem "i18n-tasks", "~> 1.1.2"

  gem "rspec-rails"
  gem "rubocop-govuk", require: false

  # For security auditing gem vulnerabilities. RUN IN CI
  gem "bundler-audit", "~> 0.9.3"

  # For detecting security vulnerabilities in Ruby on Rails applications via static analysis.
  gem "brakeman", "~> 8.0"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "rails-controller-testing"
  gem "selenium-webdriver"
  gem "simplecov"

  # axe-core for running automated accessibility checks
  gem "axe-core-rspec"

  # For validating against the JSON schema for form submissions
  gem "json_schemer"
end
