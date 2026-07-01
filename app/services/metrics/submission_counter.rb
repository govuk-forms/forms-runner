module Metrics
  class SubmissionCounter
    METRIC_NAME = "SubmissionCount".freeze
    METER_NAME = "forms-runner".freeze
    METER_VERSION = "1.0".freeze

    class << self
      def record(form_id:, form_name:, mode:, meter_provider: OpenTelemetry.meter_provider)
        return if mode.preview?

        counter(meter_provider).add(
          1,
          attributes: metric_attributes(form_id:, form_name:),
        )
      end

    private

      def counter(meter_provider)
        counters[meter_provider] ||= meter(meter_provider).create_counter(
          METRIC_NAME,
          unit: "1",
          description: "Number of form submissions",
        )
      end

      def counters
        @counters ||= {}
      end

      def meter(meter_provider)
        meter_provider.meter(METER_NAME, version: METER_VERSION)
      end

      def metric_attributes(form_id:, form_name:)
        {
          "Environment" => Settings.forms_env.downcase,
          "FormId" => form_id.to_s,
          "FormName" => form_name.to_s,
        }
      end
    end
  end
end
