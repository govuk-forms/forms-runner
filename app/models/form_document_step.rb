class FormDocumentStep < ActiveResource::Base
  self.site = Settings.forms_api.base_url
  self.prefix = "/api/v2/forms/:form_id/"
  self.include_format_in_path = false

  belongs_to :form

  def form_id
    @prefix_options[:form_id]
  end

  def next_step_id
    @attributes["next_page"]
  end

  def answer_settings
    @attributes["answer_settings"] || {}
  end

  def repeatable?
    @attributes["is_repeatable"] || false
  end
end
