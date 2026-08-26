RSpec.shared_context "with branding from branding.yml" do
  before do
    allow(Brand).to receive(:find) { |brand_id| Brand.from_attributes(BRANDING_CONFIG[brand_id]) if BRANDING_CONFIG[brand_id] }
  end
end
