# ## Schema Information
#
# Table name: `users`
#
# ### Columns
#
# Name              | Type               | Attributes
# ----------------- | ------------------ | ---------------------------
# **`id`**          | `integer`          | `not null, primary key`
# **`email`**       | `string(250)`      | `not null`
# **`created_at`**  | `datetime`         | `not null`
# **`updated_at`**  | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_users_on_email` (_unique_):
#     * **`email`**
#
FactoryBot.define do
  factory :user do
    transient do
      first_name { Faker::Name.unique.first_name }
      last_name  { Faker::Name.unique.last_name }
    end

    email { Faker::Internet.unique.email(name: "#{first_name} #{last_name}") }

    trait :with_full_profile do
      after(:build) do |user, context|
        create(
          :user_profile,
          :with_all_attributes,
          user: user,
          first_name: context.first_name,
          last_name: context.last_name
        )
      end
    end
  end
end
