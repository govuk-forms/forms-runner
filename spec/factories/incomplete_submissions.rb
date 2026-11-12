FactoryBot.define do
  factory :incomplete_submission do
    sequence(:user_id) { |n| "user-#{n}" }
    form_id { Faker::Number.number(digits: 5) }
    form_version { 1 }
    mode { "form" }
    locale { "en" }
    submission_uuid { SecureRandom.uuid }
    answers { {} }
  end
end
