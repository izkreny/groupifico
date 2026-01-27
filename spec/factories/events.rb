# ## Schema Information
#
# Table name: `events`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`category`**     | `integer`          |
# **`description`**  | `text(100000)`     |
# **`ends_at`**      | `datetime`         | `not null`
# **`name`**         | `string(250)`      | `not null`
# **`starts_at`**    | `datetime`         | `not null`
# **`status`**       | `integer`          | `not null`
# **`created_at`**   | `datetime`         | `not null`
# **`updated_at`**   | `datetime`         | `not null`
# **`address_id`**   | `integer`          |
# **`creator_id`**   | `bigint`           | `not null`
# **`group_id`**     | `integer`          | `not null`
# **`manager_id`**   | `bigint`           |
#
# ### Indexes
#
# * `index_events_on_group_id`:
#     * **`group_id`**
#
# ### Foreign Keys
#
# * `address_id` (_ON DELETE => restrict ON UPDATE => cascade_):
#     * **`address_id => addresses.id`**
# * `group_id` (_ON DELETE => cascade ON UPDATE => cascade_):
#     * **`group_id => groups.id`**
#
FactoryBot.define do
  factory :event do
    name      { Faker::TvShows::Simpsons.episode_title }
    starts_at { Faker::Date.unique.between_except(from: 180.days.ago, to: 180.days.from_now, excepted: Date.today) + 10.hours }
    ends_at   { starts_at + 1.hour }
    group
    creator

    trait :from_the_past do
      starts_at { Faker::Date.unique.between(from: 180.days.ago, to: 7.days.ago) + 10.hours }
    end

    trait :from_the_future do
      starts_at { Faker::Date.unique.between(from: 7.days.from_now, to: 180.days.from_now) + 10.hours }
    end

    trait :with_all_attributes do
      description { Faker::TvShows::Simpsons.quote }
      association :group,   :with_all_attributes
      association :creator, :with_all_attributes
      association :manager, :with_all_attributes
      association :address, :with_all_attributes
    end
  end
end
