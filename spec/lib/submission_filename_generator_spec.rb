require "rails_helper"

RSpec.describe SubmissionFilenameGenerator do
  describe "#csv_filename" do
    let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

    context "when there is a long form name that would cause the filename to be longer than 100 characters" do
      let(:form_name) { "A form name that will cause the filename to be truncated to obey the limittt" }

      it "truncates the form name in the filename" do
        filename = described_class.csv_filename(form_name:, submission_reference:)
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_truncated_to_obey_the_#{submission_reference}.csv")
      end
    end

    context "when the form name would cause the filename to be exactly 100 characters long" do
      let(:form_name) { "A form name that will cause the filename to be 100 characters long exactlyy" }

      it "does not truncate the form name in the filename" do
        filename = described_class.csv_filename(form_name:, submission_reference:)
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_100_characters_long_exactlyy_#{submission_reference}.csv")
      end
    end
  end

  describe "#json_filename" do
    let(:submission_reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

    context "when there is a long form name that would cause the filename to be longer than 100 characters" do
      let(:form_name) { "A form name that will cause the filename to be truncated to obey the limitt" }

      it "truncates the form name in the filename" do
        filename = described_class.json_filename(form_name:, submission_reference:)
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_truncated_to_obey_the_#{submission_reference}.json")
      end
    end

    context "when the form name would cause the filename to be exactly 100 characters long" do
      let(:form_name) { "A form name that will cause the filename to be 100 characters long exactly" }

      it "does not truncate the form name in the filename" do
        filename = described_class.json_filename(form_name:, submission_reference:)
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_100_characters_long_exactly_#{submission_reference}.json")
      end
    end
  end

  describe "#daily_batch_csv_filename" do
    subject(:filename) { described_class.daily_batch_csv_filename(form_name:, mode:, csv_version:, date:) }

    let(:date) { Time.zone.local(2024, 6, 1) }
    let(:mode) { instance_double(Mode, preview?: false) }
    let(:csv_version) { "1" }

    context "when there is a long form name that would cause the filename to be longer than 100 characters" do
      let(:form_name) { "A form name that will cause the filename to be truncated to obey the limit" }

      it "truncates the form name in the filename" do
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_truncated_to_obey_the_2024-06-01_1.csv")
      end
    end

    context "when the form name would cause the filename to be exactly 100 characters long" do
      let(:form_name) { "Form name that will cause the filename to be 100 characters long exact" }

      it "does not truncate the form name in the filename" do
        expect(filename).to eq("govuk_forms_form_name_that_will_cause_the_filename_to_be_100_characters_long_exact_2024-06-01_1.csv")
      end
    end

    context "when there is no form version provided" do
      let(:form_name) { "Form name" }
      let(:csv_version) { nil }

      it "does not include the form version in the filename" do
        expect(filename).to eq("govuk_forms_form_name_2024-06-01.csv")
      end
    end

    context "when the mode is preview" do
      let(:mode) { instance_double(Mode, preview?: true) }
      let(:form_name) { "Form name" }

      it "includes 'test_' in the filename" do
        expect(filename).to eq("test_govuk_forms_form_name_2024-06-01_1.csv")
      end

      context "when the form name would cause the filename to be over 100 characters long including the 'test_' prefix" do
        let(:form_name) { "A form name that will cause the filename to be truncated to obey the limit" }

        it "truncates the form name in the filename" do
          expect(filename).to eq("test_govuk_forms_a_form_name_that_will_cause_the_filename_to_be_truncated_to_obey_2024-06-01_1.csv")
        end
      end
    end
  end

  describe "#weekly_batch_csv_filename" do
    subject(:filename) { described_class.weekly_batch_csv_filename(form_name:, mode:, csv_version:, begin_date:, end_date:) }

    let(:begin_date) { Time.zone.local(2024, 6, 1) }
    let(:end_date) { Time.zone.local(2024, 6, 7) }
    let(:mode) { instance_double(Mode, preview?: false) }
    let(:csv_version) { "1" }

    context "when there is a long form name that would cause the filename to be longer than 100 characters" do
      let(:form_name) { "A form name that will cause the filename to be truncated to obey" }

      it "truncates the form name in the filename" do
        expect(filename).to eq("govuk_forms_a_form_name_that_will_cause_the_filename_to_be_truncated_to_2024-06-01--2024-06-07_1.csv")
      end
    end

    context "when the form name would cause the filename to be exactly 100 characters long" do
      let(:form_name) { "Form name that will cause the filename to be 100 characters" }

      it "does not truncate the form name in the filename" do
        expect(filename).to eq("govuk_forms_form_name_that_will_cause_the_filename_to_be_100_characters_2024-06-01--2024-06-07_1.csv")
      end
    end

    context "when there is no form version provided" do
      let(:form_name) { "Form name" }
      let(:csv_version) { nil }

      it "does not include the form version in the filename" do
        expect(filename).to eq("govuk_forms_form_name_2024-06-01--2024-06-07.csv")
      end
    end

    context "when the mode is preview" do
      let(:mode) { instance_double(Mode, preview?: true) }
      let(:form_name) { "Form name" }

      it "includes 'test_' in the filename" do
        expect(filename).to eq("test_govuk_forms_form_name_2024-06-01--2024-06-07_1.csv")
      end

      context "when the form name would cause the filename to be over 100 characters long including the 'test_' prefix" do
        let(:form_name) { "A form name that will cause the filename to be truncated" }

        it "truncates the form name in the filename" do
          expect(filename).to eq("test_govuk_forms_a_form_name_that_will_cause_the_filename_to_be_2024-06-01--2024-06-07_1.csv")
        end
      end
    end
  end
end
