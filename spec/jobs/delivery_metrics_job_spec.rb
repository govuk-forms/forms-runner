require "rails_helper"

RSpec.describe DeliveryMetricsJob, type: :job do
  let(:other_modes) { %w[preview-draft preview-archived] }

  before do
    freeze_time

    allow(Metrics).to receive(:record_submissions_without_immediate_delivery)
    allow(Metrics).to receive(:record_oldest_undelivered_delivery_age)
  end

  describe "submissions without immediate delivery metric" do
    before do
      create(:submission)
      create(:submission)
      create(:delivery, :immediate)
      create(:delivery, :daily_scheduled_delivery, submissions_count: 1)
      create(:submission, mode: "preview-live")
    end

    it "records the number of live submissions without an immediate delivery" do
      described_class.perform_now

      # The two submissions with no deliveries and the one with only a daily batch delivery
      expect(Metrics).to have_received(:record_submissions_without_immediate_delivery).with(3, mode: "form")
    end

    it "records preview submissions with their mode" do
      described_class.perform_now

      expect(Metrics).to have_received(:record_submissions_without_immediate_delivery).with(1, mode: "preview-live")
    end

    it "records zero for modes with no submissions without an immediate delivery" do
      described_class.perform_now

      other_modes.each do |mode|
        expect(Metrics).to have_received(:record_submissions_without_immediate_delivery).with(0, mode:)
      end
    end
  end

  describe "oldest undelivered delivery age metric" do
    def create_immediate_delivery(*traits, created_at:, delivery_method: "email", mode: "form")
      submission = create(:submission, created_at:, mode:)
      create(:delivery, *traits, delivery_method:, submissions: [submission])
    end

    before do
      create_immediate_delivery(:pending, created_at: 2.days.ago)
      create_immediate_delivery(:bounced, created_at: 3.days.ago)
      create_immediate_delivery(:delivered, created_at: 10.days.ago)
      create_immediate_delivery(:pending, created_at: 1.hour.ago, delivery_method: "s3")
      create_immediate_delivery(:pending, created_at: 5.days.ago, mode: "preview-live")
      create(:delivery, :daily_scheduled_delivery, :pending, submissions_count: 1, created_at: 20.days.ago)
    end

    it "records the age of the oldest undelivered delivery for each delivery method" do
      described_class.perform_now

      expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
        .with(3.days.to_i, mode: "form", delivery_method: "email")
      expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
        .with(1.hour.to_i, mode: "form", delivery_method: "s3")
    end

    it "records preview deliveries with their mode" do
      described_class.perform_now

      expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
        .with(5.days.to_i, mode: "preview-live", delivery_method: "email")
    end

    it "records zero for modes and delivery methods with no undelivered deliveries" do
      described_class.perform_now

      expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
        .with(0, mode: "preview-live", delivery_method: "s3")
      other_modes.each do |mode|
        expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
          .with(0, mode:, delivery_method: "email")
        expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age)
          .with(0, mode:, delivery_method: "s3")
      end
    end
  end

  describe "resilience to metric failures" do
    let(:error) { StandardError.new("database unavailable") }

    before do
      allow(Rails.logger).to receive(:warn)
      allow(Sentry).to receive(:capture_exception)
      allow(Submission).to receive(:without_immediate_delivery).and_raise(error)
    end

    it "records the other metric and reports the error" do
      expect { described_class.perform_now }.not_to raise_error

      expect(Metrics).to have_received(:record_oldest_undelivered_delivery_age).at_least(:once)
      expect(Sentry).to have_received(:capture_exception).with(error)
    end
  end
end
