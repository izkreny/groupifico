require 'rails_helper'

RSpec.describe Redeemable, type: :model do
  describe ".digest" do
    # The label the extraction had to reproduce byte for byte. `SignInToken` passed the literal
    # "SignInToken token digest" before the concern derived it from the model name, and if the
    # derivation came out even one word short every outstanding sign-in link would stop verifying
    # with nothing in the suite reporting it: `spec/factories/sign_in_tokens.rb` computes its
    # digest through `SignInToken.digest`, so both sides of every comparison move together and
    # stay green.
    #
    # So the label is the literal here and the key generator is reached directly. A stored hex
    # digest cannot be the pin: `secret_key_base` comes from `tmp/local_secret.txt`, which is
    # per-machine and untracked, so the digest of a fixed token differs between this checkout and
    # CI. Nothing on the expected side runs through `Redeemable`, which is what keeps this from
    # being the mirror assertion `.agents/testing.md` forbids - watched failing against a derived
    # label of "#{name} digest".
    it "keys SignInToken off the label its pre-extraction code passed" do
      raw = "pinned-raw-token"
      key = Rails.application.key_generator.generate_key("SignInToken token digest", 32)

      expect(SignInToken.digest(raw)).to eq(OpenSSL::HMAC.hexdigest("SHA256", key, raw))
    end

    # The label is derived per model, so the two tables draw from independent keyspaces. Nothing
    # exploits a shared one today, since every lookup is confined to its own table, which is why
    # the independence needs saying out loud somewhere - watched failing against a version passing
    # the literal "SignInToken token digest" for both.
    it "gives the two tables independent keyspaces for one raw token" do
      raw = "shared-raw-token"

      expect(SignUp.digest(raw)).not_to eq(SignInToken.digest(raw))
    end
  end
end
