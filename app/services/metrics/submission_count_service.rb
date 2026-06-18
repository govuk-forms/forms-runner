module Metrics
  class SubmissionCountService
    class ExportError < StandardError; end

    METRIC_NAME = "SubmissionCount".freeze
    METER_NAME = "forms-runner".freeze
    METER_VERSION = "1.0".freeze
    PERIOD = 5.minutes

    def initialize(meter_provider: OpenTelemetry.meter_provider)
      @meter_provider = meter_provider
    end

    def publish_submission_counts
      metric_count = 0
      form_names = latest_form_names_by_form_id

      submission_counts_by_form_id.each do |form_id, count|
        submission_count_counter.add(
          count,
          attributes: metric_attributes(form_id:, form_name: form_names[form_id]),
        )
        metric_count += 1
      end

      export_metrics!

      Rails.logger.info "Published #{metric_count} submission count metrics via OpenTelemetry"
    rescue ExportError => e
      Sentry.capture_exception(e)
      raise
    end

  private

    attr_reader :meter_provider

    def submission_counts_by_form_id
      submissions_in_period.group(:form_id).count
    end

    def latest_form_names_by_form_id
      submissions_in_period
        .order(Arel.sql("form_id, created_at DESC"))
        .pluck(Arel.sql("DISTINCT ON (form_id) form_id"), Arel.sql("form_document->>'name'"))
        .to_h
    end

    def submissions_in_period
      Submission.where(mode: "form", created_at: period_range)
    end

    def period_range
      PERIOD.ago..Time.current
    end

    def submission_count_counter
      @submission_count_counter ||= meter.create_counter(
        METRIC_NAME,
        unit: "1",
        description: "Number of form submissions in the export period",
      )
    end

    def meter
      meter_provider.meter(METER_NAME, version: METER_VERSION)
    end

    def metric_attributes(form_id:, form_name:)
      {
        "Environment" => Settings.forms_env.downcase,
        "FormId" => form_id.to_s,
        "FormName" => form_name.to_s,
      }
    end

    def export_metrics!
      return if meter_provider.metric_readers.empty?

      result = meter_provider.force_flush
      return if result == OpenTelemetry::SDK::Metrics::Export::SUCCESS

      raise ExportError, "Failed to export submission count metrics (status: #{result})"
    end
  end
end
