FactoryBot.define do
  factory :exit_page, class: ActiveResource::Base do
    sequence(:id) { |n| n }

    heading { Faker::Lorem.sentence }
    markdown { Faker::Lorem.paragraph }
  end
end
