require 'rails_helper'

RSpec.describe MemberMailer, type: :mailer do
  describe "#invitation" do
    it "addresses the person invited, naming the group" do
      member = create(:member, :pending, user: create(:user, email: "added@example.com"), group: create(:group, name: "Riverside Choir"))

      mail = described_class.invitation(member)

      expect(mail.to).to eq([ "added@example.com" ])
      expect(mail.subject).to eq("You are invited to join Riverside Choir")
    end

    # WHY: #505 AC1, the link signing them in through the sign-in form and opening the group's join page, the address and the destination both in the query string and never in the path, because `filtered_path` filters only the query string. ADR 0004.
    it "links to the sign-in form carrying the address and the group's join page in the query string" do
      member = create(:member, :pending, user: create(:user, email: "added@example.com"))

      url = sign_in_form_link_in(described_class.invitation(member))

      expect(url.path).to eq("/session/new")
      expect(URI.decode_www_form(url.query).to_h).to eq("email" => "added@example.com", "return_to" => "/groups/#{member.group_id}/invitation")
    end

    # The link is not a credential, so building the mail leaves nothing behind that could expire.
    it "mints no sign-in token" do
      member = create(:member, :pending)

      expect { described_class.invitation(member).message }.not_to change(SignInToken, :count)
    end
  end
end
