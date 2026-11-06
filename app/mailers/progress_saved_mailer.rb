class ProgressSavedMailer < ApplicationMailer
  def progress_saved_email(
    incomplete_submission:,
    email_address:
  )
    @form = incomplete_submission.form
    @resume_form_link = resume_form_link(@form, incomplete_submission.mode)
    @deletion_date = incomplete_submission.updated_at + 30.days

    @locale = incomplete_submission.locale
    if @locale == "cy"
      @welsh_form = incomplete_submission.welsh_form
      @welsh_resume_form_link = resume_form_link(@welsh_form, incomplete_submission.mode, locale: "cy")
    end

    mail(
      to: email_address,
      subject: subject,
      delivery_method_options: {
        configuration_set_name: Settings.aws.ses_confirmation_email_configuration_set_name,
      },
    )
  end

  def resume_form_link(form, mode, locale: nil)
    path = Rails.application.routes.url_helpers.continue_saved_form_path(mode:, form_id: form.id, form_slug: form.form_slug, locale:)
    "#{Settings.forms_runner.base_url}#{path}"
  end

  def subject
    subject = I18n.t("mailer.progress_saved.subject", form_name: @form.name)

    if @locale == "cy"
      subject = "#{subject} | #{I18n.t('mailer.progress_saved.subject', form_name: @welsh_form.name, locale: :cy)}"
    end

    subject
  end
end
