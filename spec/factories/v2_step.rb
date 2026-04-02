FactoryBot.define do
  factory :v2_step, class: Api::V2::StepResource do
    id { Faker::Alphanumeric.alphanumeric(number: 8) }

    sequence(:position) { |n| n }
    next_step_id { nil }

    routing_conditions { [] }

    type { nil }
    data { nil }

    factory :v2_question_page_step do
      type { "question_page" }

      transient do
        answer_type { "number" }
        answer_settings { nil }

        question_text { Faker::Lorem.question }

        hint_text { nil }

        guidance_markdown { nil }
        page_heading { nil }

        is_optional { false }
        is_repeatable { false }
      end

      data do
        DataStruct.new(
          answer_settings:,
          answer_type:,
          guidance_markdown:,
          hint_text:,
          is_optional:,
          is_repeatable:,
          page_heading:,
          question_text:,
        )
      end

      trait :with_hints do
        hint_text { Faker::Quote.yoda }
      end

      trait :with_guidance do
        page_heading { Faker::Quote.yoda }
        guidance_markdown { "## List of items \n\n\n #{Faker::Markdown.ordered_list}" }
      end

      factory :v2_selection_question_page_step do
        answer_type { "selection" }
        answer_settings do
          if none_of_the_above_question
            Struct.new(:only_one_option, :selection_options, :none_of_the_above_question)
                  .new(only_one_option, selection_options, none_of_the_above_question)
          else
            Struct.new(:only_one_option, :selection_options).new(only_one_option, selection_options)
          end
        end

        transient do
          only_one_option { "true" }
          selection_options { [{ name: "Option 1", value: "Option 1" }, { name: "Option 2", value: "Option 2" }] }
          none_of_the_above_question { nil }
        end

        trait :with_none_of_the_above_question do
          is_optional { true }

          transient do
            none_of_the_above_question_text { Faker::Lorem.question }
            none_of_the_above_question_is_optional { "false" }
          end

          none_of_the_above_question do
            Struct.new(:question_text, :is_optional)
                  .new(none_of_the_above_question_text, none_of_the_above_question_is_optional)
          end
        end
      end

      trait :with_text_settings do
        transient do
          input_type { %w[single_line long_text].sample }
        end

        answer_type { "text" }
        answer_settings do
          DataStruct.new(
            input_type:,
          )
        end
      end

      trait :with_name_settings do
        transient do
          input_type { "first_and_last_name" }
          title_needed { "false" }
        end

        answer_type { "name" }
        answer_settings do
          DataStruct.new(
            input_type:,
            title_needed:,
          )
        end
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

      trait :with_file_upload_settings do
        answer_type { "file" }
      end

      trait :with_repeatable do
        is_repeatable { true }
      end
    end
  end
end
