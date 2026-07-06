require "./app/lib/application_logger"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  GovukNotifyRails::Mailer.default(delivery_method: :govuk_notify_test, from: "forms@example.com")

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Allow storing session in cookies. This should only be allowed in local
  # development and testing. In production redis should be used
  config.unsafe_session_storage = true

  # Allow previews so we can run feature tests against components
  config.view_component.show_previews = true
  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Disable log output for tests - remove these lines to enable
  config.lograge.logger = ActiveSupport::Logger.new(nil)
  config.logger = ApplicationLogger.new(nil)

  # Set ActiveRecord Encryption keys - this is overriding the default which is to use active_kms gem in application.rb
  config.active_record.encryption.primary_key = Settings.active_record_encryption.primary_key
  config.active_record.encryption.deterministic_key = Settings.active_record_encryption.deterministic_key
  config.active_record.encryption.key_derivation_salt = Settings.active_record_encryption.key_derivation_salt

  # Make it so we can connect to the Solid Queue database. We don't set the Active Job adapter to use Solid Queue for
  # tests
  config.solid_queue.connects_to = { database: { writing: :queue } }
end
