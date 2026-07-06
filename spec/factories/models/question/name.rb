FactoryBot.define do
  factory :name, class: "Question::Name" do
    question_text { Faker::Lorem.question }
    hint_text { nil }
    is_optional { false }
    title { nil }
    full_name { nil }
    first_name { nil }
    middle_names { nil }
    last_name { nil }

    trait :with_hints do
      hint_text { Faker::Quote.yoda }
    end

    factory :full_name_question do
      transient do
        with_title { "false" }
      end
      title { with_title == "false" ? nil : Faker::Name.prefix }
      full_name { Faker::Name.name }
      answer_settings { DataStruct.new(input_type: "full_name", title_needed: with_title) }
    end

    factory :first_and_last_name_question do
      trait :unanswered do
        title { "" }
        first_name { "" }
        last_name { "" }
      end

      transient do
        with_title { "false" }
      end

      title { with_title == "false" ? nil : Faker::Name.prefix }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }

      answer_settings { DataStruct.new(input_type: "first_and_last_name", title_needed: with_title) }
    end

    factory :first_middle_last_name_question do
      transient do
        with_title { "false" }
      end

      title { with_title == "false" ? nil : Faker::Name.prefix }
      first_name { Faker::Name.first_name }
      middle_names { nil }
      last_name { Faker::Name.last_name }

      answer_settings { DataStruct.new(input_type: "first_middle_and_last_name", title_needed: with_title) }
    end
  end
end
