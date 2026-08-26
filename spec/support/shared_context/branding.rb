RSpec.shared_context "with branding" do
  let(:brand) { build :brand }

  before do
    allow(Brand).to receive(:find).and_return(nil)
    allow(Brand).to receive(:find).with("weatherfield").and_return(brand)
  end
end
