require "rails_helper"

RSpec.describe Condition do
  subject(:condition) do
    described_class.new(form_document_condition:)
  end

  let(:form_document_condition) do
    build(
      :v2_condition,
      routing_page_id: "aaaaa",
      check_page_id: "bbbbb",
      goto_page_id: "eeeee",
      answer_value: "Option 1",
    )
  end

  describe "#initialize" do
    it "sets the attributes" do
      expect(condition).to have_attributes(
        goto_page_id: "eeeee",
        answer_value: "Option 1",
      )
    end
  end

  describe "#==" do
    context "when other condition was created from the same form document condition" do
      it "returns true" do
        other_condition = described_class.new(form_document_condition:)
        expect(condition == other_condition).to be true
      end
    end

    context "when other condition was created from a different form document condition" do
      it "returns false" do
        other_condition = described_class.new(form_document_condition: build(:v2_condition))
        expect(condition == other_condition).to be false
      end
    end
  end

  describe "#goto_page_id" do
    context "when goto_page_id is nil" do
      let(:form_document_condition) { build(:v2_condition, goto_page_id: nil) }

      it "returns nil" do
        expect(condition.goto_page_id).to be_nil
      end
    end
  end

  describe "#exit_page_id" do
    context "when form document does not have exit_page_id" do
      let(:form_document_condition) do
        condition = build(:v2_condition, exit_page_id: nil)
        condition.attributes.delete(:exit_page_id)
        condition
      end

      it "returns nil" do
        expect(condition.exit_page_id).to be_nil
      end
    end

    context "when exit_page_id is nil" do
      let(:form_document_condition) { build(:v2_condition, exit_page_id: nil) }

      it "returns nil" do
        expect(condition.exit_page_id).to be_nil
      end
    end
  end

  describe "#default?" do
    context "when condition.answer_value is nil" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          answer_value: nil,
        )
      end

      it "returns true" do
        expect(condition.default?).to be true
      end
    end

    context "when condition.answer_value is the empty string" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          answer_value: "",
        )
      end

      it "returns true" do
        expect(condition.default?).to be true
      end
    end

    context "when condition.answer_value is any other value" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          answer_value: "Option 1",
        )
      end

      it "returns false" do
        expect(condition.default?).to be false
      end
    end
  end

  describe "#match?" do
    context "when condition.answer_value is a string" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          answer_value: "Option 1",
        )
      end

      context "when given a string matching condition.answer_value" do
        it "returns true" do
          expect(condition.match?("Option 1")).to be true
        end
      end

      context "when given a string not matching condition.answer_value" do
        it "returns false" do
          expect(condition.match?("Option 2")).to be false
        end
      end

      context "when given the 'None of the above' answer" do
        it "returns false" do
          expect(condition.match?(Question::Selection::NONE_OF_THE_ABOVE_VALUE)).to be false
        end
      end
    end

    context "when condition.answer_value is the 'None of the above' answer" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          answer_value: "none_of_the_above",
        )
      end

      context "when given the 'None of the above' answer" do
        it "returns true" do
          expect(condition.match?(Question::Selection::NONE_OF_THE_ABOVE_VALUE)).to be true
        end
      end

      context "when given a string" do
        it "returns false" do
          expect(condition.match?("Option 1")).to be false
        end
      end
    end
  end

  describe "#exit_page?" do
    context "when condition has goto page id" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          goto_page_id: Faker::Alphanumeric.alphanumeric(number: 8),
        )
      end

      it "returns false" do
        expect(condition.exit_page?).to be false
      end

      context "and does not have exit_page_id attribute" do
        let(:form_document_condition) do
          condition = build(:v2_condition, goto_page_id: Faker::Alphanumeric.alphanumeric(number: 8))
          condition.attributes.delete(:exit_page_id)
          condition
        end

        it "returns false" do
          expect(condition.exit_page?).to be false
        end
      end

      context "and does not have exit page content attributes" do
        let(:form_document_condition) do
          condition = build(:v2_condition, goto_page_id: Faker::Alphanumeric.alphanumeric(number: 8))
          condition.attributes.delete(:exit_page_heading)
          condition.attributes.delete(:exit_page_markdown)
          condition
        end

        it "returns false" do
          expect(condition.exit_page?).to be false
        end
      end
    end

    context "when condition has exit_page_id" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          exit_page_id: 10,
        )
      end

      it "returns true" do
        expect(condition.exit_page?).to be true
      end

      context "and does not have exit page content attributes" do
        let(:form_document_condition) do
          condition = build(:v2_condition, exit_page_id: 10)
          condition.attributes.delete(:exit_page_heading)
          condition.attributes.delete(:exit_page_markdown)
          condition
        end

        it "returns true" do
          expect(condition.exit_page?).to be true
        end
      end
    end

    context "when condition has exit page content" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          exit_page_heading: Faker::Lorem.sentence,
          exit_page_markdown: Faker::Lorem.paragraph,
        )
      end

      it "returns true" do
        expect(condition.exit_page?).to be true
      end

      context "and does not have exit_page_id attribute" do
        let(:form_document_condition) do
          condition = build(:v2_condition, exit_page_heading: Faker::Lorem.sentence, exit_page_markdown: Faker::Lorem.paragraph)
          condition.attributes.delete(:exit_page_id)
          condition
        end

        it "returns true" do
          expect(condition.exit_page?).to be true
        end
      end
    end
  end

  describe "#skip_to_end?" do
    context "when condition has goto page id" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          goto_page_id: Faker::Alphanumeric.alphanumeric(number: 8),
        )
      end

      it "returns false" do
        expect(condition.skip_to_end?).to be false
      end
    end

    context "when condition.skip_to_end is true" do
      let(:form_document_condition) do
        build(
          :v2_condition,
          goto_page_id: nil,
          skip_to_end: true,
        )
      end

      it "returns true" do
        expect(condition.skip_to_end?).to be true
      end
    end
  end
end
