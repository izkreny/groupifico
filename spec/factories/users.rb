# ## Schema Information
#
# Table name: `users`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`email`**               | `string(250)`      | `not null`
# **`first_signed_in_at`**  | `datetime`         |
# **`created_at`**          | `datetime`         | `not null`
# **`updated_at`**          | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_users_on_email` (_unique_):
#     * **`email`**
#
FactoryBot.define do
  factory :user do
    transient do
      first_name { Faker::Name.first_name }
      last_name  { Faker::Name.last_name }
      set_up     { true }
    end

    # The sequence carries uniqueness and Faker only decorates, which is the split
    # `.agents/testing.md` asks for: a constrained field gets a sequence. `Faker::Name.unique` drew
    # from a finite pool and raised `RetryLimitExceeded` once a run created enough users - a suite
    # that failed on how many examples ran before it rather than on anything it asserted.
    sequence(:email) { |n| "#{first_name.parameterize}.#{last_name.parameterize}.#{n}@example.com" }

    # WHY: a signed-in user without a first name and a mobile is sent to the profile form from every page, so a user is set up unless a spec asks for the empty profile `User` builds for an email-only invitation.
    after(:build) do |user, context|
      user.build_profile(first_name: context.first_name, mobile_phone: generate(:mobile_phone)) if context.set_up && !user.profile
    end

    trait :not_set_up do
      set_up { false }
    end

    trait :with_full_profile do
      after(:create) do |user, context|
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
