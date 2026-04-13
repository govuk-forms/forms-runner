FactoryBot.define do
  factory :form, class: "Form" do
    initialize_with { new(build(:v2_form_document, **attributes)) }

    form_id { Faker::Number.number(digits: 5) }
    sequence(:name) { |n| "Form #{n}" }
    sequence(:form_slug) { |n| "form-#{n}" }
    submission_email { Faker::Internet.email(domain: "example.gov.uk") }
    privacy_policy_url { Faker::Internet.url(host: "gov.uk") }
    what_happens_next_markdown { nil }
    support_email { nil }
    support_phone { nil }
    support_url { nil }
    support_url_text { nil }
    payment_url { nil }
    language { "en" }
    declaration_text { nil }

    submission_type { "email" }

    s3_bucket_name { nil }
    s3_bucket_aws_account_id { nil }

    trait :live do
      with_steps
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      what_happens_next_markdown { "We usually respond to applications within 10 working days." }
    end

    trait :with_steps do
      transient do
        steps_count { 5 }
      end

      form_document_steps do
        Array.new(steps_count) { association(:form_document_step) }
      end
    end

    trait :with_support do
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      support_phone { Faker::Lorem.paragraph(sentence_count: 2, supplemental: true, random_sentences_to_add: 4) }
      support_url { Faker::Internet.url(host: "gov.uk") }
      support_url_text { Faker::Lorem.sentence(word_count: 1, random_words_to_add: 4) }
    end

    trait :with_payment_url do
      payment_url { "https://www.gov.uk/payments/test-service/pay-for-licence" }
    end
  end
end
