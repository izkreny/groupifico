FactoryBot.define do
  factory :sign_in_token do
    user
    sequence(:token_digest) { |n| SignInToken.digest("sign-in-token-#{n}") }
    expires_at { SignInToken::EXPIRES_IN.from_now }
  end
end
