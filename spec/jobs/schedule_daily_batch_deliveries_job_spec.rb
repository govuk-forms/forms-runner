require "rails_helper"

RSpec.describe ScheduleDailyBatchDeliveriesJob do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let(:travel_time) { Time.zone.local(2022, 12, 2) }
  let(:form_id) { 101 }
  let(:other_form_id) { 201 }
  let(:form_submissions) { create_list(:submission, 2, form_id: form_id, mode: "form") }
  let(:other_form_submissions) { create_list(:submission, 1, form_id: other_form_id, mode: "preview-draft") }
  let!(:batches) do
    [
      BatchSubmissionsSelector::Batch.new(101, "form", form_submissions),
      BatchSubmissionsSelector::Batch.new(201, "preview-draft", other_form_submissions),
    ]
  end

  around do |example|
    travel_to travel_time do
      example.run
    end
  end

  before do
    allow(BatchSubmissionsSelector).to receive(:daily_batches).and_return(batches.to_enum)
  end

  context "when Deliveries do not already exist for batches" do
    before do
      described_class.perform_now
    end

    it "calls the selector with yesterday's date" do
      expect(BatchSubmissionsSelector).to have_received(:daily_batches).with(Time.zone.yesterday)
    end

    it "creates a delivery record per batch job" do
      expect(Delivery.daily.count).to eq(2)
      expect(Delivery.first.submissions.map(&:id)).to match_array(form_submissions.map(&:id))
      expect(Delivery.second.submissions.map(&:id)).to match_array(other_form_submissions.map(&:id))
    end

    it "enqueues a SendSubmissionBatchJob per batch" do
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(2)
    end

    it "enqueues the jobs with the correct args" do
      enqueued_args = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j[:args].first }
      expect(enqueued_args.first).to include("delivery" => hash_including("_aj_globalid"))
      expect(locate_delivery(enqueued_args.first)).to eq(Delivery.first)

      expect(enqueued_args.second).to include("delivery" => hash_including("_aj_globalid"))
      expect(locate_delivery(enqueued_args.second)).to eq(Delivery.second)
    end

    describe "setting batch_begin_at" do
      context "when the date for the batch is the day the clocks go forwards" do
        let(:travel_time) { Time.zone.local(2025, 3, 31) }

        it "sets the batch_begin_at to the beginning of the day in BST" do
          expect(Delivery.first.batch_begin_at).to eq(Time.utc(2025, 3, 30, 0, 0, 0))
        end
      end

      context "when the date for the batch is after the clocks have gone forwards" do
        let(:travel_time) { Time.zone.local(2025, 4, 1) }

        it "sets the batch_begin_at to the beginning of the day in BST" do
          expect(Delivery.first.batch_begin_at).to eq(Time.utc(2025, 3, 30, 23, 0, 0))
        end
      end

      context "when the date for the batch is the day the clocks go back" do
        let(:travel_time) { Time.zone.local(2025, 10, 27) }

        it "sets the batch_begin_at to the beginning of the day in GMT" do
          expect(Delivery.first.batch_begin_at).to eq(Time.utc(2025, 10, 25, 23, 0, 0))
        end
      end

      context "when the date for the batch is the day after the clocks have gone back" do
        let(:travel_time) { Time.zone.local(2025, 10, 28) }

        it "sets the batch_begin_at to the beginning of the day in GMT" do
          expect(Delivery.first.batch_begin_at).to eq(Time.utc(2025, 10, 27, 0, 0, 0))
        end
      end
    end
  end

  context "when a Delivery already exists for a batch" do
    let!(:existing_delivery) { create(:delivery, delivery_schedule: :daily, submissions: form_submissions) }

    it "logs that the delivery will be skipped" do
      expect(Rails.logger).to receive(:warn).with(
        "Daily batch delivery already exists for batch - skipping",
        hash_including(
          form_id: form_id, mode: "form", date: Time.zone.yesterday, delivery_id: existing_delivery.id,
        ),
      )

      described_class.perform_now
    end

    it "only creates a delivery for the batch without an existing delivery" do
      expect {
        described_class.perform_now
      }.to change(Delivery, :count).by(1)

      expect(Delivery.last.submissions.map(&:id)).to match_array(other_form_submissions.map(&:id))
    end

    it "only schedules a job for the batch without an existing delivery" do
      expect {
        described_class.perform_now
      }.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(1)

      enqueued_args = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j[:args].first }
      expect(enqueued_args.first).to include("delivery" => hash_including("_aj_globalid"))
      expect(locate_delivery(enqueued_args.first)).to eq(Delivery.last)
    end
  end

  def locate_delivery(enqueued_args)
    gid_string = enqueued_args.dig("delivery", "_aj_globalid")
    GlobalID::Locator.locate(gid_string)
  end
end
