require "rails_helper"
require "ostruct"

RSpec.describe Store::SessionAnswerStore do
  subject(:answer_store) { described_class.new(store, form_id) }

  let(:store) { {} }
  let(:form_id) { 1 }
  let(:step) { OpenStruct.new({ id: "5" }) }
  let(:other_step) { OpenStruct.new({ id: "1" }) }
  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
  let(:requested_email_confirmation) { true }

  describe "answer store common methods" do
    let(:answer) { "test answer" }

    before do
      answer_store.save_step(step, answer)
    end

    it_behaves_like "an answer store"
  end

  it "stores the answer for a step" do
    answer_store.save_step(step, "test answer")
    result = answer_store.get_stored_answer(step)
    expect(result).to eq("test answer")
  end

  describe "#clear_stored_answer" do
    before do
      answer_store.save_step(step, "test answer")
    end

    it "clears a single answer for a step" do
      expect(answer_store.get_stored_answer(step)).to eq("test answer")
      answer_store.clear_stored_answer(step)
      expect(answer_store.get_stored_answer(step)).to be_nil
    end

    it "does not error if removing a step which doesn't exist in the store" do
      answer_store.clear_stored_answer(other_step)
      expect(answer_store.get_stored_answer(step)).to eq("test answer")
    end
  end

  describe "#clear" do
    let(:other_form_id) { 9 }

    before do
      answer_store.save_step(step, "test answer")
    end

    it "clears the session for a form" do
      answer_store.clear
      expect(answer_store.get_stored_answer(step)).to be_nil
    end

    it "doesn't change other forms" do
      other_form_answer_store = described_class.new(store, other_form_id)
      other_form_answer_store.save_step(other_step, "other form answer")

      answer_store.clear
      expect(other_form_answer_store.get_stored_answer(other_step)).to eq("other form answer")
    end

    it "clears the locales used" do
      answer_store.add_locale(:en)
      answer_store.add_locale(:cy)

      answer_store.clear

      expect(answer_store.locales_used).to eq([])
    end
  end

  describe "#get_stored_answer" do
    before do
      answer_store.save_step(step, "test answer")
      answer_store.save_step(other_step, "test2 answer")
    end

    it "returns the answer for the first step" do
      expect(answer_store.get_stored_answer(step)).to eq("test answer")
    end

    it "returns the answer for the second step" do
      expect(answer_store.get_stored_answer(other_step)).to eq("test2 answer")
    end
  end

  describe "#answers" do
    let(:form_answers) do
      {
        "1" => {
          selection: "Option 1",
        },
        "2" => {
          text: "Example text",
        },
      }
    end
    let(:store) do
      {
        answers: {
          form_id.to_s => form_answers,
          "2" => {
            "3" => {
              selection: "Option 2",
            },
          },
        },
      }
    end

    it "returns all answers for a form" do
      expect(answer_store.answers).to eq form_answers
    end
  end

  describe "#form_submitted?" do
    let(:store) { { answers: { form_id.to_s => nil } } }

    it "returns true when a form has been submitted and cleared" do
      expect(answer_store.form_submitted?).to be true
    end

    context "when form answers have not been submitted and cleared" do
      let(:store) { { answers: { form_id.to_s => "This is my answer to question 1" } } }

      it "returns true when a form has been submitted and cleared" do
        expect(answer_store.form_submitted?).to be false
      end
    end
  end

  describe "#locales_used" do
    context "when no locales have been added" do
      it "returns []" do
        expect(answer_store.locales_used).to eq([])
      end
    end

    context "when multiple locales exist in the store" do
      let(:store) do
        {
          locales: {
            form_id.to_s => %i[en cy],
          },
        }
      end

      it "returns the locales used" do
        expect(answer_store.locales_used).to eq(%i[en cy])
      end
    end
  end
end
