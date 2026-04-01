class Form < ActiveResource::Base
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v2/"
  self.include_format_in_path = false

  class Step < ActiveResource::Base
    self.site = Form.site
    self.prefix = Form.prefix_source
    self.include_format_in_path = false
  end

  has_many :steps, class_name: "form/step"
  attr_accessor :document_json

  def form_id
    @attributes["form_id"] || @attributes["id"]
  end

  alias_method :id, :form_id

  def form_document_steps
    # TODO: remove the need for this line - the form_document_steps attribute is only set in tests
    return @attributes["form_document_steps"] if @attributes.key? "form_document_steps"

    @form_document_steps ||= steps.map do |step|
      step = step.as_json
      attrs = {
        "id" => step["id"],
        "position" => step["position"],
        "next_page" => step["next_step_id"],
      }
      if step["type"] == "question_page"
        attrs.merge!(step["data"])
      end
      attrs["routing_conditions"] = step.fetch("routing_conditions", [])
      FormDocumentStep.new(attrs, @persisted)
    end
  end

  def step_by_id(step_id)
    form_document_steps.find { |s| s.id == step_id }
  end

  def payment_url_with_reference(reference)
    return nil if payment_url.blank?

    "#{payment_url}?reference=#{reference}"
  end

  def submission_format
    @attributes["submission_format"] || []
  end

  def support_details
    OpenStruct.new({
      email: support_email,
      phone: support_phone,
      call_charges_url: "https://www.gov.uk/call-charges",
      url: support_url,
      url_text: support_url_text,
    })
  end

  def language
    @attributes["language"]&.to_sym || :en
  end

  def english?
    language == :en
  end

  def welsh?
    language == :cy
  end

  def multilingual?
    @attributes["available_languages"].present? && @attributes["available_languages"].count > 1
  end
end
