class FormDocumentStep < ActiveResource::Base
  # If we make changes to this regex, update the WAF rules first
  PAGE_ID_REGEX_FOR_ROUTES = /(?:[a-zA-Z0-9]{8}|\d+)/
  PAGE_ID_REGEX = /\A#{PAGE_ID_REGEX_FOR_ROUTES}\z/

  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v2/forms/:form_id/"
  self.include_format_in_path = false

  belongs_to :form

  def form_id
    @prefix_options[:form_id]
  end

  def has_next_page?
    @attributes.include?("next_page") && !@attributes["next_page"].nil?
  end

  def answer_settings
    @attributes["answer_settings"] || {}
  end

  def repeatable?
    @attributes["is_repeatable"] || false
  end
end
