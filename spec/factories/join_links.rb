FactoryBot.define do
  factory :join_link do
    group
    sequence(:token) { |n| "join-link-#{n}" }
  end
end
