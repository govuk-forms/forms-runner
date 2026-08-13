require "rails_helper"

RSpec.describe BrandingHelper, type: :helper do
  describe "#branding_asset_url" do
    it "prefixes the path with the forms-runner base URL" do
      expect(helper.branding_asset_url("/brand_assets/cheshire-east/logo.png"))
        .to eq("#{Settings.forms_runner.base_url}/brand_assets/cheshire-east/logo.png")
    end
  end
end
