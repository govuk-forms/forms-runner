require "rails_helper"

RSpec.describe "jobs.rake", type: :task do
  include ActiveJob::TestHelper

  describe "jobs:retry_failed" do
    subject(:task) do
      Rake::Task["jobs:retry_failed"]
    end

    # If a job is retried, there are multiple jobs with the same active_job_id but the failed execution is only
    # attached to the final one. Create another job with the same active_job_id first to simulate this.
    let(:first_job) { create :solid_queue_job }
    let(:job) { create :solid_queue_job, active_job_id: first_job.active_job_id }

    context "with valid arguments" do
      let(:valid_args) { [job.active_job_id] }

      context "when the job is failed" do
        before do
          create :solid_queue_failed_execution, job: job
        end

        it "calls retry for the failed execution" do
          # rubocop:disable RSpec/AnyInstance
          expect_any_instance_of(SolidQueue::FailedExecution).to receive(:retry).once
          # rubocop:enable RSpec/AnyInstance

          task.invoke(*valid_args)
        end

        it "logs that the job was scheduled for retry" do
          expect(Rails.logger).to receive(:info).with("Scheduled retry for job with ID: #{job.active_job_id}, class: #{job.class_name}")

          task.invoke(*valid_args)
        end
      end

      context "when the job is not failed" do
        it "aborts with message that the job id not failed" do
          expect {
            task.invoke(*valid_args)
          }.to raise_error(SystemExit)
                 .and output("Job with job_id #{job.active_job_id} is not failed\n").to_stderr
        end
      end

      context "when the job does not exist" do
        it "aborts with message that the job was not found" do
          expect {
            task.invoke("foo")
          }.to raise_error(SystemExit)
                 .and output("Job with job_id foo not found\n").to_stderr
        end
      end
    end

    context "with invalid arguments" do
      it "aborts with a usage message" do
        expect {
          task.invoke
        }.to raise_error(SystemExit)
               .and output("usage: rake jobs:retry_failed[<job_id>]\n").to_stderr
      end
    end
  end

  describe "jobs:delete_failed" do
    subject(:task) do
      Rake::Task["jobs:delete_failed"]
    end

    # If a job is retried, there are multiple jobs with the same active_job_id but the failed execution is only
    # attached to the final one. Create another job with the same active_job_id first to simulate this.
    let(:first_job) { create :solid_queue_job }
    let(:job) { create :solid_queue_job, active_job_id: first_job.active_job_id }

    context "with valid arguments" do
      context "when the job is failed" do
        before do
          create :solid_queue_failed_execution, job: job
        end

        it "deletes the failed execution" do
          expect {
            task.invoke(job.active_job_id)
          }.to change(SolidQueue::FailedExecution, :count).by(-1)
        end

        it "logs that the failed execution was deleted" do
          expect(Rails.logger).to receive(:info).with("Deleted failed execution for job with ID: #{job.active_job_id}, class: #{job.class_name}.")

          task.invoke(job.active_job_id)
        end
      end

      context "when given multiple job ids" do
        let(:other_job) { create :solid_queue_job }

        before do
          create :solid_queue_failed_execution, job: job
          create :solid_queue_failed_execution, job: other_job
        end

        it "deletes the failed executions" do
          expect {
            task.invoke(job.active_job_id, other_job.active_job_id)
          }.to change(SolidQueue::FailedExecution, :count).by(-2)
        end
      end

      context "when the job is not failed" do
        it "aborts with message" do
          expect {
            task.invoke(job.active_job_id)
          }.to raise_error(SystemExit)
                 .and output("Job with job_id #{job.active_job_id} is not failed\n").to_stderr
        end
      end

      context "when the job does not exist" do
        it "aborts with message that the job was not found" do
          expect {
            task.invoke("foo")
          }.to raise_error(SystemExit)
                 .and output("Job with job_id foo not found\n").to_stderr
        end
      end
    end

    context "with invalid arguments" do
      it "aborts with a usage message" do
        expect {
          task.invoke
        }.to raise_error(SystemExit)
               .and output("usage: rake jobs:delete_failed[<job_id>, ...]\n").to_stderr
      end
    end
  end

  describe "jobs:retry_all_failed" do
    subject(:task) do
      Rake::Task["jobs:retry_all_failed"]
    end

    let(:failed_job) { create :solid_queue_job, class_name: SendSubmissionJob.name }
    let(:other_failed_job) { create :solid_queue_job, class_name: SendSubmissionJob.name }
    let(:failed_not_submission_job) { create :solid_queue_job, class_name: "SomethingElse" }
    let(:not_failed_job) { create :solid_queue_job }

    before do
      create :solid_queue_failed_execution, job: failed_job
      create :solid_queue_failed_execution, job: other_failed_job
      create :solid_queue_failed_execution, job: failed_not_submission_job
    end

    context "with valid arguments" do
      let(:valid_args) { [SendSubmissionJob.name] }

      it "retries the failed jobs with the given class name" do
        expect(SolidQueue::FailedExecution).to receive(:retry_all).with([failed_job, other_failed_job])
        task.invoke(*valid_args)
      end

      it "logs that 2 jobs were retried" do
        expect(Rails.logger).to receive(:info).with("Found 2 failed SendSubmissionJob jobs to retry")
        expect(Rails.logger).to receive(:info).with("Retried 2 failed SendSubmissionJob jobs")
        task.invoke(*valid_args)
      end
    end

    context "with invalid arguments" do
      it "aborts with a usage message" do
        expect {
          task.invoke
        }.to raise_error(SystemExit)
               .and output("usage: rake jobs:retry_all_failed[<job_class_name>]\n").to_stderr
      end
    end
  end

  describe "jobs:list_failed" do
    subject(:task) do
      Rake::Task["jobs:list_failed"]
    end

    let(:queue_name) { "queue-1" }
    let(:job) { create :solid_queue_job, queue_name: }
    let!(:failed_execution) { create :solid_queue_failed_execution, job: job, error: "Error message 1" }

    before do
      other_queue_job = create :solid_queue_job, queue_name: "queue-2"
      create :solid_queue_failed_execution, job: other_queue_job
    end

    it "logs the details of the failed jobs on the specified queue" do
      expect(Rails.logger).to receive(:info).with("Found 1 failed jobs on #{queue_name} queue")
      expect(Rails.logger).to receive(:info).with(
        "Failed execution - Job ID: #{job.active_job_id}, Job Class: #{job.class_name}, Failed At: #{failed_execution.created_at}, Error Message: #{failed_execution.error}",
      )

      task.invoke(queue_name)
    end

    context "with invalid arguments" do
      it "aborts with a usage message" do
        expect {
          task.invoke
        }.to raise_error(SystemExit)
               .and output("usage: rake jobs:list_failed[<queue_name>]\n").to_stderr
      end
    end
  end
end
