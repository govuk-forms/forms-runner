module Metrics
  METER_NAME = "forms-runner".freeze
  METER_VERSION = "1.0".freeze

  # Metrics from this meter are recorded by a scheduled job that runs once across all queue worker tasks, so there is
  # only ever one writer. The ADOT collector in forms-deploy sends metrics from this meter through a pipeline that
  # strips the per-task and per-process resource attributes, so each one is a single series.
  SINGLE_WRITER_METER_NAME = "forms-runner.single-writer".freeze

  # Forms with these names are used for automated testing of the platform
  TEST_FORM_NAME_PATTERNS = [/\Acapybara/, /smoke/, /\As3/].freeze

  class << self
    def record_submission(form_id:, form_name:, mode:)
      submission_counter.add(
        1,
        attributes: {
          "form.id" => form_id.to_s,
          "form.submission.mode" => mode_label(form_name:, mode:),
        },
      )
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

    def record_submissions_without_immediate_delivery(count, mode:)
      submissions_without_immediate_delivery_gauge.record(
        count,
        attributes: { "form.submission.mode" => mode.to_s },
      )
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

    def record_oldest_undelivered_delivery_age(age_seconds, mode:, delivery_method:)
      oldest_undelivered_delivery_age_gauge.record(
        age_seconds,
        attributes: {
          "form.submission.mode" => mode.to_s,
          "form.submission.delivery.method" => delivery_method,
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

    def submissions_without_immediate_delivery_gauge
      @submissions_without_immediate_delivery_gauge ||= single_writer_meter.create_gauge(
        "form.submission.without_immediate_delivery.count",
        unit: "{submission}",
        description: "The number of submissions that have no immediate delivery",
      )
    end

    def oldest_undelivered_delivery_age_gauge
      @oldest_undelivered_delivery_age_gauge ||= single_writer_meter.create_gauge(
        "form.submission.delivery.oldest_undelivered.age",
        unit: "s",
        description: "The time since the submission was created for the oldest immediate delivery that has not been delivered",
      )
    end

    def meter
      @meter ||= OpenTelemetry.meter_provider.meter(METER_NAME, version: METER_VERSION)
    end

    def single_writer_meter
      @single_writer_meter ||= OpenTelemetry.meter_provider.meter(SINGLE_WRITER_METER_NAME, version: METER_VERSION)
    end
  end
end
