FactoryBot.define do
  factory :join_request do
    join_link
    sequence(:email)        { |n| "joiner.#{n}@example.com" }
    first_name              { "Ana" }
    last_name               { "Kovač" }
    sequence(:mobile_phone) { |n| "+385 91 000 #{n.to_s.rjust(4, '0')}" }
    sequence(:token_digest) { |n| JoinRequest.digest("join-request-token-#{n}") }
    expires_at { JoinRequest::EXPIRES_IN.from_now }
  end
end
