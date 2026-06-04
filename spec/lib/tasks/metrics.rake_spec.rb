require "rails_helper"

RSpec.describe "metrics.rake", type: :task do
  describe "metrics:export_submission_counts" do
    subject(:task) do
      Rake::Task["metrics:export_submission_counts"]
    end

    it "publishes submission counts via Metrics::SubmissionCountService" do
      service = instance_double(Metrics::SubmissionCountService)
      allow(Metrics::SubmissionCountService).to receive(:new).and_return(service)
      expect(service).to receive(:publish_submission_counts)

      task.invoke
    end
  end
end
