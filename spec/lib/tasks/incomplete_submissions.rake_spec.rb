require "rails_helper"

RSpec.describe "incomplete_submissions.rake", type: :task do
  let(:email) { "test@example.com" }
  let(:secret_answer) { "a secret answer" }

  describe "incomplete_submissions:list_for_email" do
    subject(:task) do
      Rake::Task["incomplete_submissions:list_for_email"]
    end

    let!(:incomplete_submission) do
      create(:incomplete_submission, email:, form_id: 123, mode: "form", answers: { "1" => { "text" => secret_answer } })
    end

    before do
      create(:incomplete_submission, email: "other@example.com", form_id: 456)
    end

    it "aborts with the usage message when no email is given" do
      expect { task.invoke }
        .to raise_error(SystemExit)
        .and output("usage: rake incomplete_submissions:list_for_email[<email>]\n").to_stderr
    end

    it "lists the incomplete submissions for the email address" do
      expect { task.invoke(email) }
        .to output(a_string_including("Found 1 incomplete submissions", "form_id: 123", "submission_uuid: #{incomplete_submission.submission_uuid}")).to_stdout
    end

    it "does not list incomplete submissions for other email addresses" do
      expect { task.invoke(email) }.not_to output(a_string_including("form_id: 456")).to_stdout
    end

    it "does not output the answers" do
      expect { task.invoke(email) }.not_to output(a_string_including(secret_answer)).to_stdout
    end
  end

  describe "incomplete_submissions:delete_by_submission_uuid" do
    subject(:task) do
      Rake::Task["incomplete_submissions:delete_by_submission_uuid"]
    end

    let(:file_upload_s3_service) { instance_double(Question::FileUploadS3Service, delete_from_s3: nil) }

    let!(:to_delete) do
      create(:incomplete_submission, email:, form_id: 123, answers: { "1" => { "uploaded_file_key" => "file-key", "original_filename" => "a.png" } })
    end
    let!(:other) { create(:incomplete_submission, email:, form_id: 456) }

    before do
      allow(Question::FileUploadS3Service).to receive(:new).and_return(file_upload_s3_service)
    end

    it "aborts with the usage message when no submission_uuid is given" do
      expect { task.invoke }
        .to raise_error(SystemExit)
        .and output("usage: rake incomplete_submissions:delete_by_submission_uuid[<submission_uuid>]\n").to_stderr
    end

    it "aborts when the incomplete submission is not found" do
      expect { task.invoke("non-existent-uuid") }
        .to raise_error(SystemExit)
        .and output("Incomplete submission with submission_uuid non-existent-uuid not found\n").to_stderr
    end

    it "deletes only the incomplete submission with the submission_uuid" do
      expect { task.invoke(to_delete.submission_uuid) }.to output.to_stdout
      expect(IncompleteSubmission.all).to contain_exactly(other)
    end

    it "deletes uploaded files from S3" do
      expect { task.invoke(to_delete.submission_uuid) }.to output.to_stdout
      expect(file_upload_s3_service).to have_received(:delete_from_s3).with("file-key")
    end

    context "when deleting an uploaded file from S3 fails" do
      before do
        allow(file_upload_s3_service).to receive(:delete_from_s3).and_raise(Aws::S3::Errors::ServiceError.new(nil, "S3 error"))
      end

      it "does not delete the incomplete submission so the task can be retried" do
        expect { task.invoke(to_delete.submission_uuid) }.to raise_error(Aws::S3::Errors::ServiceError)
        expect(IncompleteSubmission.exists?(to_delete.id)).to be true
      end
    end

    it "outputs the deleted incomplete submission" do
      expect { task.invoke(to_delete.submission_uuid) }
        .to output("Deleted incomplete submission with submission_uuid #{to_delete.submission_uuid} for form 123\n").to_stdout
    end
  end
end
