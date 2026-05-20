class FormSubmissionConfirmationMailer < GovukNotifyRails::Mailer
  include NotifyUtils

  def send_confirmation_email(form:, welsh_form:, submission:, notify_response_id:, confirmation_email_address:)
    @submission_locale = submission.submission_locale.to_sym
    set_template(template_id)

    what_happens_next_text = form.what_happens_next_markdown.presence || default_what_happens_next_text
    set_personalisation(
      title: form.name,
      title_cy: welsh_form&.name || form.name,
      what_happens_next_text:,
      what_happens_next_text_cy: welsh_form&.what_happens_next_markdown.presence || what_happens_next_text,
      support_contact_details: format_support_details(form.support_details).presence || default_support_contact_details_text,
      support_contact_details_cy: welsh_support_details(form, welsh_form),
      submission_time: submission.submission_time.strftime("%l:%M%P").strip,
      submission_date: I18n.l(submission.submission_time, format: "%-d %B %Y", locale: :en),
      submission_date_cy: I18n.l(submission.submission_time, format: "%-d %B %Y", locale: :cy),
      test: make_notify_boolean(submission.preview?),
      submission_reference: submission.reference,
      include_payment_link: make_notify_boolean(submission.payment_url.present?),
      payment_link: form.payment_url_with_reference(submission.reference) || "",
      payment_link_cy: welsh_form&.payment_url_with_reference(submission.reference) || "",
    )

    set_reference(notify_response_id)

    set_email_reply_to(Settings.govuk_notify.form_submission_email_reply_to_id)

    mail(to: confirmation_email_address)
  end

  def format_support_details(support_details, locale: :en)
    phone = support_details&.phone
    call_charges_url = support_details&.call_charges_url
    email = support_details&.email
    url = support_details&.url
    url_text = support_details&.url_text

    support_details = []
    support_details << normalize_whitespace(phone) if phone.present?
    support_details << "[#{I18n.t('support_details.call_charges', locale: locale)}](#{call_charges_url})" if phone.present?
    support_details << "[#{email}](mailto:#{email})" if email.present?
    support_details << "[#{url_text}](#{url})" if url.present? && url_text.present?

    support_details.compact_blank.join("\n\n")
  end

private

  def welsh_support_details(form, welsh_form)
    format_support_details(welsh_form&.support_details, locale: :cy).presence ||
      format_support_details(form.support_details, locale: :cy).presence ||
      default_support_contact_details_text
  end

  def default_what_happens_next_text
    I18n.t("mailer.submission_confirmation.default_what_happens_next")
  end

  def default_support_contact_details_text
    I18n.t("mailer.submission_confirmation.default_support_contact_details")
  end

  def template_id
    return Settings.govuk_notify.form_filler_confirmation_email_welsh_template_id if @submission_locale == :cy

    Settings.govuk_notify.form_filler_confirmation_email_template_id
  end

  def normalize_whitespace(text)
    text.strip.gsub(/\r\n?/, "\n").split(/\n\n+/).map(&:strip).join("\n\n")
  end
end
