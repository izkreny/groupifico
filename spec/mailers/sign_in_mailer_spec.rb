require 'rails_helper'

RSpec.describe SignInMailer, type: :mailer do
  describe "#link" do
    it "addresses the account holder" do
      user = create(:user)

      mail = described_class.link(user)

      expect(mail.to).to eq([ user.email ])
    end

    it "mints the token as it builds, so nothing upstream ever holds the raw value" do
      user = create(:user)

      expect { described_class.link(user).message }
        .to change { user.sign_in_tokens.outstanding.count }.by(1)
    end

    # `filtered_path` filters the query string and never a path segment, so a token in the path
    # reaches the application log in plaintext whatever `filter_parameters` holds. ADR 0004.
    it "carries the token in the query string and never in the path" do
      url = sign_in_url_from(described_class.link(create(:user)))

      expect(url.path).to eq("/sign_in")
      expect(URI.decode_www_form(url.query).to_h).to have_key("token")
    end

    it "sends a token that signs the addressee in" do
      user = create(:user)

      token = URI.decode_www_form(sign_in_url_from(described_class.link(user)).query).to_h.fetch("token")

      expect(SignInToken.redeem!(token)).to eq(user)
    end

    # The sender and the copy are asserted together because a mail signed by one brand and worded
    # by another undermines the single decision it exists to support: whether to trust the link.
    it "presents one brand, in the sender and in the copy alike" do
      mail = described_class.link(create(:user))

      expect(mail[:from].to_s).to eq("Chorifico <hello@chorifico.com>")
      expect(mail.body.encoded).to include("Chorifico")
      expect(mail.body.encoded).not_to include("Groupifico")
    end
  end

  private
    def sign_in_url_from(mail)
      URI.parse(mail.body.encoded[%r{https?://\S+?/sign_in\?token=[\w\-]+}])
    end
end
