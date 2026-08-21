RSpec.shared_context "with branding from branding.yml" do
  before do
    allow(Api::V2::BrandRepository).to receive(:find) { |brand_id| BRANDING_CONFIG[brand_id] }
  end
end
