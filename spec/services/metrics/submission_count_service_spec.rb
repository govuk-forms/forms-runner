require "rails_helper"
require "opentelemetry-metrics-sdk"

describe Metrics::SubmissionCountService do
  subject(:service) { described_class.new(meter_provider:) }

  let(:meter_provider) { OpenTelemetry::SDK::Metrics::MeterProvider.new }
  let(:metric_exporter) { OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:forms_env) { "test" }
  let(:form_id) { 42 }
  let(:other_form_id) { 99 }
  let(:form_document) { build(:v2_form_document, form_id:, name: "Test Form") }
  let(:other_form_document) { build(:v2_form_document, form_id: other_form_id, name: "Other Form") }
  let(:third_form_document) { build(:v2_form_document, form_id: 123, name: "Third Form") }

  before do
    allow(Settings).to receive(:forms_env).and_return(forms_env)
    meter_provider.add_metric_reader(metric_exporter)
  end

  around do |example|
    travel_to(Time.zone.local(2026, 6, 3, 12, 0, 0)) do
      example.run
    end
  end

  describe "#publish_submission_counts" do
    context "with submissions for multiple forms in the export period" do
      before do
        create_list(:submission, 2, form_id:, form_document:)
        create(:submission, form_id: other_form_id, form_document: other_form_document)
        create(:submission, :preview, form_id:, form_document:)
        create(:submission, form_id: 123, form_document: third_form_document)
      end

      it "publishes grouped submission counts for the period via OpenTelemetry" do
        service.publish_submission_counts

        expect(exported_data_points).to contain_exactly(
          data_point(form_id:, form_name: "Test Form", count: 2),
          data_point(form_id: other_form_id, form_name: "Other Form", count: 1),
          data_point(form_id: 123, form_name: "Third Form", count: 1),
        )
      end

      context "when metric export fails" do
        before do
          allow(meter_provider).to receive(:force_flush)
            .and_return(OpenTelemetry::SDK::Metrics::Export::FAILURE)
        end

        it "captures the exception and re-raises" do
          expect(Sentry).to receive(:capture_exception).with(instance_of(Metrics::SubmissionCountService::ExportError))

          expect { service.publish_submission_counts }.to raise_error(Metrics::SubmissionCountService::ExportError)
        end
      end
    end

    context "with submissions outside the export period" do
      before do
        create(:submission, form_id:, form_document:, created_at: 10.minutes.ago)
        create(:submission, form_id:, form_document:, created_at: 4.minutes.ago)
      end

      it "only counts submissions within the last 5 minutes" do
        service.publish_submission_counts

        expect(exported_data_points).to contain_exactly(
          data_point(form_id:, form_name: "Test Form", count: 1),
        )
      end
    end

    context "when a form has been renamed within the export period" do
      before do
        create(
          :submission,
          form_id:,
          form_document: build(:v2_form_document, form_id:, name: "Older Form Name"),
          created_at: 4.minutes.ago,
        )
        create(
          :submission,
          form_id:,
          form_document: build(:v2_form_document, form_id:, name: "Latest Form Name"),
          created_at: 1.minute.ago,
        )
      end

      it "uses the latest form name from the most recent submission in the period" do
        service.publish_submission_counts

        expect(exported_data_points).to include(
          data_point(form_id:, form_name: "Latest Form Name", count: 2),
        )
      end
    end
  end

  def exported_data_points
    metric_exporter.pull
    metric_exporter.metric_snapshots.flat_map(&:data_points)
  end

  def data_point(form_id:, form_name:, count:)
    have_attributes(
      value: count,
      attributes: {
        "Environment" => forms_env,
        "FormId" => form_id.to_s,
        "FormName" => form_name,
      },
    )
  end
end
