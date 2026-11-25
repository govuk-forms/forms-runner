require "rails_helper"

RSpec.describe ContinueWithOneLoginInput do
  let(:input) { described_class.new(continue_with_this_one_login: "yes") }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(input).to be_valid
    end

    it "is valid with each of the radio options offered" do
      described_class::OPTIONS.each do |value|
        input.continue_with_this_one_login = value
        expect(input).to be_valid, "expected #{value} to be valid"
      end
    end

    it "is not valid without a continue_with_this_one_login" do
      input.continue_with_this_one_login = nil
      expect(input).not_to be_valid
      expect(input.errors[:continue_with_this_one_login]).to include(I18n.t("activemodel.errors.models.continue_with_one_login_input.attributes.continue_with_this_one_login.blank"))
    end

    it "is not valid with an invalid continue_with_this_one_login" do
      input.continue_with_this_one_login = "invalid"
      expect(input).not_to be_valid
      expect(input.errors[:continue_with_this_one_login]).to include(I18n.t("activemodel.errors.models.continue_with_one_login_input.attributes.continue_with_this_one_login.inclusion"))
    end
  end

  describe "#continue?" do
    it 'returns true when continue_with_this_one_login is "yes"' do
      expect(described_class.new(continue_with_this_one_login: "yes").continue?).to be true
    end

    it 'returns false when continue_with_this_one_login is "no"' do
      expect(described_class.new(continue_with_this_one_login: "no").continue?).to be false
    end
  end
end
