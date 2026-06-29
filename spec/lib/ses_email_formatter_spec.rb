require "rails_helper"

RSpec.describe SesEmailFormatter do
  subject(:ses_email_formatter) { described_class.new(submission_reference:, steps:, confirmation_email:) }

  let(:confirmation_email) { false }
  let(:submission_reference) { "SUB-12345" }
  let(:text_question) { build :text, question_text: "What is the meaning of life?", text: "42" }
  let(:text_step) { build :step, question: text_question }
  let(:name_question) { build :first_middle_last_name_question, question_text: "What is your name?" }
  let(:name_step) { build :step, question: name_question }
  let(:file_question) { build :file, question_text: "Upload a file", original_filename: "a-file.txt" }
  let(:file_step) { build :step, question: file_question }
  let(:none_of_the_above_question) do
    build(
      :selection,
      :with_none_of_the_above_question,
      question_text: "What sandwich do you want?",
      none_of_the_above_question_text: "Specify your desired sandwich",
      selection: Question::Selection::NONE_OF_THE_ABOVE_VALUE,
      none_of_the_above_answer:,
      none_of_the_above_question_is_optional:,
    )
  end
  let(:none_of_the_above_answer) { "Cheese and pickle" }
  let(:none_of_the_above_question_is_optional) { "false" }
  let(:none_of_the_above_step) { build :step, question: none_of_the_above_question }
  let(:steps) { [text_step] }

  describe "#build_question_answers_section_markdown" do
    context "when there is one step" do
      it "returns question and and answer markdown" do
        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\n42")
      end

      it "formats with the specified heading level" do
        expect(ses_email_formatter.build_question_answers_section_markdown(heading_level: 4)).to eq("#### What is the meaning of life?\n\n42")
      end

      it "raises an error if the heading level is unsupported" do
        expect {
          ses_email_formatter.build_question_answers_section_markdown(heading_level: 2)
        }.to raise_error(SesEmailFormatter::FormattingError, "unsupported heading level: 2")
      end
    end

    context "when the answer has multiple attributes" do
      let(:steps) { [name_step] }

      it "inserts line breaks between answer attributes" do
        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is your name?\n\nFirst name: #{name_question.first_name}\n\nLast name: #{name_question.last_name}")
      end
    end

    context "when the answer is blank i.e. skipped" do
      let(:text_question) { build :text, question_text: "What is the meaning of life?", text: nil }
      let(:steps) { [text_step] }

      it "returns the blank answer text" do
        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\n[This question was skipped]")
      end

      context "when formatting for a confirmation email" do
        let(:confirmation_email) { true }

        it "returns the blank answer text" do
          expect(ses_email_formatter.build_question_answers_section_markdown).to include("Not completed")
        end
      end
    end

    context "when there is more than one step" do
      let(:steps) { [text_step, name_step] }

      it "returns all question an answers separated by a horizontal rule" do
        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\n42\n\n---\n\n### What is your name?\n\nFirst name: #{name_question.first_name}\n\nLast name: #{name_question.last_name}")
      end
    end

    context "when there are special characters in the answer" do
      let(:steps) { [text_step] }

      it "returns the sanitized answer" do
        [
          { input: "\n\nTest\n\nTest 2", output: "Test\n\nTest 2" },
          { input: "    paragraph 1\n\n\n\n\n\n\n\n\n\n\n\n\n Another Paragraph with trailing space     \n\n\n\n\n", output: "paragraph 1\n\nAnother Paragraph with trailing space" },

        ].each do |test_case|
          text_question.text = test_case[:input]

          expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\n#{test_case[:output]}")
        end
      end
    end

    context "when there are newline characters in the answer" do
      let(:steps) { [text_step] }

      it "converts single newlines into markdown linebreaks" do
        text_question.text = "Test\nTest 2"

        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\nTest  \nTest 2")
      end

      it "Converts multiple newlines into double newlines" do
        text_question.text = "Test\n\n\nTest 2\n\nTest 3"

        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What is the meaning of life?\n\nTest\n\nTest 2\n\nTest 3")
      end
    end

    context "when none of the above is selected in a none of the above question" do
      let(:steps) { [none_of_the_above_step] }

      it "returns the sanitized answer including the none of the above answer" do
        expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What sandwich do you want?\n\nNone of the above\n\n#### Specify your desired sandwich\n\nCheese and pickle")
      end

      context "when the none of the above question is optional and no answer is provided" do
        let(:none_of_the_above_answer) { nil }
        let(:none_of_the_above_question_is_optional) { "true" }

        it "returns the skipped none of the above answer text" do
          expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### What sandwich do you want?\n\nNone of the above\n\n#### Specify your desired sandwich (optional)\n\n[This question was skipped]")
        end

        context "when formatting for a confirmation email" do
          let(:confirmation_email) { true }

          it "returns the skipped none of the above answer text" do
            expect(ses_email_formatter.build_question_answers_section_markdown).to include("Not completed")
          end
        end
      end
    end

    context "when there is a file question" do
      let(:steps) { [file_step] }

      context "when formatting for a submission email" do
        it "returns the content for a submission email" do
          expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### Upload a file\n\na-file_SUB-12345.txt (attached to this email)")
        end
      end

      context "when formatting for a confirmation email" do
        let(:confirmation_email) { true }

        it "returns the content for a confirmation email" do
          expect(ses_email_formatter.build_question_answers_section_markdown).to eq("### Upload a file\n\nYou uploaded a file called a-file.txt")
        end
      end
    end

    context "when there is an error formatting an answer" do
      before do
        allow(text_step).to receive(:show_answer_in_email).and_raise(NoMethodError, "undefined method 'strip' for an instance of Array")
      end

      it "raises an error with the page id" do
        expect {
          ses_email_formatter.build_question_answers_section_markdown
        }.to raise_error(SesEmailFormatter::FormattingError, "could not format answer for question step #{text_step.id}")
      end
    end
  end
end
