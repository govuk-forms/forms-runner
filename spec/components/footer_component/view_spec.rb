require "rails_helper"

RSpec.describe FooterComponent::View, type: :component do
  include Rails.application.routes.url_helpers

  let(:form) { build :v2_form_document, id: 1 }
  let(:mode) { Mode.new }

  before do
    render_inline(described_class.new(mode: mode, form: form))
  end

  context "when the locale is en" do
    it "includes the accessibility statement link without a language query parameter" do
      expect(page).to have_link("Accessibility statement", href: accessibility_statement_path)
    end

    it "includes the cookies link without a language query parameter" do
      expect(page).to have_link("Cookies", href: cookies_path)
    end

    it "includes the licence link" do
      expect(page).to have_link(I18n.t("footer.licence_link_text"), href: I18n.t("footer.licence_link_url"))
    end
  end

  context "when the locale is cy" do
    around do |example|
      I18n.with_locale(:cy) do
        example.run
      end
    end

    it "includes the accessibility statement link with a language query parameter" do
      expect(page).to have_link(I18n.t("footer.accessibility_statement", locale: :cy), href: accessibility_statement_path(locale: "cy"))
    end

    it "includes the cookies link with a language query parameter" do
      expect(page).to have_link(I18n.t("footer.cookies", locale: :cy), href: cookies_path(locale: "cy"))
    end

    it "includes the licence link in Welsh" do
      expect(page).to have_link(I18n.t("footer.licence_link_text", locale: :cy), href: I18n.t("footer.licence_link_url", locale: :cy))
    end
  end

  context "when a form is present for the request" do
    it "includes the privacy link" do
      expect(page).to have_link("Privacy", href: form_privacy_path(mode:, form_id: form.id, form_slug: form.form_slug))
    end

    context "when the form has custom branding" do
      let(:form) { build :form, brand_id: "cheshire-east", id: 1 }

      it "includes a link to the branded accessbility statement" do
        expect(page).to have_link("Accessibility statement", href: form_branded_accessibility_statement_path(mode:, form_id: form.id, form_slug: form.form_slug))
      end
    end
  end

  context "when a form is not present for the request" do
    let(:form) { nil }

    it "does not include the privacy link" do
      expect(page).not_to have_link("Privacy")
    end
  end
end
