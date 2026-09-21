FactoryBot.define do
  factory :delivery_configuration, class: DataStruct do
    delivery_method { "email" }
    delivery_schedule { "immediate" }
    formats { [] }

    trait :immediate_email do
      delivery_method { "email" }
      delivery_schedule { "immediate" }
    end

    trait :immediate_s3 do
      delivery_method { "s3" }
      delivery_schedule { "immediate" }
      formats { %w[csv] }
    end

    trait :daily_email do
      delivery_method { "email" }
      delivery_schedule { "daily" }
      formats { %w[csv] }
    end

    trait :weekly_email do
      delivery_method { "email" }
      delivery_schedule { "weekly" }
      formats { %w[csv] }
    end
  end
end
