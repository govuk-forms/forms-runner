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

  context "when the form has custom branding configured" do
    let(:logo_data_uri) { "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHgAAAAqCAMAAABP/G8cAAAAJFBMVEX+///v8u7W6d3o17m93r7Zz4Wfz6CRxduBvnzQfJlYq1kbjBtQ6hxcAAACsUlEQVR42u3U4W7jRgxF4XPvcCiKfP/37a4txEiwm3WA1imKfj8MYQTjiIQt/mXENwnxPdJ8jy2+hbr4DtrVwTfY++yD19tr+zz/rn+XQjxnLXb4NFxyfki+RBPcxQRP0SZqcR5cajKym69JfzW8Vsb+GRY3mgIQSiASZ3QH1SWUrk6q20B2JzhVSRpVd97D2V38QZV17vO0uZsxAB5BDzHTPdM1he7XUzNQUzVJzkxrkpnqsSfIqZz+Q3cD2qf82NVMB1e48QRMQw2ahB7wyGOouY+oCY9AeIK5vv57qi1AtbC5KGum38IxgknIkca3MzzK6e4ZcriFmemEGF97Mb+X1gKde2O/uzF+TGyYusLBIxw/mBzdw66ekceajB8+6wZroVOufZgbBVzPzbvwx4mvXT4mBpj0mAk+lQlanAuxD+48U1HTMJ09Tfx6YtNT0f0W9mTU2BPUVNSI34gE2OcC483Ffb0/YqaqcAsqIRq1r+e9Hc50EA3QpmYmcBvys1eQCoDzBMyxeZUMgHXuBTqOtXiJa2CdsIUOsYDXDXwuYEmCpReFdQ0MbAu+sms9f/qREt5ihw1s3nMXQCYPLkDVHXwU7mfKDoBlAFt7/WLkTiKdpUwpMlBW3c8dzsDGRCbKtD1PhQ3oPARY1hbaH8Phjlu4yxPtuoXd95sdmWpNtqsi0/18eF2XvlW3+DhxlzNdVS4qEheoARVRmZSazAbqybBu4XPBISTWYi/emZSzMzuj3HRU3BJdimhVZkWryei0y/N8+DxPfIBYe7H2xx+Xu8Lh7lSSju4E1N0RXeh+I+yfByqeDfNz4sPoHtbmH3eFETpA0tKCrReEzZ1v4b3XgvXSsG/htfWicPIIIy/xmjCpx6qR4WVhc3eArvCGV+4aZAGsxSuEeaPr83//AX8BngYVsMuf6BgAAAAASUVORK5CYII=" }
    let(:form) do
      OpenStruct.new(id: 1,
                     name: "test_form_name",
                     form_slug: "test",
                     has_custom_branding?: true,
                     branding: {
                       "background_colour" => "#ffffff",
                       "border_colour" => "#ff0000",
                       "organisation_name" => "Summerisle Island Council",
                       "organisation_url" => "https://www.summerisle.gov.uk",
                       "logo" => logo_data_uri,
                     })
    end

    it "renders the brand logo with the organisation name as alt text" do
      render_inline(described_class.new(current_context:, mode:))

      expect(page.find(".app-header__logo-link img")["src"]).to have_content logo_data_uri
      expect(page.find(".app-header__logo-link img")["alt"]).to have_content "Summerisle Island Council"
    end

    it "links to the brand homepage" do
      render_inline(described_class.new(current_context:, mode:))

      expect(page.find("a.app-header__logo-link")[:href]).to eq "https://www.summerisle.gov.uk"
    end
  end

  it "does not show if current_context is nil" do
    render_inline(described_class.new(current_context: nil, mode:))
    expect(page).not_to have_selector(".govuk-header__service-name")
  end
end
