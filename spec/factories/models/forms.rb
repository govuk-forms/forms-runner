FactoryBot.define do
  factory :form, class: "Form" do
    sequence(:name) { |n| "Form #{n}" }
    sequence(:form_slug) { |n| "form-#{n}" }
    has_draft_version { true }
    has_live_version { false }
    submission_email { Faker::Internet.email(domain: "example.gov.uk") }
    privacy_policy_url { Faker::Internet.url(host: "gov.uk") }
    org { "test-org" }
    what_happens_next_markdown { nil }
    support_email { nil }
    support_phone { nil }
    support_url { nil }
    support_url_text { nil }
    payment_url { nil }
    language { "en" }
    document_json { nil }

    declaration_text { nil }
    declaration_section_completed { false }

    submission_type { "email" }

    s3_bucket_name { nil }
    s3_bucket_aws_account_id { nil }

    trait :new_form do
      submission_email { nil }
      privacy_policy_url { nil }
    end

    trait :ready_for_live do
      with_pages
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      what_happens_next_markdown { "We usually respond to applications within 10 working days." }
    end

    trait :live? do
      ready_for_live
      has_draft_version { false }
      has_live_version { true }
    end

    trait :with_pages do
      transient do
        pages_count { 5 }
      end

      form_document_steps do
        Array.new(pages_count) { association(:form_document_step) }
      end

      question_section_completed { true }
    end

    trait :with_support do
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      support_phone { Faker::Lorem.paragraph(sentence_count: 2, supplemental: true, random_sentences_to_add: 4) }
      support_url { Faker::Internet.url(host: "gov.uk") }
      support_url_text { Faker::Lorem.sentence(word_count: 1, random_words_to_add: 4) }
    end

    trait :ready_for_routing do
      transient do
        pages_count { 5 }
      end

      form_document_steps do
        Array.new(pages_count) { association(:form_document_step, :with_selections_settings) }
      end
    end

    trait :with_payment_url do
      payment_url { "https://www.gov.uk/payments/test-service/pay-for-licence" }
    end
  end
end
