require "rails_helper"
require "aws-sdk-cloudwatch"

describe Metrics::SubmissionCountService do
  subject(:service) { described_class.new }

  let(:forms_env) { "test" }
  let(:cloud_watch_client) { Aws::CloudWatch::Client.new(stub_responses: true) }
  let(:form_id) { 42 }
  let(:other_form_id) { 99 }

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
    before do
      create_list(:submission, 2, form_id:)
      create(:submission, form_id: other_form_id)
      create(:submission, :preview, form_id:)
      create(:submission, form_id: 123)
    end

    it "publishes grouped submission counts to CloudWatch" do
      expect(cloud_watch_client).to receive(:put_metric_data).with(
        namespace: "Forms",
        metric_data: contain_exactly(
          metric_datum(form_id:, count: 2),
          metric_datum(form_id: other_form_id, count: 1),
          metric_datum(form_id: 123, count: 1),
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

  def metric_datum(form_id:, count:)
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
      ],
      value: count,
      unit: "Count",
      timestamp: Time.zone.local(2026, 6, 3, 12, 0, 0),
    }
  end
end
