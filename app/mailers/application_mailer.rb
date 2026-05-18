class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  default from: I18n.t("mailer.submission.from", email_address: Settings.ses_submission_email.from_email_address),
          reply_to: Settings.ses_submission_email.reply_to_email_address
end
