FactoryBot.define do
  factory :step, class: "Step" do
    form_document_step { association :question_step }
    question { build(:full_name_question) }

    initialize_with { new(question:, form_document_step:) }
  end
end
