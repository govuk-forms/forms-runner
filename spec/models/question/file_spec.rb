require "rails_helper"

RSpec.describe Question::File, type: :model do
  subject(:question) { described_class.new(attributes, options) }

  let(:attributes) { {} }

  let(:options) { { is_optional:, question_text: } }

  let(:is_optional) { false }
  let(:question_text) { Faker::Lorem.question }
  let(:extension) { ".png" }
  let(:tempfile) { Tempfile.new(["temp-file", extension]) }
  let(:original_filename) { "a-file#{extension}" }
  let(:file_size_in_bytes) { 2.megabytes }
  let(:file_type) { "image/png" }
  let(:file_content) { "not empty" }
  let(:submission_reference) { "abc123" }

  let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile) }
  let(:mock_file_upload_s3_service) { instance_double(Question::FileUploadS3Service) }

  before do
    File.write(tempfile, file_content)

    allow(Question::FileUploadS3Service).to receive(:new).and_return(mock_file_upload_s3_service)
    allow(uploaded_file).to receive_messages(original_filename: original_filename,
                                             tempfile: tempfile,
                                             size: file_size_in_bytes,
                                             content_type: file_type,
                                             path: tempfile.path)
  end

  after do
    tempfile.unlink
  end

  describe "base question" do
    let(:original_filename) { Faker::File.file_name }

    before do
      question.original_filename = original_filename
    end

    it_behaves_like "a question model"
  end

  describe "#before_save" do
    context "when a file was selected" do
      let(:mock_s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:bucket) { "an-s3-bucket" }
      let(:uuid) { Faker::Alphanumeric.alphanumeric }
      let(:key) { "#{uuid}#{extension}" }

      before do
        allow(mock_file_upload_s3_service).to receive(:upload_to_s3)

        allow(SecureRandom).to receive(:uuid).and_return uuid

        allow(Rails.logger).to receive(:info).at_least(:once)

        question.file = uploaded_file
      end

      context "when the virus scan successfully returns a status" do
        let(:scan_status) { Question::File::NO_THREATS_FOUND_SCAN_STATUS }

        before do
          allow(mock_file_upload_s3_service).to receive(:poll_for_scan_status).and_return(scan_status)
          question.before_save
        end

        it "puts object to S3" do
          expect(mock_file_upload_s3_service).to have_received(:upload_to_s3).with(tempfile, key)
        end

        it "sets the uploaded_file_key" do
          expect(question.uploaded_file_key).to eq key
        end

        it "sets the original_filename" do
          expect(question.original_filename).to eq original_filename
        end

        it "logs information about the file" do
          expect(Rails.logger).to have_received(:info).with("Uploaded file to S3 for file upload question",
                                                            { s3_object_key: key })
        end

        it "does not add any errors" do
          expect(question.errors).to be_empty
        end

        context "when the scan returns the threats found status" do
          let(:scan_status) { Question::File::THREATS_FOUND_SCAN_STATUS }

          it "does adds a contains_virus error" do
            expect(question.errors[:file]).to include "The selected file contains a virus"
          end
        end

        context "when the scan returns a different status" do
          let(:scan_status) { "FAILURE" }

          it "does adds a contains_virus error" do
            expect(question.errors[:file]).to include "The selected file could not be uploaded - try again"
          end
        end
      end

      context "when the scan times out" do
        before do
          allow(mock_file_upload_s3_service).to receive(:poll_for_scan_status).and_raise(Question::FileUploadS3Service::PollForScanResultTimeoutError)
          allow(Rails.logger).to receive(:error).at_least(:once)

          question.before_save
        end

        let(:scan_status) { nil }

        it "adds a contains_virus error" do
          expect(question.errors[:file]).to include "The selected file could not be uploaded - try again"
        end

        it "logs an error" do
          expect(Rails.logger).to have_received(:error).once.with(
            "Timed out polling for GuardDuty scan status for uploaded file",
            { s3_object_key: key },
          )
        end
      end
    end

    context "when no file was selected (question was optional)" do
      it "sets the original_filename question attribute to a blank string" do
        question.before_save
        expect(question.original_filename).to eq ""
      end
    end
  end

  describe "#show_answer" do
    let(:original_filename) { Faker::File.file_name(dir: "", directory_separator: "") }

    before do
      question.original_filename = original_filename
    end

    it "returns the original_filename" do
      expect(question.show_answer).to eq original_filename
    end

    context "when the file has a suffix set" do
      let(:attributes) { { original_filename:, filename_suffix: } }
      let(:filename_suffix) { "_1" }

      it "returns the filename without a suffix" do
        expect(question.show_answer).to eq original_filename
      end
    end
  end

  describe "#show_answer_in_email" do
    let(:attributes) { { original_filename:, filename_suffix: } }
    let(:filename_suffix) { "" }

    context "when the original_filename is blank" do
      let(:original_filename) { nil }

      it "returns a nil value" do
        expect(question.show_answer_in_email(submission_reference:)).to be_nil
      end
    end

    context "when the original_filename has a value" do
      context "when formatting for a submission email" do
        it "returns the filename containing the submission reference with the email attachment text" do
          expect(question.show_answer_in_email(submission_reference:)).to eq I18n.t("mailer.submission.file_attached", filename: "a-file_#{submission_reference}.png")
        end

        context "when the filename is long enough to be truncated" do
          let(:filename_suffix) { "_1" }
          let(:original_filename) { "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncated.doc" }

          it "returns a hash with a truncated filename containing the submission reference" do
            truncated_filename_with_suffix_and_reference = "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncated_1_#{submission_reference}.doc"

            expect(question.show_answer_in_email(submission_reference:)).to eq(I18n.t("mailer.submission.file_attached", filename: truncated_filename_with_suffix_and_reference))
          end
        end
      end

      context "when formatting for a confirmation email" do
        let(:filename_suffix) { "_1" } # ensure the suffix isn't used

        it "returns content for the confirmation email with the original filename" do
          expect(question.show_answer_in_email(submission_reference:, confirmation_email: true)).to eq(
            I18n.t("mailer.submission_confirmation.file_answer", filename: original_filename),
          )
        end
      end
    end
  end

  describe "#show_answer_in_csv" do
    let(:attributes) { { original_filename:, filename_suffix: } }
    let(:filename_suffix) { "" }
    let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

    context "when the original_filename is blank" do
      let(:original_filename) { nil }

      it "returns a hash with the question text and a nil value" do
        expect(question.show_answer_in_csv(submission_reference:, is_s3_submission: false)).to eq({ question.question_text => nil })
      end
    end

    context "when the original_filename has a value" do
      context "when is_s3_submission is false" do
        it "returns a hash with the filename containing the submission reference" do
          expect(question.show_answer_in_csv(submission_reference:, is_s3_submission: false)).to eq({ question.question_text => "a-file_#{submission_reference}.png" })
        end

        context "when the filename is long enough to be truncated" do
          let(:filename_suffix) { "_1" }
          let(:original_filename) { "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncated.doc" }

          it "returns a hash with a truncated filename containing the submission reference" do
            truncated_filename_with_suffix_and_reference = "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncate_1_#{submission_reference}.doc"

            expect(question.show_answer_in_csv(submission_reference:, is_s3_submission: false)).to eq({ question.question_text => truncated_filename_with_suffix_and_reference })
            expect(question.show_answer_in_csv(submission_reference:, is_s3_submission: false)[question.question_text].length).to eq 100
          end
        end
      end

      context "when is_s3_submission is true" do
        it "returns a hash with the filename_for_s3_submission" do
          expect(question.show_answer_in_csv(submission_reference:, is_s3_submission: true)).to eq({ question.question_text => original_filename })
        end
      end
    end
  end

  describe "#show_answer_in_json" do
    let(:attributes) { { original_filename:, filename_suffix: } }
    let(:filename_suffix) { "" }
    let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

    context "when the original_filename is blank" do
      let(:original_filename) { nil }

      it "returns a hash with a blank value" do
        expect(question.show_answer_in_json(submission_reference:, is_s3_submission: false)).to eq({ answer_text: "" })
      end
    end

    context "when the original_filename has a value" do
      context "when is_s3_submission is false" do
        it "returns a hash with the filename containing the submission reference" do
          expect(question.show_answer_in_json(submission_reference:, is_s3_submission: false)).to eq({ answer_text: "a-file_#{submission_reference}.png" })
        end

        context "when the filename is long enough to be truncated" do
          let(:filename_suffix) { "_1" }
          let(:original_filename) { "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncated.doc" }

          it "returns a hash with a truncated filename containing the submission reference" do
            truncated_filename_with_suffix_and_reference = "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncate_1_#{submission_reference}.doc"

            expect(question.show_answer_in_json(submission_reference:, is_s3_submission: false)).to eq({ answer_text: truncated_filename_with_suffix_and_reference })
            expect(question.show_answer_in_json(submission_reference:, is_s3_submission: false)[:answer_text].length).to eq 100
          end
        end
      end

      context "when is_s3_submission is true" do
        it "returns a hash with the filename_for_s3_submission" do
          expect(question.show_answer_in_json(submission_reference:, is_s3_submission: true)).to eq({ answer_text: original_filename })
        end
      end
    end
  end

  describe "#filename_for_s3_submission" do
    let(:attributes) { { original_filename:, filename_suffix: } }

    let(:original_filename) { "\"a\"_<>:/\\?*very_very_very_very_very_very_very_very_very_long_filename_just_about_long_enough_for_truncation.png" }
    let(:filename_suffix) { "_1" }

    it "returns a filename" do
      expect(question.filename_for_s3_submission).to eq "a_very_very_very_very_very_very_very_very_very_long_filename_just_about_long_enough_for_trunca_1.png"
      expect(question.filename_for_s3_submission.length).to eq 100
    end
  end

  describe "filename_after_reference_truncation" do
    let(:attributes) { { original_filename: } }

    let(:original_filename) { "\"this\"_<>:/\\?*is_an_incredibly_long_filename_that_will_surely_have_to_be_truncated_somewhere_near_the_end.xlsx" }

    it "returns a filename" do
      truncated_filename = "this_is_an_incredibly_long_filename_that_will_surely_have_to_be_truncated_somewhere_nea.xlsx"
      expect(question.filename_after_reference_truncation).to eq truncated_filename
    end
  end

  describe "email_filename" do
    let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
    let(:attributes) { { original_filename:, filename_suffix: } }

    let(:filename_suffix) { "_1" }
    let(:original_filename) { "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncated.doc" }

    it "sets the email_filename" do
      truncated_filename_with_suffix_and_reference = "an_unusual_and_atypically_long_filename_that_is_just_about_long_enough_to_be_truncate_1_#{submission_reference}.doc"

      expect(question.email_filename(submission_reference:)).to eq(truncated_filename_with_suffix_and_reference)
      expect(question.email_filename(submission_reference:).length).to eq 100
    end
  end

  describe "#file_from_s3" do
    let(:attributes) { { original_filename:, uploaded_file_key: } }

    let(:original_filename) { "a-file.png" }
    let(:uploaded_file_key) { Faker::Alphanumeric.alphanumeric }
    let(:file_content) { Faker::Lorem.sentence }

    before do
      allow(mock_file_upload_s3_service).to receive(:file_from_s3).with(uploaded_file_key).and_return(file_content)
    end

    it("reads file contents from S3") do
      expect(question.file_from_s3).to eq(file_content)
    end
  end

  describe "#delete_from_s3" do
    let(:attributes) { { original_filename: "a-file.png", uploaded_file_key: } }

    let(:uploaded_file_key) { Faker::Alphanumeric.alphanumeric }

    before do
      allow(mock_file_upload_s3_service).to receive(:delete_from_s3)
    end

    it("calls S3 to delete the file") do
      expect(mock_file_upload_s3_service).to receive(:delete_from_s3).with(uploaded_file_key)
      question.delete_from_s3
    end
  end

  describe "#file_uploaded?" do
    let(:attributes) { { uploaded_file_key: } }

    context "when a file has been uploaded" do
      let(:uploaded_file_key) { Faker::Alphanumeric.alphanumeric }

      it "returns true" do
        expect(question.file_uploaded?).to be true
      end
    end

    context "when a file has not been uploaded" do
      let(:uploaded_file_key) { nil }

      it "returns false" do
        expect(question.file_uploaded?).to be false
      end
    end
  end

  describe "#question_text_for_check_your_answers" do
    context "when page_heading is blank" do
      let(:options) { { is_optional:, question_text: } }

      it "returns the question text" do
        expect(question.question_text_for_check_your_answers).to eq question.question_text
      end

      it "returns the question text with optional suffix when the question is optional" do
        question.is_optional = true
        expect(question.question_text_for_check_your_answers).to eq "#{question.question_text} #{I18n.t('page.optional')}"
      end
    end

    context "when page_heading is set" do
      let(:page_heading) { Faker::Lorem.sentence }
      let(:options) { { is_optional:, question_text:, page_heading: } }

      it "returns the page heading in a caption before the question text" do
        expect(question.question_text_for_check_your_answers).to eq "<span class=\"govuk-caption-m govuk-!-margin-bottom-1\">#{page_heading}</span> #{question.question_text}"
      end

      it "returns the page heading in a caption before the question text with optional suffix when the question is optional" do
        question.is_optional = true
        expect(question.question_text_for_check_your_answers).to eq "<span class=\"govuk-caption-m govuk-!-margin-bottom-1\">#{page_heading}</span> #{question.question_text} #{I18n.t('page.optional')}"
      end
    end
  end

  describe "validations" do
    context "when the question is mandatory" do
      context "when no file is set" do
        it "returns an error" do
          expect(question).not_to be_valid
          expect(question.errors[:file]).to include "Select a file"
        end
      end
    end

    context "when the question is optional" do
      let(:is_optional) { true }

      context "when no file is set" do
        it "is valid" do
          expect(question).to be_valid
        end
      end
    end

    context "when the file size is greater than 7MB" do
      let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile) }
      let(:file_size_in_bytes) { 7.megabytes + 1 }
      let(:file_type) { "image/png" }

      before do
        question.file = uploaded_file
      end

      it "returns an error" do
        expect(question).not_to be_valid
        expect(question.errors[:file]).to include "The selected file must be smaller than 7MB"
      end
    end

    context "when the file size is empty" do
      let(:file_content) { "" }

      before do
        question.file = uploaded_file
      end

      it "returns an error" do
        expect(question).not_to be_valid
        expect(question.errors[:file]).to include "The selected file is empty"
      end
    end

    context "when the file type is not in the list of allowed file types" do
      let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile) }
      let(:file_size_in_bytes) { 7.megabytes }
      let(:file_type) { "text/javascript" }

      before do
        question.file = uploaded_file
      end

      it "returns an error" do
        expect(question).not_to be_valid
        expect(question.errors[:file]).to include I18n.t("activemodel.errors.models.question/file.attributes.file.disallowed_type")
      end
    end

    Question::File::FILE_TYPES.each do |file_type|
      context "when the file type is #{file_type}" do
        let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile) }
        let(:file_size_in_bytes) { 7.megabytes }

        before do
          allow(uploaded_file).to receive_messages(size: file_size_in_bytes, content_type: file_type)
          question.file = uploaded_file
        end

        it "does not return an error" do
          expect(question).to be_valid
          expect(question.errors[:file]).to be_empty
        end
      end
    end

    context "when the file is valid" do
      let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile) }
      let(:file_size_in_bytes) { 7.megabytes }
      let(:file_type) { "text/plain" }

      before do
        allow(uploaded_file).to receive_messages(size: file_size_in_bytes, content_type: file_type)
        question.file = uploaded_file
      end

      it "is valid" do
        expect(question).to be_valid
      end
    end

    context "when validating for submission" do
      let(:question) { described_class.new({ file: nil, original_filename:, uploaded_file_key:, filename_suffix: "" }, {}) }
      let(:uploaded_file_key) { "#{Faker::Internet.uuid}#{extension}" }

      before do
        question.validate :submission
      end

      it "is valid for submission" do
        expect(question).to be_valid(:submission)
      end

      context "when it does not have the original filename" do
        let(:original_filename) { "" }

        it "is not valid for submission" do
          expect(question).not_to be_valid(:submission)
        end

        it "has a blank original_filename error" do
          expect(question.errors.of_kind?(:original_filename, :blank)).to be true
        end
      end
    end
  end
end
