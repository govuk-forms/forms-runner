require "rails_helper"

RSpec.describe FormHeaderComponent::View, type: :component do
  let(:mode) { Mode.new }
  let(:form) { OpenStruct.new(id: 1, name: "test_form_name", form_slug: "test") }
  let(:current_context) { OpenStruct.new(form:) }
  let(:auth_service) { nil }

  it "has service name" do
    render_inline(described_class.new(current_context:, auth_service:, mode:))

    expect(page).to have_selector(
      "header .govuk-service-navigation .govuk-service-navigation__service-name",
      text: "test_form_name",
    )
  end

  it "links to the GOV.UK homepage" do
    render_inline(described_class.new(current_context:, auth_service:, mode:))

    expect(page.find("a.govuk-header__homepage-link")[:href]).to eq "https://www.gov.uk/"
  end

  it "links to the form start page" do
    render_inline(described_class.new(current_context:, auth_service:, mode:))

    expect(page).to have_link("test_form_name", href: "/form/1/test")
  end

  it "does not have a link to 'Your Questions' in admin" do
    allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
    render_inline(described_class.new(current_context:, auth_service:, mode:))

    expect(page).not_to have_link("Your questions")
    expect(page).not_to have_link(href: /^http:\/\/forms-admin/)
  end

  context "when mode is preview_draft" do
    let(:mode) { Mode.new("preview-draft") }

    it "has service name" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector(
        "header .govuk-service-navigation .govuk-service-navigation__service-name",
        text: "test_form_name",
      )
      expect(page).to have_selector(".app-header--preview-draft")
    end

    it "has a link to 'Add and edit your questions' in admin" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_link("Your questions", href: "#{Settings.forms_admin.base_url}/forms/1/pages/")
    end

    it "links to the forms-admin homepage" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin/")

      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page.find(".govuk-header__homepage-link")[:href]).to eq "http://forms-admin/"
    end
  end

  context "when mode is preview_archived" do
    let(:mode) { Mode.new("preview-archived") }

    it "has service name" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector(
        "header .govuk-service-navigation .govuk-service-navigation__service-name",
        text: "test_form_name",
      )
      expect(page).to have_selector(".app-header--preview-archived")
    end

    it "links to the forms-admin homepage" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin/")

      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page.find(".govuk-header__homepage-link")[:href]).to eq "http://forms-admin/"
    end
  end

  context "when mode is preview_live" do
    let(:mode) { Mode.new("preview-live") }

    it "has service name" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector(
        "header .govuk-service-navigation .govuk-service-navigation__service-name",
        text: "test_form_name",
      )
      expect(page).to have_selector(".app-header--preview-live")
    end

    it "has a link to 'Your Questions' in admin" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_link("Your questions")
      expect(page).to have_link(href: /^http:\/\/forms-admin/)
    end
  end

  context "when the environment is production" do
    before do
      allow(HostingEnvironment).to receive(:friendly_environment_name).and_return(I18n.t("environment_names.production"))
      render_inline(described_class.new(current_context:, auth_service:, mode:))
    end

    it "does not show an environment tag" do
      expect(page).not_to have_css(".govuk-tag", text: I18n.t("environment_names.production"))
    end
  end

  [
    { name: "Local", colour: "magenta" },
    { name: "Development", colour: "green" },
    { name: "User research", colour: "blue" },
    { name: "Staging", colour: "yellow" },
  ].each do |environment|
    context "when the environment is #{environment[:name]}" do
      before do
        allow(HostingEnvironment).to receive(:friendly_environment_name).and_return(environment[:name])
        render_inline(described_class.new(current_context:, auth_service:, mode:))
      end

      it "shows the environment tag" do
        expect(page).to have_css(".govuk-tag--#{environment[:colour]}", text: environment[:name])
      end
    end
  end

  context "when the form has custom branding configured" do
    let(:form) do
      OpenStruct.new(id: 1,
                     name: "test_form_name",
                     form_slug: "test",
                     has_custom_branding?: true,
                     branding: build(:brand))
    end

    it "has service name" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector(
        "header .govuk-service-navigation .govuk-service-navigation__service-name",
        text: "test_form_name",
      )
    end

    it "renders the brand logo with the organisation name as alt text" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page.find(".app-header__logo-link img")["src"]).to have_content "/assets/brands/weatherfield/logo-abc123.png"
      expect(page.find(".app-header__logo-link img")["alt"]).to have_content "Weatherfield Borough Council"
    end

    it "links to the brand homepage" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page.find("a.app-header__logo-link")[:href]).to eq "https://www.weatherfield.example.com"
    end
  end

  context "when the form filler is logged in" do
    let(:auth_service) do
      double(AuthService, logged_in?: true)
    end

    it "renders the one login service header" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector("header .cross-service-header .one-login-header")
      expect(page).not_to have_selector(".govuk-header")
    end

    it "has service name" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_selector(
        "header .govuk-service-navigation .govuk-service-navigation__service-name",
        text: "test_form_name",
      )
    end

    it "links to the GOV.UK homepage" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page.find("a.one-login-header__link--homepage")[:href]).to eq "https://www.gov.uk/"
    end

    it "links to the form start page" do
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).to have_link("test_form_name", href: "/form/1/test")
    end

    it "does not have a link to 'Your Questions' in admin" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
      render_inline(described_class.new(current_context:, auth_service:, mode:))

      expect(page).not_to have_link("Your questions")
      expect(page).not_to have_link(href: /^http:\/\/forms-admin/)
    end

    %w[
      preview-draft
      preview-archived
      preview-live
    ].each do |mode_string|
      context "when mode is #{mode_string}" do
        let(:mode) { Mode.new(mode_string) }

        it "links to the forms-admin homepage" do
          allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin/")

          render_inline(described_class.new(current_context:, auth_service:, mode:))

          expect(page.find(".one-login-header__link--homepage")[:href]).to eq "http://forms-admin/"
        end

        it "has a link to 'Your Questions' in admin" do
          allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
          render_inline(described_class.new(current_context:, auth_service:, mode:))

          expect(page).to have_link("Your questions")
          expect(page).to have_link(href: /^http:\/\/forms-admin/)
        end
      end
    end
  end

  context "if current_context is nil" do
    it "does not show service name" do
      render_inline(described_class.new(current_context: nil, auth_service:, mode:))
      expect(page).not_to have_selector(".govuk-header__service-name")
    end
  end
end
