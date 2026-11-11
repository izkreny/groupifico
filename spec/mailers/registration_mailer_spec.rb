require 'rails_helper'

RSpec.describe RegistrationMailer, type: :mailer do
  describe "#response_requested" do
    it "addresses the member, naming the group and the event" do
      group = create(:group, name: "Riverside Choir")
      registration = create(:registration, event: create(:event, group:, name: "Spring concert"), member: create(:member, group:, user: create(:user, email: "asked@example.com")))

      mail = described_class.response_requested(registration)

      expect(mail.to).to eq([ "asked@example.com" ])
      expect(mail.subject).to eq("Riverside Choir: are you coming to Spring concert?")
    end

    it "states when the event starts, in both parts" do
      event = create(:event, starts_at: Time.zone.local(2026, 11, 13, 18), ends_at: Time.zone.local(2026, 11, 13, 20))

      mail = described_class.response_requested(create(:registration, event:))

      expect(mail.text_part.decoded).to include("Fri 13 Nov · 18:00–20:00")
      expect(mail.html_part.decoded).to include("Fri 13 Nov · 18:00–20:00")
    end

    it "links to the event's page in both parts" do
      registration = create(:registration)
      url = "http://example.com/groups/#{registration.event.group_id}/events/#{registration.event_id}"

      mail = described_class.response_requested(registration)

      expect(mail.text_part.decoded).to include(url)
      expect(mail.html_part.decoded).to include(%(href="#{url}"))
    end

    it "reaches a member who has never signed in" do
      registration = create(:registration, member: create(:member, user: create(:user, email: "new@example.com", first_signed_in_at: nil)))

      expect(described_class.response_requested(registration).to).to eq([ "new@example.com" ])
    end

    # WHY: the link is the event page, never a credential, so building the mail leaves nothing behind that could expire.
    it "mints no sign-in token" do
      registration = create(:registration)

      expect { described_class.response_requested(registration).message }.not_to change(SignInToken, :count)
    end
  end
end
