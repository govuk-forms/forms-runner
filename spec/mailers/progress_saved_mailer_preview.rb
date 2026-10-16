class ProgressSavedMailerPreview < ActionMailer::Preview
  include FactoryBot::Syntax::Methods

  def progress_saved
    mail_for(form_document)
  end

  def with_welsh
    mail_for(form_document, welsh_form_document:, locale: "cy")
  end

  def preview_draft
    mail_for(form_document, mode: "preview-draft")
  end

  def without_support_contact_details
    mail_for(build(:form_document,
                   name: "English form",
                   support_phone: nil,
                   support_email: nil,
                   support_url: nil,
                   support_url_text: nil))
  end

private

  def mail_for(form_document, welsh_form_document: nil, locale: "en", mode: "form")
    incomplete_submission = IncompleteSubmission.new(user_id: "user-1", form_id: form_document.form_id, form_version: 1, mode:, locale:, updated_at: Time.zone.now)

    incomplete_submission.define_singleton_method(:form) { Form.new(form_document) }
    incomplete_submission.define_singleton_method(:welsh_form) { Form.new(welsh_form_document) }

    ProgressSavedMailer.progress_saved_email(incomplete_submission:, email_address: "foo@example.com")
  end

  def form_document
    build(:form_document,
          name: "English form",
          support_phone: "0203 222 2222\r\nLines are open 8am - 6pm Monday to Friday",
          support_email: "help@example.gov.uk",
          support_url: "https://example.gov.uk/help",
          support_url_text: "Get help")
  end

  def welsh_form_document
    build(:form_document,
          name: "Welsh form",
          support_phone: "0203 333 3333\r\nMae'r llinellau ar agor 8am - 6pm o ddydd Llun i ddydd Gwener",
          support_email: "help@example.gov.wales",
          support_url: "https://example.gov.wales/help",
          support_url_text: "Cael help")
  end
end
