require "rails_helper"

RSpec.describe Api::V2::BrandResource do
  let(:req_headers) { { "Accept" => "application/json" } }
  let(:brand) { build :brand }
  let(:brand_id) { "weatherfield" }

  describe ".find" do
    before do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.get "/api/v2/brands/#{brand_id}", req_headers, brand.to_json, 200
      end
    end

    it "finds a brand for a given brand ID" do
      brand = described_class.find(brand_id)
      expect(brand).to be_a(described_class)
    end

    it "returns the brand attributes" do
      brand = described_class.find(brand_id)
      expect(brand).to have_attributes(
        name: "Weatherfield Borough Council",
        header_background_colour: "#ffffff",
        border_colour: "#00703c",
        logo_link: "https://www.weatherfield.example.com",
        copyright_holder: "Weatherfield Borough Council",
        logo_path: "/assets/brands/weatherfield/logo-abc123.png",
        favicon_path: "/assets/brands/weatherfield/favicon-abc123.ico",
        opengraph_image_path: "/assets/brands/weatherfield/opengraph-image-abc123.jpg",
      )
    end
  end
end
