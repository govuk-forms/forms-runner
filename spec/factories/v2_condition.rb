FactoryBot.define do
  factory :v2_condition, class: ActiveResource::Base do
    sequence(:id) { |n| n }

    routing_page_id { Faker::Alphanumeric.alphanumeric(number: 8) }
    check_page_id { routing_page_id }
    goto_page_id { Faker::Alphanumeric.alphanumeric(number: 8) }
    skip_to_end { false }
    answer_value { "Option 1" }

    exit_page_heading { nil }
    exit_page_markdown { nil }

    validation_errors { [] }

    trait :default do
      answer_value { nil }
    end

    trait :skip_to_end do
      goto_page_id { nil }
      exit_page_heading { nil }
      exit_page_markdown { nil }

      skip_to_end { true }
    end

    trait :with_exit_page do
      goto_page_id { nil }
      skip_to_end { false }

      exit_page_heading { Faker::Lorem.sentence }
      exit_page_markdown { Faker::Lorem.paragraph }
    end
  end
end
