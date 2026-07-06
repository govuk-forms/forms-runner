module Flow
  class QuestionRegister
    def self.from_form_document_step(form_document_step)
      klass = case form_document_step.answer_type.to_sym
              when :date
                Question::Date
              when :address
                Question::Address
              when :email
                Question::Email
              when :national_insurance_number
                Question::NationalInsuranceNumber
              when :phone_number
                Question::PhoneNumber
              when :number
                Question::Number
              when :selection
                Question::Selection
              when :organisation_name
                Question::OrganisationName
              when :text
                Question::Text
              when :name
                Question::Name
              when :file
                Question::File
              else
                raise ArgumentError, "Unexpected answer_type for form_document_step #{form_document_step.id}: #{form_document_step.answer_type}"
              end
      hint_text = form_document_step.respond_to?(:hint_text) ? form_document_step.hint_text : nil
      page_heading = form_document_step.respond_to?(:page_heading) ? form_document_step.page_heading : nil
      guidance_markdown = form_document_step.respond_to?(:guidance_markdown) ? form_document_step.guidance_markdown : nil
      klass.new({}, { question_text: form_document_step.question_text,
                      hint_text:,
                      is_optional: form_document_step.is_optional,
                      answer_settings: form_document_step.answer_settings,
                      page_heading:,
                      guidance_markdown: })
    end
  end
end
