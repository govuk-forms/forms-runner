class Form
  attr_reader :document_json
  private attr_reader :form_document

  def initialize(form_document, form_document_json = nil)
    @form_document = form_document
    @document_json = form_document_json
  end

  delegate :steps, to: :form_document, prefix: true
  delegate :available_languages,
           :declaration_markdown,
           :declaration_text,
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
           :submission_format,
           :submission_type,
           :support_email,
           :support_phone,
           :support_url,
           :support_url_text,
           :what_happens_next_markdown,
           to: :form_document

  alias_method :id, :form_id

  def step_by_id(step_id)
    form_document_steps.find { |s| s.id == step_id }
  end

  def payment_url_with_reference(reference)
    return nil if form_document.payment_url.blank?

    "#{form_document.payment_url}?reference=#{reference}"
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
    form_document.language.to_sym
  end

  def english?
    language == :en
  end

  def welsh?
    language == :cy
  end

  def multilingual?
    form_document.available_languages.count > 1
  end
end
