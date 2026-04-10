FactoryBot.define do
  factory :v2_form_document, class: Api::V2::FormDocumentResource do
    form_id { Faker::Number.number(digits: 5) }

    sequence(:name) { |n| "Form #{n}" }
    form_slug { name ? name.parameterize : nil }

    steps { [] }

    declaration_text { nil }
    payment_url { nil }
    privacy_policy_url { nil }
    submission_email { nil }
    submission_type { nil }
    submission_format { nil }
    support_email { nil }
    support_phone { nil }
    support_url { nil }
    support_url_text { nil }
    what_happens_next_markdown { nil }
    language { "en" }
    s3_bucket_aws_account_id { nil }
    s3_bucket_name { nil }
    s3_bucket_region { nil }
    updated_at { Time.current.iso8601(3) }
    send_daily_submission_batch { false }
    send_weekly_submission_batch { false }

    trait :with_steps do
      transient do
        steps_count { 5 }
      end

      steps do
        Array.new(steps_count) { build(:v2_question_step) }
      end

      start_page { steps.first.id }
    end

    trait :with_privacy_policy_url do
      privacy_policy_url { Faker::Internet.url host: "gov.uk" }
    end

    trait :with_submission_email do
      submission_type { "email" }
      submission_format { [] }
      submission_email { Faker::Internet.email domain: "example.gov.uk" }
    end

    trait :with_support do
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      support_phone { Faker::Lorem.paragraph(sentence_count: 2, supplemental: true, random_sentences_to_add: 4) }
      support_url { Faker::Internet.url(host: "gov.uk") }
      support_url_text { Faker::Lorem.sentence(word_count: 1, random_words_to_add: 4) }
    end

    trait :ready_for_live do
      with_steps
      with_privacy_policy_url
      with_submission_email
      support_email { Faker::Internet.email(domain: "example.gov.uk") }
      what_happens_next_markdown { "We usually respond to applications within 10 working days." }
    end

    trait :live do
      ready_for_live
    end

    trait :s3_submissions_enabled do
      ready_for_live
      submission_type { "s3" }
      submission_format { %w[csv] }
      s3_bucket_aws_account_id { "21487124" }
      s3_bucket_name { "a-bucket-name" }
      s3_bucket_region { "eu-west-2" }
    end
  end
end
