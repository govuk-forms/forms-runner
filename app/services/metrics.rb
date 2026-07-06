module Metrics
  METER_NAME = "forms-runner".freeze
  METER_VERSION = "1.0".freeze

  # Forms with these names are used for automated testing of the platform
  TEST_FORM_NAME_PATTERNS = [/\Acapybara/, /smoke/, /\As3/].freeze

  class << self
    def record_submission(form_id:, form_name:, mode:)
      submission_counter.add(
        1,
        attributes: {
          "deployment.environment.name" => Settings.forms_env.downcase,
          "form.id" => form_id.to_s,
          "form.submission.mode" => mode_label(form_name:, mode:),
        },
      )
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

  private

    def mode_label(form_name:, mode:)
      return "test" if test_form?(form_name)

      mode.to_s
    end

    def test_form?(form_name)
      TEST_FORM_NAME_PATTERNS.any? { |pattern| pattern.match?(form_name.to_s) }
    end

    def submission_counter
      @submission_counter ||= meter.create_counter(
        "form.submission.created",
        unit: "{submission}",
        description: "The number of form submissions queued for delivery",
      )
    end

    def meter
      @meter ||= OpenTelemetry.meter_provider.meter(METER_NAME, version: METER_VERSION)
    end
  end
end
