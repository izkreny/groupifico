require 'rails_helper'

RSpec.describe MemberMailer, type: :mailer do
  describe "#welcome" do
    it "addresses the person added, naming the group" do
      member = create(:member, user: create(:user, email: "added@example.com"), group: create(:group, name: "Riverside Choir"))

      mail = described_class.welcome(member)

      expect(mail.to).to eq([ "added@example.com" ])
      expect(mail.subject).to eq("You were added to Riverside Choir")
    end

    # `filtered_path` filters the query string and never a path segment, so an address in the path
    # would reach the application log in plaintext. ADR 0004.
    it "links to the sign-in form with the address in the query string and never in the path" do
      member = create(:member, user: create(:user, email: "added@example.com"))

      url = sign_in_form_url_from(described_class.welcome(member))

      expect(url.path).to eq("/session/new")
      expect(URI.decode_www_form(url.query).to_h).to eq("email" => "added@example.com")
    end

    # The link is not a credential, so building the mail leaves nothing behind that could expire.
    it "mints no sign-in token" do
      member = create(:member)

      expect { described_class.welcome(member).message }.not_to change(SignInToken, :count)
    end
  end

  private
    def sign_in_form_url_from(mail)
      URI.parse(mail.body.encoded[%r{https?://\S+?/session/new\?email=[^\s"<]+}])
    end
end
