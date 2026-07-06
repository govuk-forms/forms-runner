class AwsSesSubmissionBatchMailer < ApplicationMailer
  def daily_submission_batch_email(form:, date:, mode:, files:)
    @form_name = form.name
    @date = date.strftime("%-d %B %Y")
    @mode = mode
    @filenames = files.keys
    @subject = daily_batch_subject

    files.each do |name, file|
      attachments[name] = {
        encoding: "base64",
        content: Base64.encode64(file),
      }
    end

    mail(to: form.submission_email, subject: @subject)
  end

  def weekly_submission_batch_email(form:, begin_date:, end_date:, mode:, files:)
    @form_name = form.name
    @begin_date = begin_date.strftime("%-d %B %Y")
    @end_date = end_date.strftime("%-d %B %Y")
    @mode = mode
    @filenames = files.keys
    @subject = weekly_batch_subject

    files.each do |name, file|
      attachments[name] = {
        encoding: "base64",
        content: Base64.encode64(file),
      }
    end

    mail(to: form.submission_email, subject: @subject)
  end

private

  def daily_batch_subject
    if @mode.preview?
      I18n.t("mailer.submission_batch.daily.subject_preview", form_name: @form_name, date: @date)
    else
      I18n.t("mailer.submission_batch.daily.subject", form_name: @form_name, date: @date)
    end
  end

  def weekly_batch_subject
    if @mode.preview?
      I18n.t("mailer.submission_batch.weekly.subject_preview", form_name: @form_name, begin_date: @begin_date, end_date: @end_date)
    else
      I18n.t("mailer.submission_batch.weekly.subject", form_name: @form_name, begin_date: @begin_date, end_date: @end_date)
    end
  end
end
