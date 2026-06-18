require "rails_helper"
require "opentelemetry-metrics-sdk"

describe Metrics::SubmissionCounter do
  let(:meter_provider) { OpenTelemetry::SDK::Metrics::MeterProvider.new }
  let(:metric_exporter) { OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:forms_env) { "test" }
  let(:form_id) { 42 }
  let(:form_name) { "Test Form" }
  let(:mode) { Mode.new("form") }

  before do
    allow(Settings).to receive(:forms_env).and_return(forms_env)
    meter_provider.add_metric_reader(metric_exporter)
    described_class.send(:counters).clear
  end

  describe ".record" do
    it "records a submission count metric" do
      described_class.record(form_id:, form_name:, mode:, meter_provider:)

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 1,
          attributes: {
            "Environment" => forms_env,
            "FormId" => form_id.to_s,
            "FormName" => form_name,
          },
        ),
      )
    end

    context "when mode is preview" do
      let(:mode) { Mode.new("preview-live") }

      it "does not record a metric" do
        described_class.record(form_id:, form_name:, mode:, meter_provider:)

        expect(exported_data_points).to be_empty
      end
    end

    it "accumulates counts for the same form" do
      2.times { described_class.record(form_id:, form_name:, mode:, meter_provider:) }

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 2,
          attributes: {
            "Environment" => forms_env,
            "FormId" => form_id.to_s,
            "FormName" => form_name,
          },
        ),
      )
    end

    it "records separate counts per form" do
      described_class.record(form_id:, form_name:, mode:, meter_provider:)
      described_class.record(form_id: 99, form_name: "Other Form", mode:, meter_provider:)

      expect(exported_data_points).to contain_exactly(
        have_attributes(
          value: 1,
          attributes: {
            "Environment" => forms_env,
            "FormId" => form_id.to_s,
            "FormName" => form_name,
          },
        ),
        have_attributes(
          value: 1,
          attributes: {
            "Environment" => forms_env,
            "FormId" => "99",
            "FormName" => "Other Form",
          },
        ),
      )
    end
  end

  def exported_data_points
    metric_exporter.pull
    metric_exporter.metric_snapshots.flat_map(&:data_points)
  end
end
