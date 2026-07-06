require "rails_helper"

RSpec.describe BatchSubmissionsSelector do
  let(:form_id) { 101 }

  describe ".daily_batches" do
    subject(:daily_batches) { described_class.daily_batches(date) }

    let(:date) { Time.zone.local(2022, 12, 1) }
    let(:form_document_with_batch_enabled) { build(:v2_form_document, send_daily_submission_batch: true) }
    let(:form_document_with_batch_disabled) { build(:v2_form_document, send_daily_submission_batch: false) }

    it "returns an enumerator" do
      expect(daily_batches).to be_an(Enumerator)
    end

    context "when send_daily_submission_batch is enabled for the form document" do
      context "when the date is during BST" do
        let(:date) { Time.zone.local(2022, 6, 1) }

        let!(:form_submission) do
          create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2022, 5, 31, 23, 0, 0), form_document: form_document_with_batch_enabled)
        end
        let!(:preview_draft_submission) do
          create(:submission, form_id: form_id, mode: "preview-draft", reference: "INCLUDED2", created_at: Time.utc(2022, 6, 1, 22, 59, 59), form_document: form_document_with_batch_enabled)
        end

        before do
          # create form/mode combinations that only have submissions outside the BST day
          create(:submission, form_id: form_id, mode: "preview-archived", reference: "OMITTED1", created_at: Time.utc(2022, 5, 31, 22, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: 102, mode: "form", reference: "OMITTED2", created_at: Time.utc(2022, 6, 1, 23, 0, 0), form_document: form_document_with_batch_enabled)

          # create submissions for the form/mode included in a batch outside the BST day to ensure they are excluded
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED3", created_at: Time.utc(2022, 5, 31, 22, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED4", created_at: Time.utc(2022, 6, 1, 23, 0, 0), form_document: form_document_with_batch_enabled)
        end

        it "includes only forms/modes with submissions on the date" do
          expect(daily_batches.map(&:to_h)).to contain_exactly(
            a_hash_including(form_id: form_id, mode: "form"),
            a_hash_including(form_id: form_id, mode: "preview-draft"),
          )
        end

        it "includes only submissions on the day in the batches" do
          expect(daily_batches.to_a[0].submissions.pluck(:reference)).to contain_exactly(form_submission.reference)
          expect(daily_batches.to_a[1].submissions.pluck(:reference)).to contain_exactly(preview_draft_submission.reference)
        end
      end

      context "when the date is not in BST" do
        let(:date) { Time.zone.local(2022, 12, 1) }

        let!(:form_submission) do
          create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2022, 12, 1, 0, 0, 0), form_document: form_document_with_batch_enabled)
        end
        let!(:preview_draft_submission) do
          create(:submission, form_id: form_id, mode: "preview-draft", reference: "INCLUDED2", created_at: Time.utc(2022, 12, 1, 23, 59, 59), form_document: form_document_with_batch_enabled)
        end

        before do
          # create form/mode combinations that only have submissions outside the day
          create(:submission, form_id: form_id, mode: "preview-archived", reference: "OMITTED1", created_at: Time.utc(2022, 11, 30, 23, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: 102, mode: "form", reference: "OMITTED2", created_at: Time.utc(2022, 12, 2, 0, 0, 0), form_document: form_document_with_batch_enabled)

          # create submissions for the form/mode included in a batch outside the day to ensure they are excluded
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED3", created_at: Time.utc(2022, 11, 30, 23, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED4", created_at: Time.utc(2022, 12, 2, 0, 0, 0), form_document: form_document_with_batch_enabled)
        end

        it "includes only forms/modes with submissions on the date" do
          expect(daily_batches.map(&:to_h)).to contain_exactly(
            a_hash_including(form_id: form_id, mode: "form"),
            a_hash_including(form_id: form_id, mode: "preview-draft"),
          )
        end

        it "includes only submissions on the day in the batches" do
          expect(daily_batches.to_a[0].submissions.pluck(:reference)).to contain_exactly(form_submission.reference)
          expect(daily_batches.to_a[1].submissions.pluck(:reference)).to contain_exactly(preview_draft_submission.reference)
        end
      end
    end

    context "when send_daily_submission_batch is enabled part-way through the day for the form document" do
      let!(:latest_submission) do
        create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2022, 12, 1, 10, 0, 0), form_document: form_document_with_batch_enabled)
      end
      let!(:earlier_submission) do
        create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED2", created_at: Time.utc(2022, 12, 1, 9, 0, 0), form_document: form_document_with_batch_disabled)
      end

      it "includes a batch for the form and mode" do
        expect(daily_batches.map(&:to_h)).to contain_exactly(
          a_hash_including(form_id: form_id, mode: "form"),
        )
      end

      it "includes all the submissions in the batch" do
        submissions = daily_batches.first.submissions
        expect(submissions.pluck(:reference)).to contain_exactly(latest_submission.reference, earlier_submission.reference)
      end
    end

    context "when send_daily_submission_batch is disabled for the form document" do
      before do
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2022, 12, 1, 10, 0, 0), form_document: form_document_with_batch_disabled)
      end

      it "does not include a batch for the form and mode" do
        expect(daily_batches.to_a).to be_empty
      end
    end

    context "when send_daily_submission_batch is disabled part-way through the day for the form document" do
      before do
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2022, 12, 1, 10, 0, 0), form_document: form_document_with_batch_disabled)
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2022, 12, 1, 9, 0, 0), form_document: form_document_with_batch_enabled)
      end

      it "does not include a batch for the form and mode" do
        expect(daily_batches.to_a).to be_empty
      end
    end
  end

  describe ".weekly_batches" do
    subject(:weekly_batches) { described_class.weekly_batches(date) }

    let(:date) { Time.zone.local(2025, 5, 19) }
    let(:form_document_with_batch_enabled) { build(:v2_form_document, send_weekly_submission_batch: true) }
    let(:form_document_with_batch_disabled) { build(:v2_form_document, send_weekly_submission_batch: false) }

    it "returns an enumerator" do
      expect(weekly_batches).to be_an(Enumerator)
    end

    context "when send_weekly_submission_batch is enabled for the form document" do
      context "when the week is during BST" do
        let(:date) { Time.zone.local(2025, 5, 19) }

        let!(:form_submission) do
          create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2025, 5, 18, 23, 0, 0), form_document: form_document_with_batch_enabled)
        end
        let!(:preview_draft_submission) do
          create(:submission, form_id: form_id, mode: "preview-draft", reference: "INCLUDED2", created_at: Time.utc(2025, 5, 25, 22, 59, 59), form_document: form_document_with_batch_enabled)
        end

        before do
          # create form/mode combinations that only have submissions outside the BST week
          create(:submission, form_id: form_id, mode: "preview-archived", reference: "OMITTED1", created_at: Time.utc(2025, 5, 18, 22, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: 102, mode: "form", reference: "OMITTED2", created_at: Time.utc(2025, 5, 25, 23, 0, 0), form_document: form_document_with_batch_enabled)

          # create submissions for the form/mode included in a batch outside the BST week to ensure they are excluded
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED3", created_at: Time.utc(2025, 5, 18, 22, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED4", created_at: Time.utc(2025, 5, 25, 23, 0, 0), form_document: form_document_with_batch_enabled)
        end

        it "includes only forms/modes with submissions in the week" do
          expect(weekly_batches.map(&:to_h)).to contain_exactly(
            a_hash_including(form_id: form_id, mode: "form"),
            a_hash_including(form_id: form_id, mode: "preview-draft"),
          )
        end

        it "includes only submissions in the week in the batches" do
          expect(weekly_batches.to_a[0].submissions.pluck(:reference)).to contain_exactly(form_submission.reference)
          expect(weekly_batches.to_a[1].submissions.pluck(:reference)).to contain_exactly(preview_draft_submission.reference)
        end
      end

      context "when the week is not in BST" do
        let(:date) { Time.zone.local(2025, 11, 3) }

        let!(:form_submission) do
          create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2025, 11, 3, 0, 0, 0), form_document: form_document_with_batch_enabled)
        end
        let!(:preview_draft_submission) do
          create(:submission, form_id: form_id, mode: "preview-draft", reference: "INCLUDED2", created_at: Time.utc(2025, 11, 9, 23, 59, 59), form_document: form_document_with_batch_enabled)
        end

        before do
          # create form/mode combinations that only have submissions outside the week
          create(:submission, form_id: form_id, mode: "preview-archived", reference: "OMITTED1", created_at: Time.utc(2025, 11, 2, 23, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: 102, mode: "form", reference: "OMITTED2", created_at: Time.utc(2025, 11, 10, 0, 0, 0), form_document: form_document_with_batch_enabled)

          # create submissions for the form/mode included in a batch outside the week to ensure they are excluded
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED3", created_at: Time.utc(2025, 11, 2, 23, 59, 59), form_document: form_document_with_batch_enabled)
          create(:submission, form_id: form_id, mode: "form", reference: "OMITTED4", created_at: Time.utc(2025, 11, 10, 0, 0, 0), form_document: form_document_with_batch_enabled)
        end

        it "includes only forms/modes with submissions in the week" do
          expect(weekly_batches.map(&:to_h)).to contain_exactly(
            a_hash_including(form_id: form_id, mode: "form"),
            a_hash_including(form_id: form_id, mode: "preview-draft"),
          )
        end

        it "includes only submissions in the week in the batches" do
          expect(weekly_batches.to_a[0].submissions.pluck(:reference)).to contain_exactly(form_submission.reference)
          expect(weekly_batches.to_a[1].submissions.pluck(:reference)).to contain_exactly(preview_draft_submission.reference)
        end
      end
    end

    context "when send_weekly_submission_batch is enabled part-way through the week for the form document" do
      let(:date) { Time.zone.local(2025, 11, 3) }

      let!(:latest_submission) do
        create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED1", created_at: Time.utc(2025, 11, 5, 0, 0, 0), form_document: form_document_with_batch_enabled)
      end
      let!(:earlier_submission) do
        create(:submission, form_id: form_id, mode: "form", reference: "INCLUDED2", created_at: Time.utc(2025, 11, 4, 0, 0, 0), form_document: form_document_with_batch_disabled)
      end

      it "includes a batch for the form and mode" do
        expect(weekly_batches.map(&:to_h)).to contain_exactly(
          a_hash_including(form_id: form_id, mode: "form"),
        )
      end

      it "includes all the submissions in the batch" do
        submissions = weekly_batches.first.submissions
        expect(submissions.pluck(:reference)).to contain_exactly(latest_submission.reference, earlier_submission.reference)
      end
    end

    context "when send_weekly_submission_batch is disabled for the form document" do
      let(:date) { Time.zone.local(2025, 11, 3) }

      before do
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2025, 11, 5, 10, 0, 0), form_document: form_document_with_batch_disabled)
      end

      it "does not include a batch for the form and mode" do
        expect(weekly_batches.to_a).to be_empty
      end
    end

    context "when send_weekly_submission_batch is disabled part-way through the week for the form document" do
      let(:date) { Time.zone.local(2025, 11, 3) }

      before do
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2025, 11, 5, 0, 0, 0), form_document: form_document_with_batch_disabled)
        create(:submission, form_id: form_id, mode: "form", created_at: Time.utc(2025, 11, 4, 0, 0, 0), form_document: form_document_with_batch_enabled)
      end

      it "does not include a batch for the form and mode" do
        expect(weekly_batches.to_a).to be_empty
      end
    end
  end
end
