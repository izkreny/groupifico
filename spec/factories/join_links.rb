FactoryBot.define do
  factory :join_link do
    group
    sequence(:token_digest) { |n| JoinLink.digest("join-link-#{n}") }
  end
end
