require "rails_helper"

RSpec.describe StartNewFormInput do
  let(:input) { described_class.new(start_new_form: "yes") }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(input).to be_valid
    end

    it "is valid with each of the radio options offered" do
      described_class::OPTIONS.each do |value|
        input.start_new_form = value
        expect(input).to be_valid, "expected #{value} to be valid"
      end
    end

    it "is not valid without a start_new_form" do
      input.start_new_form = nil
      expect(input).not_to be_valid
      expect(input.errors[:start_new_form]).to include(I18n.t("activemodel.errors.models.start_new_form_input.attributes.start_new_form.blank"))
    end

    it "is not valid with an invalid start_new_form" do
      input.start_new_form = "invalid"
      expect(input).not_to be_valid
      expect(input.errors[:start_new_form]).to include(I18n.t("activemodel.errors.models.start_new_form_input.attributes.start_new_form.inclusion"))
    end
  end

  describe "#start_new_form?" do
    it 'returns true when start_new_form is "yes"' do
      expect(described_class.new(start_new_form: "yes").start_new_form?).to be true
    end

    it 'returns false when start_new_form is "no"' do
      expect(described_class.new(start_new_form: "no").start_new_form?).to be false
    end
  end
end
