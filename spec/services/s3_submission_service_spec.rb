require "rails_helper"

RSpec.describe S3SubmissionService do
  subject(:service) { described_class.new(submission:, delivery:) }

  let(:submission) { build(:submission, form_document:, created_at: timestamp, reference: submission_reference, mode:, submission_locale:) }
  let(:delivery) { build :delivery, formats: %w[csv] }

  let(:form_document) do
    build(:v2_form_document,
          form_id: 42,
          s3_bucket_name:,
          s3_bucket_aws_account_id:,
          s3_bucket_region:,
          available_languages:)
  end
  let(:s3_bucket_name) { "a-bucket" }
  let(:s3_bucket_aws_account_id) { "23423423423423" }
  let(:s3_bucket_region) { "eu-west-1" }
  let(:file_upload_bucket) { "file-upload-bucket" }
  let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:submission_locale) { :en }
  let(:timestamp) do
    Time.use_zone("London") { Time.zone.local(2022, 9, 14, 8, 24, 34) }
  end
  let(:expected_timestamp) { "20220914T072434Z" }
  let(:all_steps) { [step] }
  let(:completed_file_upload_questions) { [] }
  let(:journey) { instance_double(Flow::Journey, completed_steps: all_steps, all_steps:, completed_file_upload_questions:) }
  let(:question) { build :text, question_text: "What is the meaning of life?", text: "42" }
  let(:step) { build :step, question: }
  let(:mode) { "form" }
  let(:available_languages) { %i[en] }

  before do
    allow(Flow::Journey).to receive(:new).and_return(journey)
  end

  describe "#submit" do
    let(:mock_credentials) { { foo: "bar" } }
    let(:mock_sts_client) { Aws::STS::Client.new(stub_responses: true) }
    let(:mock_s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:mock_file_upload_s3_service) { instance_double(Question::FileUploadS3Service) }
    let(:role_arn) { "arn:aws:iam::11111111111:role/test-role" }

    context "when the form is configured correctly with S3 bucket details" do
      before do
        allow(Aws::AssumeRoleCredentials).to receive(:new).and_return(mock_credentials)
        allow(Aws::STS::Client).to receive(:new).and_return(mock_sts_client)
        allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
        allow(Question::FileUploadS3Service).to receive(:new).and_return(mock_file_upload_s3_service)
        allow(mock_file_upload_s3_service).to receive(:delete_from_s3)
        allow(Settings.aws).to receive_messages(s3_submission_iam_role_arn: role_arn, file_upload_s3_bucket_name: file_upload_bucket)
        allow(CloudWatchService).to receive(:record_submission_delivery_latency_metric)
      end

      it "calls AWS to assume the role to upload to S3" do
        expected_session_name = "forms-runner-#{submission_reference}"
        expect(Aws::AssumeRoleCredentials).to receive(:new).with(client: mock_sts_client, role_arn:,
                                                                 role_session_name: expected_session_name)
        service.submit
      end

      it "creates an S3 client with the credentials for the assumed role" do
        expect(Aws::S3::Client).to receive(:new).with(region: s3_bucket_region, credentials: mock_credentials)
        service.submit
      end

      context "when the submission format is CSV" do
        let(:delivery) { build :delivery, formats: %i[csv] }

        it "calls put_object with a CSV file and filename" do
          expected_key_name = "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.csv"
          expected_csv_content = "Reference,Submitted at,What is the meaning of life?\n#{submission_reference},2022-09-14T08:24:34+01:00,42\n"
          expect(mock_s3_client).to receive(:put_object).with(
            {
              body: expected_csv_content,
              bucket: s3_bucket_name,
              expected_bucket_owner: s3_bucket_aws_account_id,
              key: expected_key_name,
            },
          )

          service.submit
        end

        context "when the submission is Welsh" do
          let(:submission_locale) { "cy" }
          let(:available_languages) { %i[en cy] }

          it "generates the submission CSV with the language field" do
            expected_csv_content = "Reference,Submitted at,What is the meaning of life?,Language\n#{submission_reference},2022-09-14T08:24:34+01:00,42,cy\n"
            expect(mock_s3_client).to receive(:put_object).with(hash_including(body: expected_csv_content))

            service.submit
          end
        end
      end

      context "when the submission format is JSON" do
        let(:delivery) { build :delivery, formats: %w[json] }

        it "calls put_object with a JSON file and filename" do
          expected_key_name = "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.json"
          expect(mock_s3_client).to receive(:put_object).with(
            {
              body: satisfy { |value| JSON.parse(value)["form_name"] == form_document.name },
              bucket: s3_bucket_name,
              expected_bucket_owner: s3_bucket_aws_account_id,
              key: expected_key_name,
            },
          )

          service.submit
        end

        context "when the submission is Welsh" do
          let(:submission_locale) { "cy" }
          let(:available_languages) { %i[en cy] }

          it "generates the submission JSON with the language field" do
            expect(mock_s3_client).to receive(:put_object).with(hash_including(body: satisfy { |args| JSON.parse(args)["language"] == "cy" }))

            service.submit
          end
        end
      end

      context "when the formats are nil on the delivery" do
        let(:delivery) { build :delivery, formats: nil }
        let(:form_document) do
          build(:v2_form_document, :s3_submissions_enabled, submission_format: %w[json])
        end

        it "falls back to using the submission_format on the form" do
          expected_key_name = "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.json"
          expect(mock_s3_client).to receive(:put_object).with(hash_including(key: expected_key_name))

          service.submit
        end
      end

      context "when the form has answered file upload questions" do
        let(:first_file_upload_question) { build(:file, :with_uploaded_file, original_filename: "file.txt") }
        let(:second_file_upload_question) { build(:file, :with_uploaded_file, original_filename: "file.txt", filename_suffix: "_1") }
        let(:completed_file_upload_questions) { [first_file_upload_question, second_file_upload_question] }
        let(:all_steps) do
          [
            build(:step, question: first_file_upload_question),
            build(:step, question: second_file_upload_question),
          ]
        end

        context "when the submission format is CSV" do
          let(:delivery) { build :delivery, formats: %i[csv] }

          it "creates the CSV file with the expected filenames" do
            expected_key_name = "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.csv"
            expected_csv_content = "Reference,Submitted at,#{first_file_upload_question.question_text},#{second_file_upload_question.question_text}\n" \
              "#{submission_reference},2022-09-14T08:24:34+01:00,file.txt,file_1.txt\n"
            expect(mock_s3_client).to receive(:put_object).with(
              {
                body: expected_csv_content,
                bucket: s3_bucket_name,
                expected_bucket_owner: s3_bucket_aws_account_id,
                key: expected_key_name,
              },
            )

            service.submit
          end
        end

        context "when the submission format is JSON" do
          let(:delivery) { build :delivery, formats: %w[json] }

          it "creates the JSON file with the expected filenames" do
            expected_key_name = "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.json"
            expect(mock_s3_client).to receive(:put_object).with(
              {
                body: satisfy do |value|
                  json = JSON.parse(value)
                  json["answers"][0]["answer_text"] == "file.txt" && json["answers"][1]["answer_text"] == "file_1.txt"
                end,
                bucket: s3_bucket_name,
                expected_bucket_owner: s3_bucket_aws_account_id,
                key: expected_key_name,
              },
            )

            service.submit
          end
        end

        it "copies the file objects to the submission S3 bucket" do
          expect(mock_s3_client).to receive(:copy_object).with({
            bucket: s3_bucket_name,
            expected_bucket_owner: s3_bucket_aws_account_id,
            copy_source: "/#{file_upload_bucket}/#{first_file_upload_question.uploaded_file_key}",
            key: "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/file.txt",
            tagging_directive: "REPLACE",
          })

          expect(mock_s3_client).to receive(:copy_object).with({
            bucket: s3_bucket_name,
            expected_bucket_owner: s3_bucket_aws_account_id,
            copy_source: "/#{file_upload_bucket}/#{second_file_upload_question.uploaded_file_key}",
            key: "form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/file_1.txt",
            tagging_directive: "REPLACE",
          })

          service.submit
        end

        it "deletes the file objects from the file upload S3 bucket" do
          expect(mock_file_upload_s3_service).to receive(:delete_from_s3).with(first_file_upload_question.uploaded_file_key)
          expect(mock_file_upload_s3_service).to receive(:delete_from_s3).with(second_file_upload_question.uploaded_file_key)

          service.submit
        end
      end

      it "sends cloudwatch metric for submission delivery time" do
        expect(CloudWatchService).to receive(:record_submission_delivery_latency_metric).with(2000, "S3")
        travel_to timestamp + 2.seconds do
          service.submit
        end
      end

      context "when a preview is being submitted" do
        let(:mode) { "preview-live" }
        let(:question) { build(:file, :with_uploaded_file, original_filename: "file.txt") }
        let(:completed_file_upload_questions) { [question] }

        it "calls put_object with the 'test_form_submissions/' key prefix" do
          expected_key_name = "test_form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/form_submission.csv"
          expected_csv_content = "Reference,Submitted at,#{question.question_text}\n#{submission_reference},2022-09-14T08:24:34+01:00,file.txt\n"
          expect(mock_s3_client).to receive(:put_object).with({
            body: expected_csv_content,
            bucket: s3_bucket_name,
            expected_bucket_owner: s3_bucket_aws_account_id,
            key: expected_key_name,
          })

          service.submit
        end

        it "copies uploaded files with the 'test_form_submissions/' key prefix" do
          expect(mock_s3_client).to receive(:copy_object).with({
            bucket: s3_bucket_name,
            expected_bucket_owner: s3_bucket_aws_account_id,
            copy_source: "/#{file_upload_bucket}/#{question.uploaded_file_key}",
            key: "test_form_submissions/#{form_document.form_id}/#{expected_timestamp}_#{submission_reference}/file.txt",
            tagging_directive: "REPLACE",
          })

          service.submit
        end
      end
    end

    context "when the form's s3_bucket_name is nil" do
      let(:s3_bucket_name) { nil }

      it "raises an error" do
        expect { service.submit }.to raise_error("S3 bucket name is not set on the form")
      end
    end

    context "when the form's s3_bucket_aws_account_id is nil" do
      let(:s3_bucket_aws_account_id) { nil }

      it "raises an error" do
        expect { service.submit }.to raise_error("S3 bucket account ID is not set on the form")
      end
    end

    context "when the form's s3_bucket_region is nil" do
      let(:s3_bucket_region) { nil }

      it "raises an error" do
        expect { service.submit }.to raise_error("S3 bucket region is not set on the form")
      end
    end
  end
end
