require "rails_helper"

RSpec.describe AwsSesSubmissionBatchService do
  let(:service) { described_class.new(submissions_query:, form:, mode:) }
  let(:form) { Form.new(form_document) }
  let(:form_document) { build(:v2_form_document, :with_steps, submission_email:) }
  let(:submission_email) { "submit@email.gov.uk" }
  let(:mode) { instance_double(Mode, preview?: false) }
  let(:submissions_query) { Submission.all }

  describe "#send_daily_batch" do
    let(:date) { Date.new(2024, 6, 1) }

    before do
      allow(SubmissionFilenameGenerator).to receive(:daily_batch_csv_filename).and_return("filename.csv")
      allow(CsvGenerator).to receive(:generate_batched_submissions).and_return(%w[csv-content])
      create_list(:submission, 3, form_document:)
    end

    it "calls the SubmissionFilenameGenerator with a nil form version" do
      expect(SubmissionFilenameGenerator).to receive(:daily_batch_csv_filename).with(form_name: form.name, date:, mode:, csv_version: nil)
      service.send_daily_batch(date:)
    end

    it "returns the message id" do
      message_id = service.send_daily_batch(date:)

      last_email = ActionMailer::Base.deliveries.last
      expect(message_id).to eq last_email.message_id
    end

    context "when the csv generator returns a single csv version" do
      it "calls the AwsSesSubmissionBatchMailer to send the email with the generated file" do
        expect(AwsSesSubmissionBatchMailer).to receive(:daily_submission_batch_email)
                                                 .with(
                                                   form:,
                                                   date:,
                                                   mode:,
                                                   files: { "filename.csv" => "csv-content" },
                                                 ).and_call_original

        service.send_daily_batch(date:)
      end
    end

    context "when the csv generator returns multiple csv versions" do
      before do
        allow(CsvGenerator).to receive(:generate_batched_submissions).and_return(%w[csv-content csv-content-2])
        allow(SubmissionFilenameGenerator).to receive(:daily_batch_csv_filename).and_return("filename.csv", "filename-2.csv")
      end

      it "calls the SubmissionFilenameGenerator to generate a filename for each form version" do
        expect(SubmissionFilenameGenerator).to receive(:daily_batch_csv_filename).with(form_name: form.name, date:, mode:, csv_version: 1)
        expect(SubmissionFilenameGenerator).to receive(:daily_batch_csv_filename).with(form_name: form.name, date:, mode:, csv_version: 2)
        service.send_daily_batch(date:)
      end

      it "calls the AwsSesSubmissionBatchMailer to send the email with the generated files" do
        expect(AwsSesSubmissionBatchMailer).to receive(:daily_submission_batch_email)
                                                 .with(
                                                   form:,
                                                   date:,
                                                   mode:,
                                                   files: { "filename.csv" => "csv-content", "filename-2.csv" => "csv-content-2" },
                                                 ).and_call_original

        service.send_daily_batch(date:)
      end
    end
  end

  describe "#send_weekly_batch" do
    let(:begin_date) { Date.new(2024, 6, 1) }
    let(:end_date) { Date.new(2024, 6, 7) }

    before do
      allow(SubmissionFilenameGenerator).to receive(:weekly_batch_csv_filename).and_return("filename.csv")
      allow(CsvGenerator).to receive(:generate_batched_submissions).and_return(%w[csv-content])
      create_list(:submission, 3, form_document:)
    end

    it "calls the SubmissionFilenameGenerator with a nil form version" do
      expect(SubmissionFilenameGenerator).to receive(:weekly_batch_csv_filename).with(form_name: form.name, mode:, csv_version: nil, begin_date:, end_date:)
      service.send_weekly_batch(begin_date:, end_date:)
    end

    it "returns the message id" do
      message_id = service.send_weekly_batch(begin_date:, end_date:)

      last_email = ActionMailer::Base.deliveries.last
      expect(message_id).to eq last_email.message_id
    end

    context "when the csv generator returns a single csv version" do
      it "calls the AwsSesSubmissionBatchMailer to send the email with the generated file" do
        expect(AwsSesSubmissionBatchMailer).to receive(:weekly_submission_batch_email)
                                                 .with(
                                                   form:,
                                                   begin_date:,
                                                   end_date:,
                                                   mode:,
                                                   files: { "filename.csv" => "csv-content" },
                                                 ).and_call_original

        service.send_weekly_batch(begin_date:, end_date:)
      end
    end

    context "when the csv generator returns multiple csv versions" do
      before do
        allow(CsvGenerator).to receive(:generate_batched_submissions).and_return(%w[csv-content csv-content-2])
        allow(SubmissionFilenameGenerator).to receive(:weekly_batch_csv_filename).and_return("filename.csv", "filename-2.csv")
      end

      it "calls the SubmissionFilenameGenerator to generate a filename for each form version" do
        expect(SubmissionFilenameGenerator).to receive(:weekly_batch_csv_filename).with(form_name: form.name, mode:, csv_version: 1, begin_date:, end_date:)
        expect(SubmissionFilenameGenerator).to receive(:weekly_batch_csv_filename).with(form_name: form.name, mode:, csv_version: 2, begin_date:, end_date:)
        service.send_weekly_batch(begin_date:, end_date:)
      end

      it "calls the AwsSesSubmissionBatchMailer to send the email with the generated files" do
        expect(AwsSesSubmissionBatchMailer).to receive(:weekly_submission_batch_email)
                                                 .with(
                                                   form:,
                                                   begin_date:,
                                                   end_date:,
                                                   mode:,
                                                   files: { "filename.csv" => "csv-content", "filename-2.csv" => "csv-content-2" },
                                                 ).and_call_original

        service.send_weekly_batch(begin_date:, end_date:)
      end
    end
  end
end
