require "rails_helper"

RSpec.describe CopyOfAnswersInput do
  let(:input) { described_class.new(copy_of_answers: "yes") }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(input).to be_valid
    end

    it "is not valid without a copy_of_answers" do
      input.copy_of_answers = nil
      expect(input).not_to be_valid
      expect(input.errors[:copy_of_answers]).to include(I18n.t("activemodel.errors.models.copy_of_answers_input.attributes.copy_of_answers.blank"))
    end

    it "is not valid with an invalid copy_of_answers" do
      input.copy_of_answers = "invalid"
      expect(input).not_to be_valid
      expect(input.errors[:copy_of_answers]).to include("is not included in the list")
    end

    it 'is valid with "no" as copy_of_answers' do
      input.copy_of_answers = "no"
      expect(input).to be_valid
    end
  end

  describe "#wants_copy?" do
    it 'returns true when copy_of_answers is "yes"' do
      input = described_class.new(copy_of_answers: "yes")
      expect(input.wants_copy?).to be true
    end

    it 'returns false when copy_of_answers is "no"' do
      input = described_class.new(copy_of_answers: "no")
      expect(input.wants_copy?).to be false
    end
  end

  describe "#values" do
    it "returns an array of valid values" do
      input = described_class.new
      expect(input.values).to eq(%i[yes no])
    end
  end

  describe "RADIO_OPTIONS" do
    it "has the correct values" do
      expect(described_class::RADIO_OPTIONS).to eq({ yes: "yes", no: "no" })
    end

    it "is frozen" do
      expect(described_class::RADIO_OPTIONS).to be_frozen
    end
  end
end
