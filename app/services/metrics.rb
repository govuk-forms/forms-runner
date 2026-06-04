module Metrics
  METER_NAME = "forms-runner".freeze
  METER_VERSION = "1.0".freeze

  class << self
    def record_submission(form_id:, mode:)
      submission_counter.add(
        1,
        attributes: {
          "Environment" => Settings.forms_env.downcase,
          "FormId" => form_id.to_s,
          "Mode" => mode.to_s,
        },
      )
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

  private

    def submission_counter
      @submission_counter ||= meter.create_counter(
        "SubmissionCount",
        unit: "1",
        description: "Number of form submissions",
      )
    end

    def meter
      @meter ||= OpenTelemetry.meter_provider.meter(METER_NAME, version: METER_VERSION)
    end
  end
end
