require "rails_helper"

RSpec.describe Api::V2::StepResource do
  it "has a valid factory" do
    step = build :v2_step
    expect(step).to be_valid
  end

  describe "#answer_settings" do
    it "returns an empty object for answer_settings when it's not present" do
      step = described_class.new(data: {})
      expect(step).to have_attributes(answer_settings: {})
    end

    it "returns an answer settings object for answer_settings when present" do
      step = described_class.new(data: { answer_settings: { only_one_option: "true" } })
      expect(step.answer_settings.attributes).to eq({ "only_one_option" => "true" })
    end
  end

  describe "#repeatable?" do
    it "returns false when attribute does not exist" do
      step = described_class.new({ data: {} })
      expect(step.repeatable?).to be false
    end

    it "returns false when attribute is false" do
      step = described_class.new(data: { is_repeatable: false })
      expect(step.repeatable?).to be false
    end

    it "returns true when attribute is true" do
      step = described_class.new(data: { is_repeatable: true })
      expect(step.repeatable?).to be true
    end
  end
end
