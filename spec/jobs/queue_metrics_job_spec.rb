require "rails_helper"

RSpec.describe QueueMetricsJob, type: :job do
  include ActiveJob::TestHelper

  let(:queue_name) { "queue-1" }
  let(:other_queue_name) { "queue-2" }
  let(:queue_length) { 4 }
  let(:other_queue_length) { 2 }
  let(:queues) do
    [
      instance_double(SolidQueue::Queue, name: queue_name, size: queue_length),
      instance_double(SolidQueue::Queue, name: other_queue_name, size: other_queue_length),
    ]
  end

  before do
    allow(CloudWatchService).to receive(:record_queue_length_metric)
    allow(CloudWatchService).to receive(:record_failed_job_executions)
    allow(SolidQueue::Queue).to receive(:all).and_return(queues)

    described_class.perform_later
  end

  describe "queue length metric" do
    it "sends queue length to CloudWatch for each queue" do
      perform_enqueued_jobs
      expect(CloudWatchService).to have_received(:record_queue_length_metric).with(queue_name, queue_length)
      expect(CloudWatchService).to have_received(:record_queue_length_metric).with(other_queue_name, other_queue_length)
    end
  end

  describe "failed executions metric" do
    before do
      create :solid_queue_failed_execution, job: create(:solid_queue_job, queue_name:)
      create :solid_queue_failed_execution, job: create(:solid_queue_job, queue_name:)
      create(:solid_queue_job, queue_name:)
      create(:solid_queue_job, queue_name: other_queue_name)
    end

    it "sends the count of failed executions for each queue to CloudWatch" do
      perform_enqueued_jobs
      expect(CloudWatchService).to have_received(:record_failed_job_executions).with(queue_name, 2)
    end

    it "sends a count of zero for queues with no failed executions" do
      perform_enqueued_jobs
      expect(CloudWatchService).to have_received(:record_failed_job_executions).with(other_queue_name, 0)
    end
  end

  describe "resilience to metric failures" do
    before do
      allow(Rails.logger).to receive(:warn)
      allow(Sentry).to receive(:capture_exception)
      allow(CloudWatchService).to receive(:record_queue_length_metric)
        .with(queue_name, queue_length).and_raise(StandardError, "CloudWatch unavailable")
      allow(CloudWatchService).to receive(:record_queue_length_metric)
        .with(other_queue_name, other_queue_length)
    end

    it "continues processing metrics for other queues" do
      expect { perform_enqueued_jobs }.not_to raise_error

      expect(CloudWatchService).to have_received(:record_queue_length_metric).with(other_queue_name, other_queue_length)
      expect(CloudWatchService).to have_received(:record_failed_job_executions).with(queue_name, 0)
      expect(CloudWatchService).to have_received(:record_failed_job_executions).with(other_queue_name, 0)
      expect(Sentry).to have_received(:capture_exception)
    end
  end
end
