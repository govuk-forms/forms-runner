class Api::V2::StepResource < ActiveResource::Base
  self.element_name = "step"
  self.site = Api::V2::FormDocumentResource.site
  self.prefix = Api::V2::FormDocumentResource.prefix_source
  self.include_format_in_path = false

  belongs_to :form

  delegate :question_text, :hint_text, :answer_type, :is_optional, :page_heading, :guidance_markdown,
           :is_repeatable, to: :data

  def answer_settings
    data.try(:answer_settings) || {}
  end

  def repeatable?
    data.try(:is_repeatable) || false
  end
end
