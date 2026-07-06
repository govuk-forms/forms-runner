require "rails_helper"

RSpec.describe CsvGenerator do
  let(:form_document) { build(:v2_form_document, form_id: 42, available_languages:, steps: [text_step, name_step, file_upload_step], start_page: text_step.id) }
  let(:submission) { create(:submission, form_document:, created_at: timestamp, reference: submission_reference, mode:, submission_locale:, answers:) }
  let(:text_step) { build :v2_question_step, :with_text_settings, question_text: "What is the meaning of life?", next_step_id: name_step.id }
  let(:name_step) { build :v2_question_step, :with_name_settings, question_text: "What is your name?", next_step_id: file_upload_step.id }
  let(:file_upload_step) { build :v2_question_step, :with_file_upload_settings, question_text: "Upload a file" }
  let(:text_answer) { "blue" }
  let(:first_name_answer) { "Alice" }
  let(:last_name_answer) { "Smith" }
  let(:file_upload_answer) { "file.txt" }
  let(:answers) do
    {
      text_step.id => { "text" => text_answer },
      name_step.id => { "first_name" => first_name_answer, "last_name" => last_name_answer },
      file_upload_step.id => { "original_filename" => file_upload_answer },
    }
  end

  let(:mode) { "form" }
  let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:submission_locale) { :en }
  let(:available_languages) { %w[en] }
  let(:timestamp) do
    Time.use_zone("London") { Time.zone.local(2022, 9, 14, 8, 0o0, 0o0) }
  end

  describe "#generate_submission" do
    subject(:csv) { described_class.generate_submission(submission:, is_s3_submission:) }

    context "when the submission is being sent by email" do
      let(:is_s3_submission) { false }

      it "returns a string" do
        expect(csv).to be_a(String)
      end

      it "generates the submission CSV" do
        expect(CSV.parse(csv)).to eq(
          [
            ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file"],
            [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference}.txt"],
          ],
        )
      end

      context "when a question is optional and answer is not provided" do
        let(:text_answer) { "" }

        it "generates a CSV including blank column for unanswered optional question" do
          expect(CSV.parse(csv)).to eq(
            [
              ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file"],
              [submission_reference, "2022-09-14T08:00:00+01:00", "", first_name_answer, last_name_answer, "file_#{submission_reference}.txt"],
            ],
          )
        end
      end

      context "when there are repeated steps" do
        let(:name_step) { build :v2_question_step, :with_name_settings, question_text: "What is your name?", next_step_id: file_upload_step.id, is_repeatable: true }
        let(:another_first_name_answer) { "John" }
        let(:another_last_name_answer) { "Smith" }
        let(:answers) do
          {
            text_step.id => { "text" => text_answer },
            name_step.id => [
              { "first_name" => first_name_answer, "last_name" => last_name_answer },
              { "first_name" => another_first_name_answer, "last_name" => another_last_name_answer },
            ],
            file_upload_step.id => { "original_filename" => file_upload_answer },
          }
        end

        it "generates a CSV with columns containing answers for the repeated steps separated by newlines" do
          expect(CSV.parse(csv)).to eq(
            [
              [
                "Reference",
                "Submitted at",
                "What is the meaning of life?",
                "What is your name? - First name",
                "What is your name? - Last name",
                "Upload a file",
              ],
              [
                submission_reference,
                "2022-09-14T08:00:00+01:00",
                text_answer,
                "Answer: #{first_name_answer}\nAnswer: #{another_first_name_answer}",
                "Answer: #{last_name_answer}\nAnswer: #{another_last_name_answer}",
                "file_#{submission_reference}.txt",
              ],
            ],
          )
        end
      end

      context "when the form has multiple available languages" do
        let(:available_languages) { %w[en cy] }

        it "generates the submission CSV with a language column" do
          expect(CSV.parse(csv)).to eq(
            [
              ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file", "Language"],
              [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference}.txt", "en"],
            ],
          )
        end
      end
    end

    context "when the submission is being sent to an S3 bucket" do
      let(:is_s3_submission) { true }

      it "generates a CSV without including the submission reference in the filename for the file upload question" do
        expect(CSV.parse(csv)).to eq(
          [
            ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file"],
            [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, file_upload_answer],
          ],
        )
      end
    end
  end

  describe "#generate_batched_submissions" do
    subject(:csv_list) { described_class.generate_batched_submissions(submissions_query:, is_s3_submission:) }

    let(:submission_reference_2) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
    let(:is_s3_submission) { false }
    let(:submissions_query) { Submission.all }

    context "when all submissions result in the same CSV headers" do
      before do
        submission
        create(:submission, form_document:, created_at: timestamp + 1.hour, reference: submission_reference_2, mode:, submission_locale: :cy, answers:)
      end

      it "returns an array with a single CSV string" do
        expect(csv_list).to be_a(Array)
        expect(csv_list.size).to eq(1)
        expect(csv_list.first).to be_a(String)
      end

      it "generates a CSV with multiple rows for the submissions" do
        csv = CSV.parse(csv_list.first)
        expect(csv.size).to eq(3) # header row + 2 submissions
        expect(csv).to eq(
          [
            ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file"],
            [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference}.txt"],
            [submission_reference_2, "2022-09-14T09:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference_2}.txt"],
          ],
        )
      end

      context "when the form has multiple available languages" do
        let(:available_languages) { %w[en cy] }

        it "generates a CSV with a language column" do
          expect(CSV.parse(csv_list.first)).to eq(
            [
              ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file", "Language"],
              [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference}.txt", "en"],
              [submission_reference_2, "2022-09-14T09:00:00+01:00", text_answer, first_name_answer, last_name_answer, "file_#{submission_reference_2}.txt", "cy"],
            ],
          )
        end
      end

      context "when the CSV is being sent to an S3 bucket" do
        let(:is_s3_submission) { true }

        it "generates a CSV without including the submission reference in the filename for the file upload question" do
          expect(CSV.parse(csv_list.first)).to eq(
            [
              ["Reference", "Submitted at", "What is the meaning of life?", "What is your name? - First name", "What is your name? - Last name", "Upload a file"],
              [submission_reference, "2022-09-14T08:00:00+01:00", text_answer, first_name_answer, last_name_answer, file_upload_answer],
              [submission_reference_2, "2022-09-14T09:00:00+01:00", text_answer, first_name_answer, last_name_answer, file_upload_answer],
            ],
          )
        end
      end
    end

    context "when all submissions result in different CSV headers" do
      let(:form_document) do
        build(
          :v2_form_document,
          steps: [text_step, name_step, file_upload_step],
          start_page: text_step.id,
          updated_at: Time.utc(2022, 9, 14, 7, 0, 0).iso8601(3),
        )
      end

      let(:form_document_same_steps) do
        build(
          :v2_form_document,
          steps: [text_step, name_step, file_upload_step],
          start_page: text_step.id,
          updated_at: Time.utc(2022, 9, 15, 7, 0, 0).iso8601(3),
        )
      end

      let(:form_document_different_steps) do
        build(
          :v2_form_document,
          steps: [name_step, file_upload_step],
          start_page: name_step.id,
          updated_at: Time.utc(2022, 9, 16, 7, 0, 0).iso8601(3),
        )
      end

      before do
        create_list(:submission, 2, form_document:, answers:)
        create_list(:submission, 3, form_document: form_document_same_steps, answers:)
        create_list(:submission, 4, form_document: form_document_different_steps, answers:)
      end

      it "creates a CSV for each incompatible set of form versions" do
        expect(csv_list.count).to eq(2)
        expect(CSV.parse(csv_list[0]).count).to eq(6)
        expect(CSV.parse(csv_list[1]).count).to eq(5)
      end
    end
  end
end
