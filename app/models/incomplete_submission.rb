class IncompleteSubmission < ApplicationRecord
  encrypts :answers
  validates :user_id, presence: true
  validates :form_id, presence: true, uniqueness: { scope: :user_id }

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
