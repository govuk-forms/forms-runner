class Form
  private attr_reader :form_document

  def initialize(form_document)
    @form_document = form_document
  end

  delegate :declaration_text,
           :form_id,
           :form_slug,
           :name,
           :payment_url,
           :privacy_policy_url,
           :s3_bucket_aws_account_id,
           :s3_bucket_name,
           :s3_bucket_region,
           :start_page,
           :send_daily_submission_batch,
           :send_weekly_submission_batch,
           :submission_email,
           :support_email,
           :support_phone,
           :support_url,
           :support_url_text,
           :what_happens_next_markdown,
           :delivery_configurations,
           to: :form_document

  alias_method :id, :form_id

  def document_json
    form_document.as_json
  end

  def payment_url_with_reference(reference)
    return nil if form_document.payment_url.blank?

    "#{form_document.payment_url}?reference=#{reference}"
  end

  # Deprecated: kept for historic Submission records. Use delivery_configurations on form_document.
  # Can be removed in September 2026 when historic Submissions with this field have been deleted.
  def submission_format
    form_document.try(:submission_format) || []
  end

  def support_details
    OpenStruct.new({
      email: form_document.support_email,
      phone: form_document.support_phone,
      call_charges_url: "https://www.gov.uk/call-charges",
      url: form_document.support_url,
      url_text: form_document.support_url_text,
    })
  end

  def language
    form_document.try(:language)&.to_sym || :en
  end

  def english?
    language == :en
  end

  def welsh?
    language == :cy
  end

  def copy_of_answers_enabled?
    return false unless Settings.copy_of_answers_enabled
    return false unless form_document.respond_to?(:send_copy_of_answers)

    form_document.send_copy_of_answers == "enabled"
  end

  def multilingual?
    available_languages.count > 1
  end

  def available_languages
    form_document.try(:available_languages) || []
  end

  def declaration_markdown
    form_document.try(:declaration_markdown)
  end

  def has_custom_branding?
    return false if form_document.try(:brand_id).blank?

    BRANDING_CONFIG.key?(form_document.brand_id)
  end

  def branding
    return nil unless has_custom_branding?

    BRANDING_CONFIG[form_document.brand_id]
  end
end
