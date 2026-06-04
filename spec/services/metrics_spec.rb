require "rails_helper"
require "opentelemetry-metrics-sdk"

describe Metrics do
  let(:meter_provider) { OpenTelemetry::SDK::Metrics::MeterProvider.new }
  let(:metric_exporter) { OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:forms_env) { "test" }
  let(:form_id) { 42 }
  let(:mode) { Mode.new("form") }

  before do
    allow(Settings).to receive(:forms_env).and_return(forms_env)
    allow(OpenTelemetry).to receive(:meter_provider).and_return(meter_provider)
    meter_provider.add_metric_reader(metric_exporter)
    reset_memoized_instruments
  end

  after do
    reset_memoized_instruments
  end

  describe ".record_submission" do
    it "records a submission count metric" do
      described_class.record_submission(form_id:, mode:)

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 1,
          attributes: {
            "Environment" => forms_env,
            "FormId" => form_id.to_s,
            "Mode" => "form",
          },
        ),
      )
    end

    context "when mode is preview" do
      let(:mode) { Mode.new("preview-live") }

      it "records a metric with the preview mode label" do
        described_class.record_submission(form_id:, mode:)

        expect(exported_data_points).to contain_exactly(
          have_attributes(
            value: 1,
            attributes: include("Mode" => "preview-live"),
          ),
        )
      end
    end

    it "accumulates counts for the same form" do
      2.times { described_class.record_submission(form_id:, mode:) }

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 2,
          attributes: include("FormId" => form_id.to_s),
        ),
      )
    end

    it "records separate counts per form" do
      described_class.record_submission(form_id:, mode:)
      described_class.record_submission(form_id: 99, mode:)

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 1,
          attributes: include("FormId" => form_id.to_s),
        ),
        have_attributes(
          value: 1,
          attributes: include("FormId" => "99"),
        ),
      )
    end

    it "records separate counts per mode" do
      described_class.record_submission(form_id:, mode:)
      described_class.record_submission(form_id:, mode: Mode.new("preview-draft"))

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 1,
          attributes: include("Mode" => "form"),
        ),
        have_attributes(
          value: 1,
          attributes: include("Mode" => "preview-draft"),
        ),
      )
    end

    context "when recording the metric raises an error" do
      let(:error) { StandardError.new("metrics unavailable") }

      before do
        allow(described_class).to receive(:submission_counter).and_raise(error)
      end

      it "captures the exception in Sentry and does not raise" do
        expect(Sentry).to receive(:capture_exception).with(error)

        expect { described_class.record_submission(form_id:, mode:) }.not_to raise_error
      end
    end
  end

  def exported_data_points
    metric_exporter.pull
    metric_exporter.metric_snapshots.flat_map(&:data_points)
  end

  def reset_memoized_instruments
    described_class.instance_variable_set(:@meter, nil)
    described_class.instance_variable_set(:@submission_counter, nil)
  end
end
