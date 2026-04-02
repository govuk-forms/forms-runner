FactoryBot.define do
  factory :repeatable_step, class: "RepeatableStep" do
    form_document_step { association :form_document_step }
    question { build(:full_name_question) }

    initialize_with { new(question:, form_document_step:) }
  end
end
