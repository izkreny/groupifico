require 'rails_helper'

RSpec.describe SignUpMailer, type: :mailer do
  describe "#link" do
    it "addresses the person who asked" do
      mail = described_class.link("starter@example.com", "Chamber Choir")

      expect(mail.to).to eq([ "starter@example.com" ])
    end

    # The row is written here rather than in the controller, so `POST /sign_up` returns having
    # written nothing at all. It could not be otherwise: the row stores only a digest, so a token
    # minted upstream could never be recovered to put in the URL.
    it "records the request as it builds, which nothing upstream does" do
      expect { described_class.link("starter@example.com", "Chamber Choir").message }
        .to change { SignUp.outstanding.where(email: "starter@example.com").count }.by(1)
    end

    # `filtered_path` filters the query string and never a path segment, so a token in the path
    # reaches the application log in plaintext whatever `filter_parameters` holds. ADR 0004.
    it "carries the token in the query string and never in the path" do
      url = confirmation_url_from(described_class.link("starter@example.com", "Chamber Choir"))

      expect(url.path).to eq("/sign_up_confirmation")
      expect(URI.decode_www_form(url.query).to_h).to have_key("token")
    end

    it "names the group, so the mail says what the link would create" do
      mail = described_class.link("starter@example.com", "Chamber Choir")

      expect(mail.body.encoded).to include("Chamber Choir")
    end

    it "sends a token that creates the group it named" do
      mail = described_class.link("starter@example.com", "Chamber Choir")

      token = URI.decode_www_form(confirmation_url_from(mail).query).to_h.fetch("token")

      expect(SignUp.redeem!(token).group.name).to eq("Chamber Choir")
    end
  end

  private
    def confirmation_url_from(mail)
      URI.parse(mail.body.encoded[%r{https?://\S+?/sign_up_confirmation\?token=[\w\-]+}])
    end
end
