require "rails_helper"

RSpec.describe Brand, type: :model do
  describe ".find" do
    context "when the brand ID is blank" do
      it "returns nil" do
        expect(described_class.find(nil)).to be_nil
        expect(described_class.find("")).to be_nil
      end
    end

    context "when the brand ID is not known" do
      it "returns nil" do
        expect(described_class.find("midsomer")).to be_nil
      end
    end

    context "when the brand ID is in branding.yml" do
      it "returns a brand with the attributes of the branding.yml entry" do
        brand = described_class.find("cheshire-east")

        expect(brand).to be_a(described_class)
        expect(brand).to have_attributes(**BRANDING_CONFIG["cheshire-east"].symbolize_keys)
      end

      it "returns nil for attributes the branding.yml entry does not have" do
        expect(described_class.find("south-gloucestershire")).to have_attributes(opengraph: nil)
      end
    end
  end

  describe ".from_attributes" do
    it "builds a brand from a string-keyed hash" do
      brand = described_class.from_attributes(
        "background_colour" => "#ffffff",
        "organisation_name" => "Weatherfield Borough Council",
      )

      expect(brand).to have_attributes(
        background_colour: "#ffffff",
        organisation_name: "Weatherfield Borough Council",
        logo: nil,
      )
    end

    it "ignores unknown keys" do
      expect(described_class.from_attributes("unknown" => "value")).to be_a(described_class)
    end
  end
end
