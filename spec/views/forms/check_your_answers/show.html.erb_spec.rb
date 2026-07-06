require "rails_helper"

describe "forms/check_your_answers/show.html.erb" do
  let(:form) { build :form, :with_support, declaration_text:, declaration_markdown: }
  let(:support_details) { OpenStruct.new(email: form.support_email) }
  let(:context) { OpenStruct.new(form:) }
  let(:full_width) { false }
  let(:declaration_text) { nil }
  let(:declaration_markdown) { nil }
  let(:email_confirmation_input) { build :email_confirmation_input }
  let(:copy_of_answers_enabled) { false }
  let(:will_send_copy_of_answers) { false }
  let(:question) { build :text, question_text: "Do you want to remain anonymous?", text: "Yes" }
  let(:steps) { [build(:step, question:, form_document_step: build(:v2_question_step, :with_text_settings))] }

  before do
    assign(:current_context, context)
    assign(:mode, Mode.new("form"))
    assign(:form_submit_path, "/")
    assign(:full_width, full_width)
    assign(:steps, steps)
    assign(:form, form)
    assign(:support_details, support_details)
    render template: "forms/check_your_answers/show", locals: { email_confirmation_input:, copy_of_answers_enabled:, will_send_copy_of_answers: }
  end

  context "when the form does not have a declaration" do
    let(:declaration_text) { nil }

    it "does not display the declaration heading" do
      expect(rendered).not_to have_css("h2", text: "Declaration")
    end
  end

  context "when the form has a declaration" do
    let(:declaration_text) { "You should agree to all terms before submitting" }

    it "displays the declaration heading" do
      expect(rendered).to have_css("h2", text: "Declaration")
    end

    it "displays declaration text" do
      expect(rendered).to have_css("p", text: form.declaration_text)
    end
  end

  context "when the form has a markdown declaration and declaration text" do
    let(:declaration_text) { "You should agree to all terms before submitting" }
    let(:declaration_markdown) { "This is the markdown decalaration\n\nsecond paragraph" }

    it "displays the declaration heading" do
      expect(rendered).to have_css("h2", text: "Declaration")
    end

    it "displays declaration markdown" do
      expect(rendered).to have_css("p", text: "second paragraph")
    end

    it "does not display declaration text" do
      expect(rendered).not_to have_css("p", text: form.declaration_text)
    end
  end

  context "when the form has a markdown declaration only" do
    let(:declaration_markdown) { "This is the markdown decalaration\n\nsecond paragraph" }

    it "displays the declaration heading" do
      expect(rendered).to have_css("h2", text: "Declaration")
    end

    it "displays declaration markdown" do
      expect(rendered).to have_css("p", text: "second paragraph")
    end
  end

  it "displays the summary list two-thirds width" do
    expect(rendered).not_to have_css(".govuk-grid-column-full .govuk-summary-list")
    expect(rendered).to have_css(".govuk-grid-column-two-thirds-from-desktop .govuk-summary-list")
  end

  it "displays the title at two-thirds width" do
    expect(rendered).not_to have_css(".govuk-grid-column-full h1")
    expect(rendered).to have_css(".govuk-grid-column-two-thirds-from-desktop h1")
  end

  it "displays the email confirmation form at two-thirds width" do
    expect(rendered).not_to have_css(".govuk-grid-column-full input[type='radio']")
    expect(rendered).to have_css(".govuk-grid-column-two-thirds-from-desktop input[type='radio']")
  end

  it "contains a hidden notify reference for the confirmation email" do
    expect(rendered).to have_field("confirmation-email-reference", type: "hidden", with: email_confirmation_input.confirmation_email_reference)
  end

  it "displays the help link" do
    expect(rendered).to have_text(I18n.t("support_details.get_help_with_this_form"))
  end

  describe "will_send_copy_of_answers" do
    context "when false" do
      let(:copy_of_answers_enabled) { true }

      it "shows the no copy of answers heading" do
        expect(rendered).to have_css("h2", text: I18n.t("form.check_your_answers.no_copy_of_answers"))
      end

      it "shows a summary row indicating no copy was requested" do
        expect(rendered).to have_css(".govuk-summary-list__key", text: I18n.t("form.check_your_answers.copy_of_answers"))
        expect(rendered).to have_css(".govuk-summary-list__value", text: I18n.t("form.check_your_answers.no"))
      end

      it "shows a Change link in the summary row" do
        expect(rendered).to have_link(I18n.t("form.check_your_answers.change"))
      end
    end

    context "when false and copy of answers is not enabled on the form" do
      it "does not show the no copy of answers section" do
        expect(rendered).not_to have_css("h2", text: I18n.t("form.check_your_answers.no_copy_of_answers"))
      end
    end

    context "when true" do
      let(:will_send_copy_of_answers) { true }
      let(:context) { OpenStruct.new(form:, get_copy_of_answers_email_address: "user@example.gov.uk") }

      it "shows the copy of answers email message" do
        expect(rendered).to have_text("user@example.gov.uk")
      end

      it "does not show the no copy of answers section" do
        expect(rendered).not_to have_css("h2", text: I18n.t("form.check_your_answers.no_copy_of_answers"))
      end

      it "does not show the email confirmation radio buttons" do
        expect(rendered).not_to have_css("input[type='radio'][value='send_email']")
      end
    end
  end

  describe "email confirmation" do
    it "renders an email confirmation form" do
      expect(rendered).to have_css "form .govuk-fieldset", text: "Do you want to get an email confirming your form has been submitted?"
    end

    it "displays the email radio buttons" do
      expect(rendered).to have_text(I18n.t("helpers.legend.email_confirmation_input.send_confirmation"))
      expect(rendered).to have_field(I18n.t("helpers.label.email_confirmation_input.send_confirmation_options.send_email"))
      expect(rendered).to have_field(I18n.t("helpers.label.email_confirmation_input.send_confirmation_options.skip_confirmation"))
    end

    it "displays the email field" do
      expect(rendered).to have_field(
        I18n.t("helpers.label.email_confirmation_input.confirmation_email_address"),
        type: "email",
      )
    end

    it "email field has correct atttributes set" do
      expect(rendered).to have_selector("input[name='email_confirmation_input[confirmation_email_address]'][autocomplete='email'][spellcheck='false']")
    end

    context "when there is an error" do
      let(:email_confirmation_input) do
        email_confirmation_input = build(:email_confirmation_input)
        email_confirmation_input.validate
        email_confirmation_input
      end

      it "renders an error message" do
        expect(rendered).to have_text "Select ‘Yes’ if you want to get an email confirming your form has been submitted"
      end

      it "renders an error summary" do
        expect(rendered).to have_css ".govuk-error-summary"
      end

      it "links from the error summary to the first radio button" do
        form_document_step = Capybara.string(rendered.html)
        error_summary_link = form_document_step.find_link "Select ‘Yes’ if you want to get an email confirming your form has been submitted"
        first_radio_button = form_document_step.first :field, type: :radio

        expect(error_summary_link["href"]).to eq "##{first_radio_button['id']}"
      end
    end
  end
end
