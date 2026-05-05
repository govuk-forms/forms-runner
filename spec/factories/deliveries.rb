FactoryBot.define do
  factory :delivery do
    delivery_reference { Faker::Alphanumeric.alphanumeric }
    created_at { Time.current }
    delivery_schedule { :immediate }

    trait :not_sent do
      delivery_reference { nil }
    end

    trait :pending do
      delivered_at { nil }
      failed_at { nil }
    end

    trait :delivered do
      delivered_at { created_at + 5.minutes }
      failed_at { nil }
    end

    trait :failed do
      delivered_at { nil }
      failed_at { created_at + 5.minutes }
      failure_reason { "example" }
    end

    trait :bounced do
      failed
      failure_reason { "bounced" }
    end

    trait :delivered_after_failure do
      failed_at { created_at + 5.minutes }
      delivered_at { created_at + 10.minutes }
      failure_reason { "example" }
    end

    trait :delivered_after_bounce do
      delivered_after_failure
      failure_reason { "bounced" }
    end

    trait :failed_after_delivery do
      delivered_at { created_at + 5.minutes }
      failed_at { created_at + 10.minutes }
      failure_reason { "example" }
    end

    trait :bounced_after_delivery do
      failed_after_delivery
      failure_reason { "bounced" }
    end

    trait :daily_scheduled_delivery do
      delivery_schedule { "daily" }
      batch_begin_at { created_at.beginning_of_day }
    end

    trait :weekly_scheduled_delivery do
      delivery_schedule { "weekly" }
      batch_begin_at { (created_at - 7.days).beginning_of_day }
    end
  end
end
