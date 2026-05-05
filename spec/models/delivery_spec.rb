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

    describe ".bounced_on_day" do
      context "when the date is around the start of BST" do
        # London local date 2025-03-29 => UTC 2025-03-29 00:00:00..2025-03-29 23:59:59
        let!(:start_of_gmt_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 29, 0, 0, 0)) }
        let!(:end_of_gmt_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 29, 23, 59, 59)) }

        # London local date 2025-03-30 => UTC 2025-03-30 00:00:00..2025-03-30 22:59:59
        let!(:start_of_change_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 30, 0, 0, 0)) }
        let!(:end_of_change_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 30, 22, 59, 59)) }

        # London local date 2025-03-31 => UTC 2025-03-30 23:00:00..2025-03-31 22:59:59
        let!(:start_of_bst_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 30, 23, 0, 0)) }
        let!(:end_of_bst_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 3, 31, 22, 59, 59)) }
        let(:date) { Date.new(2022, 6, 1) }

        it "returns deliveries that bounced on the day before the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 3, 29))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_gmt_day_delivery, end_of_gmt_day_delivery)
        end

        it "returns deliveries on the day of the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 3, 30))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_change_day_delivery, end_of_change_day_delivery)
        end

        it "returns deliveries on the day after the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 3, 31))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_bst_day_delivery, end_of_bst_day_delivery)
        end
      end

      context "when the date is around the end of BST" do
        # London local date 2025-10-25 => UTC 2025-10-24 23:00:00..2025-10-25 22:59:59
        let!(:start_of_bst_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 24, 23, 0, 0)) }
        let!(:end_of_bst_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 25, 22, 59, 59)) }

        # London local date 2025-10-26 => UTC 2025-10-25 23:00:00..2025-10-26 23:59:59
        let!(:start_of_change_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 25, 23, 0, 0)) }
        let!(:end_of_change_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 26, 23, 59, 59)) }

        # London local date 2025-10-27 => UTC 2025-10-27 00:00:00..2025-10-27 23:59:59
        let!(:start_of_gmt_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 27, 0, 0, 0)) }
        let!(:end_of_gmt_day_delivery) { create(:delivery, :bounced, failed_at: Time.utc(2025, 10, 27, 23, 59, 59)) }

        it "returns deliveries on the day before the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 10, 25))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_bst_day_delivery, end_of_bst_day_delivery)
        end

        it "returns deliveries on the day of the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 10, 26))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_change_day_delivery, end_of_change_day_delivery)
        end

        it "returns deliveries on the day after the clocks change" do
          deliveries = described_class.bounced_on_day(Date.new(2025, 10, 27))
          expect(deliveries.size).to eq(2)
          expect(deliveries).to contain_exactly(start_of_gmt_day_delivery, end_of_gmt_day_delivery)
        end
      end

      it "does not include deliveries that were delivered after they bounced" do
        date = Date.new(2022, 6, 1)
        create(:delivery, :delivered_after_bounce, created_at: date)

        deliveries = described_class.bounced_on_day(date)
        expect(deliveries).to be_empty
      end

      it "includes deliveries that bounced after they were delivered" do
        date = Date.new(2022, 6, 1)
        delivery = create(:delivery, :bounced_after_delivery, created_at: date)

        deliveries = described_class.bounced_on_day(date)
        expect(deliveries).to include(delivery)
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
