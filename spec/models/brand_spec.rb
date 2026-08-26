require "rails_helper"

RSpec.describe Brand, type: :model do
  let(:req_headers) { { "Accept" => "application/json" } }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
  end

  describe ".find" do
    context "when the brand ID is blank" do
      before do
        ActiveResource::HttpMock.respond_to({})
      end

      it "returns nil without calling the API" do
        expect(described_class.find(nil)).to be_nil
        expect(described_class.find("")).to be_nil
        expect(ActiveResource::HttpMock.requests).to be_empty
      end
    end

    context "when the API has the brand" do
      let(:brand_resource) { build :v2_brand }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/brands/weatherfield", req_headers, brand_resource.to_json, 200
        end
      end

      it "returns a brand with the attributes from the API" do
        expect(described_class.find("weatherfield")).to have_attributes(
          background_colour: "#ffffff",
          border_colour: "#00703c",
          organisation_name: "Weatherfield Borough Council",
          organisation_url: "https://www.weatherfield.example.com",
          copyright_holder: "Weatherfield Borough Council",
          logo: "/assets/brands/weatherfield/logo-abc123.png",
          favicon: "/assets/brands/weatherfield/favicon-abc123.ico",
          opengraph: "/assets/brands/weatherfield/opengraph-image-abc123.jpg",
        )
      end

      it "caches the response so repeated calls make a single API request" do
        2.times { described_class.find("weatherfield") }

        expect(ActiveResource::HttpMock.requests.count).to eq 1
      end

      it "caches the branding attributes as a plain hash" do
        described_class.find("weatherfield")

        expect(cache.read("api/v2/brand/weatherfield")).to be_a Hash
      end

      it "returns a brand when served from the cache" do
        described_class.find("weatherfield")

        expect(described_class.find("weatherfield")).to be_a described_class
      end

      context "when the brand has no assets uploaded" do
        let(:brand_resource) { build :v2_brand, :without_assets }

        it "returns nil asset paths" do
          expect(described_class.find("weatherfield")).to have_attributes(
            logo: nil,
            favicon: nil,
            opengraph: nil,
          )
        end
      end
    end

    context "when the API does not have the brand" do
      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/brands/midsomer", req_headers, nil, 404
        end
      end

      it "returns nil" do
        expect(described_class.find("midsomer")).to be_nil
      end

      it "caches the not found response so repeated calls make a single API request" do
        2.times { described_class.find("midsomer") }

        expect(ActiveResource::HttpMock.requests.count).to eq 1
      end
    end

    context "when the API returns a server error" do
      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v2/brands/midsomer", req_headers, nil, 500
        end
      end

      it "logs a warning and returns nil" do
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch brand from the API/, { brand_id: "midsomer" })

        expect(described_class.find("midsomer")).to be_nil
      end

      it "does not cache the error, so the next call tries the API again" do
        allow(Rails.logger).to receive(:warn)

        2.times { described_class.find("midsomer") }

        expect(ActiveResource::HttpMock.requests.count).to eq 2
      end
    end

    context "when the API cannot be reached" do
      before do
        allow(Api::V2::BrandResource).to receive(:find).and_raise(ActiveResource::TimeoutError.new("execution expired"))
      end

      it "logs a warning and returns nil" do
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch brand from the API/, { brand_id: "midsomer" })

        expect(described_class.find("midsomer")).to be_nil
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
