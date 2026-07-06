class AwsSesFormSubmissionMailer < ApplicationMailer
  def submission_email(submission:, files:, csv_filename: nil, json_filename: nil)
    @submission = submission
    @subject = email_subject
    @csv_filename = csv_filename
    @json_filename = json_filename
    @welsh_submission = submission.submission_locale.to_sym == :cy

    files.each do |name, file|
      attachments[name] = {
        encoding: "base64",
        content: Base64.encode64(file),
      }
    end

    mail(to: submission.form.submission_email, subject: @subject)
  end

private

  def email_subject
    return I18n.t("mailer.submission.subject_preview", form_name: @submission.form.name, reference: @submission.reference) if @submission.preview?

    I18n.t("mailer.submission.subject", form_name: @submission.form.name, reference: @submission.reference)
  end
end
