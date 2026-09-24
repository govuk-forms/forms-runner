require "rails_helper"

RSpec.describe SupportDetailsComponent::View, type: :component do
  [
    ["only include phone", { email: nil, phone: "Call 01610123456\n\nThis line is only open on Tuesdays.", url: nil, url_text: nil }],
    ["only include email", { email: "help@example.gov.uk", phone: nil, url: nil, url_text: nil }],
    ["include the URL fields", { email: nil, phone: nil, url: "https://example.gov.uk/contact", url_text: "Contact form" }],
    ["include email and phone", { email: "help@example.gov.uk", phone: "Call 01610123456\n\nThis line is only open on Tuesdays.", url: nil, url_text: nil }],
    ["include email and URL fields", { email: "help@example.gov.uk", phone: nil, url: "https://example.gov.uk/contact", url_text: "Contact form" }],
    ["include phone and URL fields", { email: nil, phone: "Call 01610123456\n\nThis line is only open on Tuesdays.", url: "https://example.gov.uk/contact", url_text: "Contact form" }],
    ["include all fields", { email: "help@example.gov.uk", phone: "Call 01610123456\n\nThis line is only open on Tuesdays.", url: "https://example.gov.uk/contact", url_text: "Contact form" }],

  ].each do |variation, contact_details|
    context "with contact details set to #{variation}" do
      it "displays the contact details section" do
        render_inline(described_class.new(OpenStruct.new(contact_details)))

        expect(page).to have_content("Get help with this form")
      end
    end
  end

  context "without contact details set" do
    let(:contact_details) do
      {
        email: nil,
        phone: nil,
        url: nil,
        url_text: nil,
      }
    end

    it "does not display the contact details section" do
      render_inline(described_class.new(OpenStruct.new(contact_details)))

      expect(page).not_to have_content("Get help with this form")
    end
  end

  context "with phone contact details" do
    let(:contact_details) do
      {
        call_charges_url: "#call-charges",
        email: nil,
        phone: "Call 01610123456\n\nThis line is only open on Tuesdays.",
        url: nil,
        url_text: nil,
      }
    end

    it "includes a link to information about call charges that warns it opens in a new tab" do
      render_inline(described_class.new(OpenStruct.new(contact_details)))

      expect(page).to have_link "Find out about call charges (opens in new tab)", href: "#call-charges", exact_text: true, visible: :hidden
    end
  end
end
