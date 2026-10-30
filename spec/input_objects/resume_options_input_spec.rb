require "rails_helper"

RSpec.describe ResumeOptionsInput do
  let(:input) { described_class.new(resume_options: "continue_saved") }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(input).to be_valid
    end

    it "is valid with each of the radio options offered" do
      input.values.map(&:to_s).each do |value|
        input.resume_options = value
        expect(input).to be_valid, "expected #{value} to be valid"
      end
    end

    it "is not valid without a resume_options" do
      input.resume_options = nil
      expect(input).not_to be_valid
      expect(input.errors[:resume_options]).to include(I18n.t("activemodel.errors.models.resume_options_input.attributes.resume_options.blank"))
    end

    it "is not valid with an invalid resume_options" do
      input.resume_options = "invalid"
      expect(input).not_to be_valid
      expect(input.errors[:resume_options]).to include("is not included in the list")
    end
  end

  describe "#continue_saved?" do
    it 'returns true when resume_options is "continue_saved"' do
      expect(described_class.new(resume_options: "continue_saved").continue_saved?).to be true
    end

    it 'returns false when resume_options is "start_new"' do
      expect(described_class.new(resume_options: "start_new").continue_saved?).to be false
    end
  end

  describe "#values" do
    it "returns the radio options" do
      expect(described_class.new.values).to eq(%i[start_new continue_saved])
    end
  end
end
