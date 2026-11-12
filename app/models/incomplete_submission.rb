class IncompleteSubmission < ApplicationRecord
  include HasUploadedFileKeys

  encrypts :answers
  validates :user_id, presence: true
  validates :form_id, presence: true, uniqueness: { scope: %i[user_id mode] }
  validates :mode, presence: true
  validates :submission_uuid, presence: true

  scope :for_email, ->(email) { where(email_hash: hash_email(email)) }

  def self.hash_email(email)
    OpenSSL::HMAC.hexdigest("SHA256", Settings.incomplete_submissions.email_hmac_key, email.to_s.strip.downcase)
  end

  def email=(email)
    self.email_hash = self.class.hash_email(email)
  end

  def mode_object
    Mode.new(mode)
  end

  def form
    @form ||= Form.new(form_document)
  end

  def welsh_form
    @welsh_form ||= Form.new(form_document(language: :cy))
  end

private

  def form_document(language: :en)
    if mode_object.preview_draft?
      Api::V3::FormDocumentRepository.find_draft(form_id: form_id, language: language)
    else
      Api::V3::FormDocumentRepository.find_by_version(form_id: form_id, version: form_version, language: language)
    end
  end
end
