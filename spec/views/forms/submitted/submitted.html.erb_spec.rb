require "rails_helper"

describe "forms/submitted/submitted.html.erb" do
  let(:form) { build :form, what_happens_next_markdown:, payment_url: }
  let(:what_happens_next_markdown) { nil }
  let(:requested_email_confirmation) { false }
  let(:payment_url) { nil }
  let(:reference) { Faker::Alphanumeric.alphanumeric(number: 8).upcase }

  before do
    assign(:mode, OpenStruct.new(preview_draft?: false, preview_archived?: false, preview_live?: false))

    assign(:current_context, OpenStruct.new(form:, get_submission_reference: reference, requested_email_confirmation?: requested_email_confirmation))

    render template: "forms/submitted/submitted", locals: { requested_email_confirmation: }
  end

  it "contains a green govuk panel with success message" do
    expect(rendered).to have_css("h1.govuk-panel__title", text: "Your form has been submitted")
  end

  it "displays the submission reference" do
    expect(rendered).to have_text(I18n.t("form.submitted.your_reference"))
    expect(rendered).to have_text(reference)
  end

  context "when there is a payment url for the form" do
    let(:payment_url) { "https://www.gov.uk/payments/organisation/service" }

    it "displays the need to pay panel" do
      expect(rendered).to have_css(".app-panel--payment-required", text: I18n.t("form.submitted.need_to_pay"))
    end

    it "displays the payment button" do
      expect(rendered).to have_button(I18n.t("form.submitted.continue_to_pay"))
    end
  end

  context "when the form has extra information about what happens next" do
    let(:what_happens_next_markdown) { "See what the day brings" }

    it "displays what happens next heading" do
      expect(rendered).to have_css("h2", text: I18n.t("form.submitted.what_happens_next"))
    end

    it "displays tells the user what happens next" do
      expect(rendered).to have_css("p", text: "See what the day brings")
    end
  end

  context "when the user has opted out of the confirmation email" do
    it "displays the email confirmation message" do
      expect(rendered).not_to have_css("p", text: I18n.t("form.submitted.email_sent"))
    end
  end

  context "when the user has opted into the confirmation email" do
    let(:requested_email_confirmation) { true }

    it "displays the email confirmation message" do
      expect(rendered).to have_css("p", text: I18n.t("form.submitted.email_sent"))
    end
  end
end
