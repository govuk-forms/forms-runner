require "rails_helper"

RSpec.describe CustomBrandingComponent::View, type: :component do
  context "when no form is provided" do
    before do
      form = nil

      render_inline(described_class.new(form: form))
    end

    it "does not render" do
      expect(page).not_to have_css("style", visible: :all)
    end
  end

  context "when the form has no custom branding" do
    before do
      form = OpenStruct.new(id: 1,
                            name: "test_form_name",
                            form_slug: "test",
                            has_custom_branding?: false)

      render_inline(described_class.new(form: form))
    end

    it "does not render" do
      expect(page).not_to have_css("style", visible: :all)
    end
  end

  context "when the form has custom branding" do
    before do
      form = OpenStruct.new(id: 1,
                            name: "test_form_name",
                            form_slug: "test",
                            has_custom_branding?: true,
                            branding: {
                              "background_colour" => "white",
                              "border_colour" => "#206c49",
                              "organisation_name" => "Cheshire East Council",
                              "organisation_url" => "https://www.cheshireeast.gov.uk",
                              "logo" => "/brand_assets/cheshire-east/logo.png",
                            })

      render_inline(described_class.new(form: form))
    end

    it "renders a style component setting the branded CSS variables" do
      style_element = page.find("style", visible: :all)

      expect(style_element.native.inner_html).to include "--custom-background-colour: white;"
      expect(style_element.native.inner_html).to include "--custom-border-colour: #206c49;"
    end
  end
end
