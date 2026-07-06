require "rails_helper"

RSpec.describe FormHeaderComponent::View, type: :component do
  let(:mode) { Mode.new }
  let(:form) { OpenStruct.new(id: 1, name: "test_form_name", form_slug: "test") }
  let(:current_context) { OpenStruct.new(form:) }

  it "has service name" do
    render_inline(described_class.new(current_context:, mode:))

    expect(page).to have_selector(".govuk-service-navigation .govuk-service-navigation__service-name")
    expect(page).to have_text("test_form_name")
  end

  it "links to the GOV.UK homepage" do
    render_inline(described_class.new(current_context:, mode:))

    expect(page.find("a.govuk-header__homepage-link")[:href]).to eq "https://www.gov.uk/"
  end

  it "links to the form start page" do
    render_inline(described_class.new(current_context:, mode:))

    expect(page).to have_link("test_form_name", href: "/form/1/test")
  end

  it "does not have a link to 'Your Questions' in admin" do
    allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
    render_inline(described_class.new(current_context:, mode:))

    expect(page).not_to have_link("Your questions")
    expect(page).not_to have_link(href: /^http:\/\/forms-admin/)
  end

  context "when mode is preview_draft" do
    let(:mode) { Mode.new("preview-draft") }

    it "has service name" do
      render_inline(described_class.new(current_context:, mode:))

      expect(page).to have_selector(".govuk-service-navigation .govuk-service-navigation__service-name")
      expect(page).to have_selector(".app-header--preview-draft")
      expect(page).to have_content("test_form_name")
    end

    it "has a link to 'Add and edit your questions' in admin" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
      render_inline(described_class.new(current_context:, mode:))

      expect(page).to have_link("Your questions", href: "#{Settings.forms_admin.base_url}/forms/1/pages/")
    end

    it "links to the forms-admin homepage" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin/")

      render_inline(described_class.new(current_context:, mode:))

      expect(page.find(".govuk-header__homepage-link")[:href]).to eq "http://forms-admin/"
    end
  end

  context "when mode is preview_archived" do
    let(:mode) { Mode.new("preview-archived") }

    it "has service name" do
      render_inline(described_class.new(current_context:, mode:))

      expect(page).to have_selector(".govuk-service-navigation .govuk-service-navigation__service-name")
      expect(page).to have_selector(".app-header--preview-archived")
      expect(page).to have_content("test_form_name")
    end

    it "links to the forms-admin homepage" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin/")

      render_inline(described_class.new(current_context:, mode:))

      expect(page.find(".govuk-header__homepage-link")[:href]).to eq "http://forms-admin/"
    end
  end

  context "when mode is preview_live" do
    let(:mode) { Mode.new("preview-live") }

    it "has service name" do
      render_inline(described_class.new(current_context:, mode:))

      expect(page).to have_selector(".govuk-service-navigation .govuk-service-navigation__service-name")
      expect(page).to have_selector(".app-header--preview-live")
      expect(page).to have_content("test_form_name")
    end

    it "has a link to 'Your Questions' in admin" do
      allow(Settings.forms_admin).to receive(:base_url).and_return("http://forms-admin")
      render_inline(described_class.new(current_context:, mode:))

      expect(page).to have_link("Your questions")
      expect(page).to have_link(href: /^http:\/\/forms-admin/)
    end
  end

  context "when the environment is production" do
    before do
      allow(HostingEnvironment).to receive(:friendly_environment_name).and_return(I18n.t("environment_names.production"))
      render_inline(described_class.new(current_context:, mode:))
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
        render_inline(described_class.new(current_context:, mode:))
      end

      it "shows the environment tag" do
        expect(page).to have_css(".govuk-tag--#{environment[:colour]}", text: environment[:name])
      end
    end
  end

  it "does not show if current_context is nil" do
    render_inline(described_class.new(current_context: nil, mode:))
    expect(page).not_to have_selector(".govuk-header__service-name")
  end
end
