require 'rails_helper'

RSpec.describe JoinRequestMailer, type: :mailer do
  describe "#link" do
    it "addresses the person who asked" do
      mail = described_class.link(create(:join_link).id, **details)

      expect(mail.to).to eq([ "ana@example.com" ])
    end

    it "names the group, so the mail says what the link would join" do
      join_link = create(:join_link, group: create(:group, name: "Riverside Choir"))

      mail = described_class.link(join_link.id, **details)

      expect(mail.subject).to include("Riverside Choir")
      expect(mail.body.encoded).to include("Riverside Choir")
    end

    # WHY: the row is written here rather than in the controller, so `POST /join` returns having written nothing.
    it "records the request as it builds" do
      join_link = create(:join_link)

      expect { described_class.link(join_link.id, **details).message }
        .to change { JoinRequest.outstanding.where(join_link:, email: "ana@example.com").count }.by(1)
    end

    # WHY: `filtered_path` filters the query string and never a path segment, per ADR 0004.
    it "carries the token in the query string and never in the path" do
      url = confirmation_url_from(described_class.link(create(:join_link).id, **details))

      expect(url.path).to eq("/join_request_confirmation")
      expect(URI.decode_www_form(url.query).to_h).to have_key("token")
    end

    it "sends a token that resolves to the request it recorded" do
      join_link = create(:join_link)

      token = URI.decode_www_form(confirmation_url_from(described_class.link(join_link.id, **details)).query).to_h.fetch("token")

      expect(JoinRequest.pending(token)).to have_attributes(join_link:, email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567")
    end

    it "sends nothing for a link turned off before the mail is built" do
      join_link = create(:join_link)
      join_link.destroy!

      expect { described_class.link(join_link.id, **details).deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end

  private
    def details
      { email: "ana@example.com", first_name: "Ana", last_name: "Kovač", mobile_phone: "+385 91 123 4567" }
    end

    def confirmation_url_from(mail)
      URI.parse(mail.body.encoded[%r{https?://\S+?/join_request_confirmation\?token=[\w\-]+}])
    end
end
