FactoryBot.define do
  factory :admin_user, class: DataStruct do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
  end
end
