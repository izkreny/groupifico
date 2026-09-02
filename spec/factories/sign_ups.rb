# ## Schema Information
#
# Table name: `sign_ups`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`consumed_at`**   | `datetime`         |
# **`email`**         | `string(250)`      | `not null`
# **`expires_at`**    | `datetime`         | `not null`
# **`group_name`**    | `string(250)`      | `not null`
# **`token_digest`**  | `string`           | `not null`
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_sign_ups_on_token_digest` (_unique_):
#     * **`token_digest`**
#
FactoryBot.define do
  factory :sign_up do
    # Both domain columns are constrained and both are read by assertions - the confirmation page
    # names them - so both carry sequences rather than Faker, per `.agents/testing.md`.
    sequence(:email)      { |n| "starter.#{n}@example.com" }
    sequence(:group_name) { |n| "Chamber Choir #{n}" }
    sequence(:token_digest) { |n| SignUp.digest("sign-up-token-#{n}") }
    expires_at { SignUp::EXPIRES_IN.from_now }
  end
end
