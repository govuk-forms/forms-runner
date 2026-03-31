require "rails_helper"

RSpec.describe SesEmailFormatter do
  subject(:ses_email_formatter) { described_class.new(submission_reference:, steps: steps) }

  let(:submission_reference) { "SUB-12345" }
  let(:text_question) { build :text, question_text: "What is the meaning of life?", text: "42" }
  let(:text_step) { build :step, question: text_question }
  let(:name_question) { build :first_middle_last_name_question, question_text: "What is your name?" }
  let(:name_step) { build :step, question: name_question }
  let(:none_of_the_above_question) do
    build(
      :selection,
      :with_none_of_the_above_question,
      question_text: "What sandwich do you want?",
      none_of_the_above_question_text: "Specify your desired sandwich",
      selection: "None of the above",
      none_of_the_above_answer:,
      none_of_the_above_question_is_optional:,
    )
  end
  let(:none_of_the_above_answer) { "Cheese and pickle" }
  let(:none_of_the_above_question_is_optional) { "false" }
  let(:none_of_the_above_step) { build :step, question: none_of_the_above_question }
  let(:steps) { [text_step] }

  describe "#build_question_answers_section_html" do
    context "when there is one step" do
      it "returns question and and answer HTML" do
        expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What is the meaning of life?</h3><p>42</p>")
      end
    end

    context "when the answer has multiple attributes" do
      let(:steps) { [name_step] }

      it "inserts line breaks between answer attributes" do
        expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What is your name?</h3><p>First name: #{name_question.first_name}<br/><br/>Last name: #{name_question.last_name}</p>")
      end
    end

    context "when the answer is blank i.e. skipped" do
      let(:text_question) { build :text, question_text: "What is the meaning of life?", text: nil }
      let(:steps) { [text_step] }

      it "returns the blank answer text" do
        expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What is the meaning of life?</h3><p>[This question was skipped]</p>")
      end
    end

    context "when there is more than one step" do
      let(:steps) { [text_step, name_step] }

      it "returns all question an answers separated by a horizontal rule" do
        expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What is the meaning of life?</h3><p>42</p><hr style=\"border: 0; height: 1px; background: #B1B4B6; Margin: 30px 0 30px 0;\"><h3>What is your name?</h3><p>First name: #{name_question.first_name}<br/><br/>Last name: #{name_question.last_name}</p>")
      end
    end

    context "when there are special characters in the answer" do
      let(:steps) { [text_step] }

      it "returns the sanitized answer" do
        [
          { input: "\n\nTest\n\nTest 2", output: "Test<br/><br/>Test 2" },
          { input: "    paragraph 1\n\n\n\n\n\n\n\n\n\n\n\n\n Another Paragraph with trailing space     \n\n\n\n\n", output: "paragraph 1<br/><br/>Another Paragraph with trailing space" },

        ].each do |test_case|
          text_question.text = test_case[:input]

          expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What is the meaning of life?</h3><p>#{test_case[:output]}</p>")
        end
      end
    end

    context "when none of the above is selected in a none of the above question" do
      let(:steps) { [none_of_the_above_step] }

      it "returns the sanitized answer including the none of the above answer" do
        expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What sandwich do you want?</h3><p>None of the above</p><h4>Specify your desired sandwich</h4><p>Cheese and pickle</p>")
      end

      context "when the none of the above question has no answer is provided" do
        let(:none_of_the_above_answer) { nil }
        let(:none_of_the_above_question_is_optional) { "true" }

        it "returns the skipped none of the above answer text" do
          expect(ses_email_formatter.build_question_answers_section_html).to eq("<h3>What sandwich do you want?</h3><p>None of the above</p><h4>Specify your desired sandwich (optional)</h4><p>[This question was skipped]</p>")
        end
      end
    end

    context "when there is an error formatting an answer" do
      before do
        text_step.form_document_step.id = 99
        allow(text_step).to receive(:show_answer_in_email).and_raise(NoMethodError, "undefined method 'strip' for an instance of Array")
      end

      it "raises an error with the page id" do
        expect {
          ses_email_formatter.build_question_answers_section_html
        }.to raise_error(SesEmailFormatter::FormattingError, "could not format answer for question step 99")
      end
    end
  end

  describe "#build_question_answers_section_plain_text" do
    context "when there is one step" do
      it "returns question and and answer HTML" do
        expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What is the meaning of life?\n\n42")
      end
    end

    context "when the answer has multiple attributes" do
      let(:steps) { [name_step] }

      it "inserts line breaks between answer attributes" do
        expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What is your name?\n\nFirst name: #{name_question.first_name}\n\nLast name: #{name_question.last_name}")
      end
    end

    context "when the answer is blank i.e. skipped" do
      let(:text_question) { build :text, question_text: "What is the meaning of life?", text: nil }
      let(:steps) { [text_step] }

      it "returns the blank answer text" do
        expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What is the meaning of life?\n\n[This question was skipped]")
      end
    end

    context "when there is more than one step" do
      let(:steps) { [text_step, name_step] }

      it "returns all question an answers separated by a horizontal rule" do
        expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What is the meaning of life?\n\n42\n\n---\n\nWhat is your name?\n\nFirst name: #{name_question.first_name}\n\nLast name: #{name_question.last_name}")
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

          expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What is the meaning of life?\n\n#{test_case[:output]}")
        end
      end
    end

    context "when none of the above is selected in a none of the above question" do
      let(:steps) { [none_of_the_above_step] }

      it "returns the sanitized answer including the none of the above answer" do
        expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What sandwich do you want?\n\nNone of the above\n\nSpecify your desired sandwich\n\nCheese and pickle")
      end

      context "when the none of the above question is optional and no answer is provided" do
        let(:none_of_the_above_answer) { nil }
        let(:none_of_the_above_question_is_optional) { "true" }

        it "returns the skipped none of the above answer text" do
          expect(ses_email_formatter.build_question_answers_section_plain_text).to eq("What sandwich do you want?\n\nNone of the above\n\nSpecify your desired sandwich (optional)\n\n[This question was skipped]")
        end
      end
    end

    context "when there is an error formatting an answer" do
      before do
        text_step.form_document_step.id = 99
        allow(text_step).to receive(:show_answer_in_email).and_raise(NoMethodError, "undefined method 'strip' for an instance of Array")
      end

      it "raises an error with the page id" do
        expect {
          ses_email_formatter.build_question_answers_section_plain_text
        }.to raise_error(SesEmailFormatter::FormattingError, "could not format answer for question step 99")
      end
    end
  end
end
