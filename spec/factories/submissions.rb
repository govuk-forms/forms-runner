FactoryBot.define do
  factory :submission do
    created_at { Time.zone.now - 2.minutes }
    updated_at { created_at }
    reference { Faker::Alphanumeric.alphanumeric(number: 8).upcase }
    form_id { Faker::Number.number(digits: 5) }
    answers do
      {
        "1" => {
          selection: "Option 1",
        },
        "2" => {
          text: "Example text",
        },
      }
    end
    mode { is_preview ? "preview-live" : "form" }
    form_document { build :v2_form_document, :with_steps, form_id: }
    submission_locale { :en }

    transient do
      is_preview { false }
    end

    trait :sent do
      transient do
        delivery_reference { Faker::Alphanumeric.alphanumeric }
      end

      after(:create) do |submission, evaluator|
        submission.deliveries << create(:delivery, delivery_reference: evaluator.delivery_reference)
      end
    end

    trait :bounced do
      after(:create) do |submission|
        submission.deliveries << create(:delivery, :failed, failure_reason: "bounced")
      end
    end

    trait :preview do
      mode { "preview-live" }
    end
  end
end
