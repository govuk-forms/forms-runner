require "opentelemetry/sdk"
require "opentelemetry/instrumentation/all"
require "opentelemetry-metrics-sdk"
require "opentelemetry-exporter-otlp-metrics"

return unless ENV["ENABLE_OTEL"] == "true"

OpenTelemetry::SDK.configure do |c|
  instrumentation_config = {
    "OpenTelemetry::Instrumentation::Rack" => { untraced_endpoints: ["/up"] },
    # Name job spans by class name (e.g. "SendSubmissionJob process") rather than queue
    # name (e.g. "submissions process") so traces are identifiable in X-Ray.
    "OpenTelemetry::Instrumentation::ActiveJob" => { span_naming: :job_class },
  }
  c.use_all(instrumentation_config)

  if ENV["OTEL_PROPAGATORS"] == "xray"
    # The ID Generator can only be configured through code. Gate it behind the propagator env var to keep things agnostic.
    c.id_generator = OpenTelemetry::Propagator::XRay::IDGenerator
  end

  unless ENV.fetch("OTEL_METRICS_EXPORTER", "otlp") == "none"
    c.add_metric_reader(
      OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
        exporter: OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new,
      ),
    )
  end

  # Disable logging for Rake tasks to avoid cluttering output
  c.logger = Logger.new(File::NULL) if Rails.const_defined?(:Rake) && Rake.application.top_level_tasks.any?
end
