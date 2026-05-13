FactoryBot.define do
  factory :group, class: Api::V2::GroupResource do
    sequence(:name) { |n| "Group #{n}" }

    transient do
      group_admin_users_count { 1 }
      organisation_admin_users_count { 1 }
      organisation_name { Faker::Company.name }
    end

    group_admin_users do
      build_list(:admin_user, group_admin_users_count)
    end

    organisation do
      {
        name: organisation_name,
        admin_users: build_list(:admin_user, organisation_admin_users_count),
      }
    end
  end
end
