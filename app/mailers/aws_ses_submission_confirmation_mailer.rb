class AwsSesSubmissionConfirmationMailer < ApplicationMailer
  def submission_confirmation_email(
    submission:,
    confirmation_email_address:,
    include_copy_of_answers:
  )
    @submission_locale = submission.submission_locale.to_sym
    @form = submission.form
    @welsh_form = submission.welsh_form
    @submission = submission
    @include_copy_of_answers = include_copy_of_answers

    mail(to: confirmation_email_address, subject: subject)
  end

  def subject
    subject = if @submission.preview?
                I18n.t("mailer.submission_confirmation.subject_preview", reference: @submission.reference)
              else
                I18n.t("mailer.submission_confirmation.subject", reference: @submission.reference)
              end

    if @submission_locale == :cy
      subject = "#{subject} | #{I18n.t('mailer.submission_confirmation.subject', reference: @submission.reference, locale: :cy)}"
    end

    subject
  end
end
