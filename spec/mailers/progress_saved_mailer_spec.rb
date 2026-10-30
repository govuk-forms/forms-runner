require "rails_helper"

RSpec.describe ProgressSavedMailer, type: :mailer do
  subject(:mail) do
    described_class.progress_saved_email(
      incomplete_submission:,
      email_address:,
    )
  end

  let(:email_address) { "testing@example.gov.uk" }
  let(:locale) { "en" }
  let(:incomplete_submission) do
    IncompleteSubmission.new(
      user_id: "user-1",
      form_id: form_document.form_id,
      form_version: 3,
      mode: "form",
      locale:,
      updated_at: Time.zone.local(2026, 10, 12, 12, 0, 0),
    )
  end
  let(:resume_form_link) { "#{Settings.forms_runner.base_url}/form/#{form_document.form_id}/my-form/continue-saved-form" }
  let(:form_document) do
    build(:form_document,
          name: "My form",
          support_phone: "0203 222 2222",
          support_email: "help@example.gov.uk",
          support_url: "https://example.gov.uk/help",
          support_url_text: "Get help")
  end

  before do
    allow(Api::V3::FormDocumentRepository).to receive(:find_by_version)
      .with(form_id: incomplete_submission.form_id, version: 3, language: :en)
      .and_return(form_document)
  end

  it "sends to the requested address" do
    expect(mail.to).to eq([email_address])
  end

  it "has the expected subject" do
    expect(mail.subject).to eq(I18n.t("mailer.progress_saved.subject", form_name: "My form"))
  end

  describe "the text part" do
    let(:part) { mail.text_part }

    it "includes the form name" do
      expect(part.body).to include("My form")
    end

    it "includes the link to continue filling in the form" do
      expect(part.body).to include(resume_form_link)
    end

    it "includes the sign in message" do
      expect(part.body).to include(I18n.t("mailer.progress_saved.you_need_to_sign_in"))
    end

    it "includes the date the saved form will be deleted" do
      expect(part.body).to include("11 November 2026")
    end

    it "includes support contact details" do
      expect(part.body).to include(I18n.t("mailer.submission_confirmation.contact_details_heading"))
      expect(part.body).to include("0203 222 2222")
      expect(part.body).to include("help@example.gov.uk")
      expect(part.body).to include("Get help: https://example.gov.uk/help")
    end
  end

  describe "the html part" do
    let(:part) { mail.html_part }

    it "includes the link to continue filling in the form" do
      expect(part.body).to have_link(resume_form_link, href: resume_form_link)
    end

    it "includes the date the saved form will be deleted" do
      expect(part.body).to have_text("11 November 2026")
    end

    it "includes support contact details" do
      expect(part.body).to have_css("h2", text: I18n.t("mailer.submission_confirmation.contact_details_heading"))
      expect(part.body).to have_text("0203 222 2222")
      expect(part.body).to have_link("help@example.gov.uk", href: "mailto:help@example.gov.uk")
      expect(part.body).to have_link("Get help", href: "https://example.gov.uk/help")
    end
  end

  context "when the incomplete submission is for a draft preview" do
    let(:preview_draft_resume_form_link) { "#{Settings.forms_runner.base_url}/preview-draft/#{form_document.form_id}/my-form/continue-saved-form" }

    before do
      incomplete_submission.mode = "preview-draft"

      allow(Api::V3::FormDocumentRepository).to receive(:find_draft)
        .with(form_id: incomplete_submission.form_id, language: :en)
        .and_return(form_document)
    end

    it "fetches the draft form document" do
      mail.deliver_now

      expect(Api::V3::FormDocumentRepository).to have_received(:find_draft)
        .with(form_id: incomplete_submission.form_id, language: :en)
    end

    it "links to the draft preview in the text part" do
      expect(mail.text_part.body).to include(preview_draft_resume_form_link)
    end

    it "links to the draft preview in the html part" do
      expect(mail.html_part.body).to have_link(preview_draft_resume_form_link, href: preview_draft_resume_form_link)
    end
  end

  context "when the support details are not set" do
    let(:form_document) do
      build(:form_document,
            name: "My form",
            support_phone: nil,
            support_email: nil,
            support_url: nil,
            support_url_text: nil)
    end

    it "renders the default support contact details text for the text part" do
      expect(mail.text_part.body).to include(I18n.t("mailer.submission_confirmation.default_support_contact_details"))
    end

    it "renders the default support contact details html" do
      expect(mail.html_part.body).to have_text(I18n.t("mailer.submission_confirmation.default_support_contact_details"))
    end
  end

  context "when the saved answers are in Welsh" do
    let(:locale) { "cy" }
    let(:welsh_resume_form_link) { "#{Settings.forms_runner.base_url}/form/#{form_document.form_id}/welsh-form.cy/continue-saved-form" }
    let(:welsh_form_document) do
      build(:form_document,
            form_id: form_document.form_id,
            name: "Welsh form",
            support_phone: "0203 333 3333",
            support_email: "help@example.gov.wales",
            support_url: "https://example.gov.wales/help",
            support_url_text: "Cael help")
    end

    before do
      allow(Api::V3::FormDocumentRepository).to receive(:find_by_version)
        .with(form_id: incomplete_submission.form_id, version: 3, language: :cy)
        .and_return(welsh_form_document)
    end

    it "has a subject with the English and Welsh versions" do
      english_subject = I18n.t("mailer.progress_saved.subject", form_name: "My form")
      welsh_subject = I18n.t("mailer.progress_saved.subject", form_name: "Welsh form", locale: :cy)

      expect(mail.subject).to eq("#{english_subject} | #{welsh_subject}")
    end

    describe "the text part" do
      let(:part) { mail.text_part }

      it "includes the English content" do
        expect(part.body).to include("My form")
        expect(part.body).to include("0203 222 2222")
        expect(part.body).to include("help@example.gov.uk")
      end

      it "includes the English continue link without a locale and the Welsh one with the cy locale" do
        expect(part.body).to include(resume_form_link)
        expect(part.body).to include(welsh_resume_form_link)
      end

      it "includes the Welsh content after the English content" do
        expect(part.body).to include("Welsh form")
        expect(part.body).to include("0203 333 3333")
        expect(part.body).to include("help@example.gov.wales")
        expect(part.body.to_s.index("Welsh form")).to be > part.body.to_s.index("My form")
      end
    end

    describe "the html part" do
      let(:part) { mail.html_part }

      it "includes the English content" do
        expect(part.body).to have_text("My form")
        expect(part.body).to have_link("help@example.gov.uk", href: "mailto:help@example.gov.uk")
      end

      it "links to the English form without a locale and the Welsh form with the cy locale" do
        expect(part.body).to have_link(resume_form_link, href: resume_form_link)
        expect(part.body).to have_link(welsh_resume_form_link, href: welsh_resume_form_link)
      end

      it "includes the Welsh content" do
        expect(part.body).to have_text("Welsh form")
        expect(part.body).to have_text("0203 333 3333")
        expect(part.body).to have_link("help@example.gov.wales", href: "mailto:help@example.gov.wales")
        expect(part.body).to have_link("Cael help", href: "https://example.gov.wales/help")
      end

      it "separates the English and Welsh content" do
        expect(part.body).to have_css("hr")
      end
    end
  end
end
