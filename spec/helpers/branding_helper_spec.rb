require "rails_helper"

RSpec.describe BrandingHelper, type: :helper do
  describe "#branding_asset_url" do
    it "prefixes the path with the forms-runner base URL" do
      expect(helper.branding_asset_url("/assets/brands/weatherfield/logo-abc123.png"))
        .to eq("#{Settings.forms_runner.base_url}/assets/brands/weatherfield/logo-abc123.png")
    end
  end
end
