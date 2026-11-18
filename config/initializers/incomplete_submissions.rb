if Settings.incomplete_submissions.email_hmac_key.blank?
  raise "You must configure a secret key for hashing email addresses using SETTINGS__INCOMPLETE_SUBMISSIONS__EMAIL_HMAC_KEY"
end
