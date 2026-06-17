require "rails_helper"
require "aws-sdk-cloudwatch"

describe Metrics::SubmissionCountService do
  subject(:service) { described_class.new }

  let(:forms_env) { "test" }
  let(:cloud_watch_client) { Aws::CloudWatch::Client.new(stub_responses: true) }
  let(:form_id) { 42 }
  let(:other_form_id) { 99 }
  let(:form_document) { build(:v2_form_document, form_id:, name: "Test Form") }
  let(:other_form_document) { build(:v2_form_document, form_id: other_form_id, name: "Other Form") }
  let(:third_form_document) { build(:v2_form_document, form_id: 123, name: "Third Form") }

  before do
    allow(Settings).to receive(:forms_env).and_return(forms_env)
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloud_watch_client)
  end

  around do |example|
    travel_to(Time.zone.local(2026, 6, 3, 12, 0, 0)) do
      example.run
    end
  end

  describe "#publish_submission_counts" do
    context "with submissions for multiple forms" do
      before do
        create_list(:submission, 2, form_id:, form_document:)
        create(:submission, form_id: other_form_id, form_document: other_form_document)
        create(:submission, :preview, form_id:, form_document:)
        create(:submission, form_id: 123, form_document: third_form_document)
      end

      it "publishes grouped submission counts to CloudWatch" do
        expect(cloud_watch_client).to receive(:put_metric_data).with(
          namespace: "Forms",
          metric_data: contain_exactly(
            metric_datum(form_id:, form_name: "Test Form", count: 2),
            metric_datum(form_id: other_form_id, form_name: "Other Form", count: 1),
            metric_datum(form_id: 123, form_name: "Third Form", count: 1),
          ),
        )

        service.publish_submission_counts
      end

      context "when CloudWatch returns an error" do
        before do
          allow(cloud_watch_client).to receive(:put_metric_data)
            .and_raise(Aws::CloudWatch::Errors::ServiceError.new(nil, "CloudWatch error", nil))
        end

        it "captures the exception and re-raises" do
          expect(Sentry).to receive(:capture_exception).with(instance_of(Aws::CloudWatch::Errors::ServiceError))

          expect { service.publish_submission_counts }.to raise_error(Aws::CloudWatch::Errors::ServiceError)
        end
      end
    end

    context "when a form has been renamed" do
      before do
        create(
          :submission,
          form_id:,
          form_document: build(:v2_form_document, form_id:, name: "Older Form Name"),
          created_at: 2.days.ago,
        )
        create(
          :submission,
          form_id:,
          form_document: build(:v2_form_document, form_id:, name: "Latest Form Name"),
          created_at: 1.minute.ago,
        )
      end

      it "uses the latest form name from the most recent submission" do
        expect(cloud_watch_client).to receive(:put_metric_data).with(
          namespace: "Forms",
          metric_data: include(
            metric_datum(form_id:, form_name: "Latest Form Name", count: 2),
          ),
        )

        service.publish_submission_counts
      end
    end
  end

  def metric_datum(form_id:, form_name:, count:)
    {
      metric_name: "SubmissionCount",
      dimensions: [
        {
          name: "Environment",
          value: forms_env,
        },
        {
          name: "FormId",
          value: form_id.to_s,
        },
        {
          name: "FormName",
          value: form_name,
        },
      ],
      value: count,
      unit: "Count",
      timestamp: Time.zone.local(2026, 6, 3, 12, 0, 0),
    }
  end
end
