require "rails_helper"

RSpec.describe UrlPatterns do
  describe UrlPatterns::PAGE_ID_REGEX do
    it "matches valid form_document_step_id values" do
      %w[1 123 0123456789 08suZ3aP].each do |string|
        expect(described_class).to match string
      end
    end

    it "does not match invalid form_document_step_id values" do
      %w[no%20ten toolongforanid0 check_your_answers /secret/login.php].each do |string|
        expect(described_class).not_to match string
      end
    end
  end
end
