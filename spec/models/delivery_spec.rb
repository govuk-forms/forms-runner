require "rails_helper"

RSpec.describe Delivery, type: :model do
  describe "#status" do
    it "returns pending when delivered_at and failed_at are nil" do
      delivery = create(:delivery, :pending)

      expect(delivery.status).to eq(:pending)
    end

    it "returns delivered when delivered_at is present and failed_at is nil" do
      delivery = create(:delivery, :delivered)

      expect(delivery.status).to eq(:delivered)
    end

    it "returns failed when failed_at is present and delivered_at is nil" do
      delivery = create(:delivery, :failed)

      expect(delivery.status).to eq(:failed)
    end

    it "returns delivered when delivered_at is after failed_at" do
      delivery = create(:delivery, :delivered_after_failure)

      expect(delivery.status).to eq(:delivered)
    end

    it "returns failed when delivered_at is before failed_at" do
      delivery = create(:delivery, :failed_after_delivery)

      expect(delivery.status).to eq(:failed)
    end
  end

  describe "status predicates" do
    it "returns true for pending? when status is pending" do
      pending_delivery = create(:delivery, :pending)

      expect(pending_delivery).to be_pending
      expect(pending_delivery).not_to be_delivered
      expect(pending_delivery).not_to be_failed
    end

    it "returns true for delivered? when status is delivered" do
      delivered_delivery = create(:delivery, :delivered)

      expect(delivered_delivery).to be_delivered
      expect(delivered_delivery).not_to be_pending
      expect(delivered_delivery).not_to be_failed
    end

    it "returns true for failed? when status is failed" do
      failed_delivery = create(:delivery, :failed)

      expect(failed_delivery).to be_failed
      expect(failed_delivery).not_to be_pending
      expect(failed_delivery).not_to be_delivered
    end
  end

  describe "scopes" do
    let!(:pending_delivery) { create(:delivery, :pending) }
    let!(:delivered_delivery) { create(:delivery, :delivered) }
    let!(:failed_delivery) { create(:delivery, :failed) }
    let!(:delivered_after_failure) { create(:delivery, :delivered_after_failure) }
    let!(:failed_after_delivery) { create(:delivery, :failed_after_delivery) }

    describe ".pending" do
      it "returns only deliveries with no delivered_at or failed_at" do
        expect(described_class.pending).to contain_exactly(pending_delivery)
      end
    end

    describe ".delivered" do
      it "returns deliveries that are successfully delivered" do
        expect(described_class.delivered).to contain_exactly(delivered_delivery, delivered_after_failure)
      end
    end

    describe ".failed" do
      it "returns deliveries that have failed" do
        expect(described_class.failed).to contain_exactly(failed_delivery, failed_after_delivery)
      end
    end
  end

  describe "#new_attempt!" do
    let(:previous_attempt_at) { 2.hours.ago }
    let(:delivery) do
      create(
        :delivery,
        last_attempt_at: previous_attempt_at,
        delivered_at: 3.hours.ago,
        failed_at: 2.hours.ago,
        failure_reason: "error",
        failure_details: { "foo" => "bar" },
      )
    end

    it "updates last_attempt_at and clears delivered_at and failure attributes" do
      delivery.new_attempt!
      delivery.reload

      expect(delivery.last_attempt_at).to be > previous_attempt_at
      expect(delivery.delivered_at).to be_nil
      expect(delivery.failed_at).to be_nil
      expect(delivery.failure_reason).to be_nil
      expect(delivery.failure_details).to be_nil
    end
  end
end
