FactoryBot.define do
  factory :form_document_step, class: "FormDocumentStep" do
    id { Faker::Alphanumeric.alphanumeric(number: 8) }
    question_text { Faker::Lorem.question }
    answer_type { "number" }
    is_optional { nil }
    page_heading { nil }
    guidance_markdown { nil }
    hint_text { nil }
    routing_conditions { [] }
    sequence(:position) { |n| n }

    trait :with_hints do
      hint_text { Faker::Quote.yoda }
    end

    trait :with_guidance do
      page_heading { Faker::Quote.yoda }
      guidance_markdown { "## List of items \n\n\n #{Faker::Markdown.ordered_list}" }
    end

    trait :with_simple_answer_type do
      answer_type { FormDocumentStep::ANSWER_TYPES.reject { |item| FormDocumentStep::ANSWER_TYPES_WITH_SETTINGS.include? item }.sample }
    end

    trait :with_selections_settings do
      transient do
        only_one_option { "true" }
        selection_options { [DataStruct.new(name: "Option 1", value: "Option 1"), DataStruct.new(name: "Option 2", value: "Option 2")] }
      end

      answer_type { "selection" }
      answer_settings { DataStruct.new(only_one_option:, selection_options:) }
    end

    trait :with_text_settings do
      transient do
        input_type { %w[single_line long_text].sample }
      end

      answer_type { "text" }
      answer_settings { DataStruct.new(input_type:) }
    end

    trait :with_date_settings do
      transient do
        input_type { %w[date_of_birth other_date].sample }
      end

      answer_type { "date" }
      answer_settings { DataStruct.new(input_type:) }
    end

    trait :with_address_settings do
      transient do
        uk_address { "true" }
        international_address { "true" }
      end

      answer_type { "address" }
      answer_settings { DataStruct.new(input_type: DataStruct.new(uk_address:, international_address:)) }
    end

    trait :with_name_settings do
      transient do
        input_type { "full_name" }
        title_needed { "true" }
      end

      answer_type { "name" }
      answer_settings { DataStruct.new(input_type:, title_needed:) }
    end
  end

  trait :with_repeatable do
    is_repeatable { true }
  end
end
