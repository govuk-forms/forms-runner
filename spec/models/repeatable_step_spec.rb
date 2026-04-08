require "rails_helper"

RSpec.describe RepeatableStep, type: :model do
  subject(:repeatable_step) { described_class.new(question:, form_document_step:) }

  let(:form) { build :form, id: 1, form_slug: "form-slug", steps: [form_document_step, build(:v2_question_step, id: 2)] }
  let(:form_document_step) { build :v2_question_step }
  let(:question) { build :name, is_optional: false }
  let(:submission_reference) { "abc123" }

  describe "#repeatable?" do
    it "returns true" do
      expect(repeatable_step.repeatable?).to be true
    end
  end

  describe "#save_to_context" do
    let(:answer_store) { instance_double(Store::SessionAnswerStore) }

    it "calls save_step on the argument" do
      allow(answer_store).to receive(:save_step).with(repeatable_step, [question.serializable_hash])
      expect(repeatable_step.save_to_store(answer_store)).to be(repeatable_step)
    end
  end

  describe "#load_from_context" do
    let(:answer_store) { instance_double(Store::SessionAnswerStore) }

    context "when form context contains a non-array questions attribute" do
      it "raises an argument error" do
        allow(answer_store).to receive(:get_stored_answer).with(repeatable_step).and_return("a string")
        expect { repeatable_step.load_from_store(answer_store) }.to raise_error(ArgumentError)
      end
    end

    context "when form context contains an array questions attribute" do
      let(:question_attrs) { [first_attribute_hash, second_attribute_hash] }
      let(:first_attribute_hash) { { answer: "first" } }
      let(:second_attribute_hash) { { answer: "second" } }
      let(:question) { instance_double(Question::QuestionBase) }
      let(:question_dup) { instance_double(Question::QuestionBase) }

      it "builds the @questions array" do
        allow(answer_store).to receive(:get_stored_answer).with(repeatable_step).and_return(question_attrs)
        allow(question).to receive(:dup).and_return(question_dup)
        expect(question_dup).to receive(:assign_attributes).with(first_attribute_hash)
        expect(question_dup).to receive(:assign_attributes).with(second_attribute_hash)

        expect(repeatable_step.load_from_store(answer_store).questions).to eq([question_dup, question_dup])
      end
    end
  end

  describe "#question" do
    let(:questions) { [1] }

    before do
      allow(question).to receive(:dup).and_return(1, 2, 3)
      repeatable_step.answer_index = answer_index
      repeatable_step.questions = questions
    end

    context "when the answer index is blank" do
      let(:answer_index) { nil }

      it "returns the first question" do
        expect(repeatable_step.question).to eq(1)
      end
    end

    context "when the answer index is exactly 1 greater than the questions length" do
      let(:answer_index) { 2 }

      it "duplicates question and adds it to the questions list" do
        expect(repeatable_step.question).to eq(2)
        expect(repeatable_step.questions).to eq([1, 2])
      end
    end

    context "when the answer index is outside the range of the questions list" do
      let(:answer_index) { 3 }

      it "raises an AnswerIndexError" do
        expect { repeatable_step.question }.to raise_error(RepeatableStep::AnswerIndexError)
      end
    end

    context "when the answer index is within the range of the questions list" do
      let(:answer_index) { 3 }
      let(:questions) { [1, 2, 3] }

      it "returns the question at that index" do
        expect(repeatable_step.question).to eq(3)
      end
    end
  end

  describe "#next_answer_index" do
    let(:questions) { [1, 2, 3] }

    before { repeatable_step.questions = questions }

    it "returns an index for the next question iteration" do
      expect(repeatable_step.next_answer_index).to eq(4)
    end
  end

  describe "#max_answers?" do
    before { repeatable_step.questions = questions }

    context "with 49 or fewer questions" do
      let(:questions) { Array.new(49, :a_default_value) }

      it "returns false" do
        expect(repeatable_step.max_answers?).to be(false)
      end
    end

    context "with 50 questions" do
      let(:questions) { Array.new(50, :a_default_value) }

      it "returns true" do
        expect(repeatable_step.max_answers?).to be(true)
      end
    end
  end

  describe "#show_answer" do
    let(:questions) { [first_question, second_question] }
    let(:first_question) { instance_double(Question::QuestionBase, show_answer: "first answer") }
    let(:second_question) { instance_double(Question::QuestionBase, show_answer: "second answer") }

    before { repeatable_step.questions = questions }

    it "returns an ordered list of answers" do
      expect(repeatable_step.show_answer).to eq('<ol class="govuk-list govuk-list--number"><li>first answer</li><li>second answer</li></ol>')
    end

    context "when the question is optional and has been skipped" do
      let(:questions) { [instance_double(Question::QuestionBase, show_answer: "")] }

      it "returns blank" do
        expect(repeatable_step.show_answer).to be_blank
      end
    end
  end

  describe "#show_answer_in_email" do
    let(:questions) { [first_question, second_question] }
    let(:first_question) { instance_double(Question::QuestionBase, show_answer_in_email: "first answer") }
    let(:second_question) { instance_double(Question::QuestionBase, show_answer_in_email: "second answer") }

    before { repeatable_step.questions = questions }

    it "returns an ordered list of answers" do
      expect(repeatable_step.show_answer_in_email(submission_reference:)).to eq("1. first answer\n\n2. second answer")
    end
  end

  describe "#show_answer_in_csv" do
    context "when the question has a single attribute" do
      let(:first_question) { build :text, :with_answer, question_text: "What is the meaning of life?" }
      let(:second_question) { build :text, :with_answer, question_text: "What is the meaning of life?" }

      before do
        repeatable_step.questions = [first_question, second_question]
      end

      it "returns a hash with a single pair containing all answers separated by newlines" do
        show_answer_in_csv = repeatable_step.show_answer_in_csv(submission_reference:, is_s3_submission: false)
        expect(show_answer_in_csv).to eq({
          "What is the meaning of life?" => "Answer: #{first_question.text}\nAnswer: #{second_question.text}",
        })
      end
    end

    context "when the question has multiple attributes" do
      let(:first_question) { build :first_and_last_name_question, question_text: "What is your name?" }
      let(:second_question) { build :first_and_last_name_question, question_text: "What is your name?" }

      before do
        repeatable_step.questions = [first_question, second_question]
      end

      it "returns a hash with a key for each attribute and values containing all answers separated by newlines" do
        show_answer_in_csv = repeatable_step.show_answer_in_csv(submission_reference:, is_s3_submission: false)
        # we convert to an array to test the ordering of the hash
        expect(show_answer_in_csv.to_a).to eq({
          "What is your name? - First name" => "Answer: #{first_question.first_name}\nAnswer: #{second_question.first_name}",
          "What is your name? - Last name" => "Answer: #{first_question.last_name}\nAnswer: #{second_question.last_name}",
        }.to_a)
      end

      context "when one of the attributes is optional and has not been answered in one answer" do
        let(:first_question) { build :first_middle_last_name_question, question_text: "What is your name?", first_name: "Gabriel", middle_names: "", last_name: "Garciá Márquez" }
        let(:second_question) { build :first_middle_last_name_question, question_text: "What is your name?", first_name: "Prince", middle_names: "Rogers", last_name: "Nelson" }

        it "includes a blank answer line for the missing answer" do
          show_answer_in_csv = repeatable_step.show_answer_in_csv(submission_reference:, is_s3_submission: false)
          # we convert to an array to test the ordering of the hash
          expect(show_answer_in_csv.to_a).to eq({
            "What is your name? - First name" => "Answer: Gabriel\nAnswer: Prince",
            "What is your name? - Middle names" => "Answer: \nAnswer: Rogers",
            "What is your name? - Last name" => "Answer: Garciá Márquez\nAnswer: Nelson",
          }.to_a)
        end
      end
    end

    context "when the answer can contain newlines" do
      let(:first_question) { build :text, :with_long_text, question_text: "What is your text?", text: "Lorem ipsum\n\nDolor sit amet\nconsectetur adipiscing elit." }
      let(:second_question) { build :text, :with_long_text, question_text: "What is your text?", text: "Donec ac fingilla nisi\nIn tempor quam.\n" }

      before do
        repeatable_step.questions = [first_question, second_question]
      end

      it "returns a hash with values containing all answers separated by a single newline" do
        show_answer_in_csv = repeatable_step.show_answer_in_csv(submission_reference:, is_s3_submission: false)
        expect(show_answer_in_csv).to eq({
          "What is your text?" => "Answer: Lorem ipsum\n\nDolor sit amet\nconsectetur adipiscing elit.\nAnswer: Donec ac fingilla nisi\nIn tempor quam.\n",
        })
      end
    end

    context "when the question is optional and has no answers" do
      let(:question) { build :text, is_optional: false }

      it "returns a hash containing a key for the first answer with a blank value" do
        expect(repeatable_step.show_answer_in_csv(submission_reference:, is_s3_submission: false)).to eq({
          question.question_text => "",
        })
      end
    end
  end

  describe "#show_answer_in_json" do
    context "when the step has multiple answers" do
      let(:form_document_step) { build(:v2_question_step, :with_name_settings, id: 2) }
      let(:questions) { [first_question, second_question] }
      let(:first_question) { build :first_and_last_name_question, question_text: form_document_step.question_text }
      let(:second_question) { build :first_and_last_name_question, question_text: form_document_step.question_text }

      before { repeatable_step.questions = questions }

      it "returns a hash containing arrays with every answer" do
        expect(repeatable_step.show_answer_in_json(submission_reference:, is_s3_submission: false)).to eq(
          {
            question_id: form_document_step.id,
            question_text: form_document_step.question_text,
            can_have_multiple_answers: true,
            first_name: [first_question.first_name, second_question.first_name],
            last_name: [first_question.last_name, second_question.last_name],
            answer_text: [first_question.show_answer, second_question.show_answer],
          },
        )
      end

      [true, false].each do |is_s3_submission|
        context "when is_s3_submission is #{is_s3_submission}" do
          it "passes is_s3_submission argument to the question" do
            allow(first_question).to receive(:show_answer_in_json).and_call_original
            expect(first_question).to receive(:show_answer_in_json).with(submission_reference:, is_s3_submission:).and_call_original
            expect(second_question).to receive(:show_answer_in_json).with(submission_reference:, is_s3_submission:).and_call_original
            repeatable_step.show_answer_in_json(submission_reference:, is_s3_submission:)
          end
        end
      end
    end

    context "when the question is optional and has no answers" do
      let(:form_document_step) { build(:v2_question_step, :with_name_settings, id: 2) }
      let(:question) { build :first_and_last_name_question, :unanswered, question_text: form_document_step.question_text }

      it "returns a hash with an array containing a blank answer" do
        expect(repeatable_step.show_answer_in_json(submission_reference:, is_s3_submission: false)).to eq(
          {
            question_id: form_document_step.id,
            question_text: form_document_step.question_text,
            can_have_multiple_answers: true,
            answer_text: [],
            first_name: [],
            last_name: [],
          },
        )
      end
    end
  end

  describe "#remove_answer" do
    let(:questions) { [first_question, second_question] }
    let(:first_question) { instance_double(Question::QuestionBase, show_answer_in_email: "first answer") }
    let(:second_question) { instance_double(Question::QuestionBase, show_answer_in_email: "second answer") }

    before { repeatable_step.questions = questions }

    it "removes a question at the given answer index - 1" do
      repeatable_step.remove_answer(2)
      expect(repeatable_step.questions).to eq([first_question])
    end

    context "when removing an answer leaves questions empty" do
      let(:questions) { [first_question] }

      before { repeatable_step.answer_index = 1 }

      it "adds a blank answer" do
        repeatable_step.remove_answer(1)
        expect(repeatable_step.questions.first.question_text).to eq(question.question_text)
      end
    end
  end

  describe "#valid?" do
    let(:questions) { [first_question, second_question] }
    let(:first_question) { instance_double(Question::QuestionBase, valid?: true) }
    let(:second_question) { instance_double(Question::QuestionBase, valid?: true) }

    before { repeatable_step.questions = questions }

    context "when all questions are valid" do
      it "returns true" do
        expect(repeatable_step).to be_valid
      end
    end

    context "when a questions is not valid" do
      let(:second_question) { instance_double(Question::QuestionBase, valid?: false) }

      it "returns true" do
        expect(repeatable_step).not_to be_valid
      end
    end
  end

  describe "#min_answers?" do
    before { repeatable_step.questions = questions }

    context "when there is one value in questions" do
      let(:questions) { [first_question] }
      let(:first_question) { instance_double(Question::QuestionBase) }

      it "returns true" do
        expect(repeatable_step).to be_min_answers
      end

      context "when the question is optional" do
        let(:question) { build :name, is_optional: true }

        it "returns false" do
          expect(repeatable_step).not_to be_min_answers
        end
      end
    end

    context "when there are at least two values in questions" do
      let(:questions) { [first_question, second_question] }
      let(:first_question) { instance_double(Question::QuestionBase) }
      let(:second_question) { instance_double(Question::QuestionBase) }

      it "returns true" do
        expect(repeatable_step).not_to be_min_answers
      end
    end
  end
end
