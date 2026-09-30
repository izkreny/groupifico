require 'rails_helper'

RSpec.describe MailpaceDelivery do
  # WHY: production names the delivery method by this symbol, and one load hook in
  # `config/application.rb` is all that puts the class behind it.
  it "is the class registered behind the :mailpace delivery method" do
    expect(ActionMailer::Base.delivery_methods[:mailpace]).to eq(described_class)
  end

  describe "#deliver!" do
    it "authenticates with the api token it was configured with" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 200, body: { id: 1, status: "queued" }.to_json)
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      described_class.new(api_token: "test-token").deliver!(mail)

      expect(a_request(:post, "https://app.mailpace.com/api/v1/send").with(headers: { "MailPace-Server-Token" => "test-token" }))
        .to have_been_made
    end

    it "sends a text mail as its text body alone, with the sender's display name as written" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 200, body: { id: 1, status: "queued" }.to_json)
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      described_class.new(api_token: "test-token").deliver!(mail)

      expect(a_request(:post, "https://app.mailpace.com/api/v1/send").with(
        body: { from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", textbody: "Sign in to Chorifico" }
      )).to have_been_made
    end

    it "sends an html mail as its html body alone" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 200, body: { id: 1, status: "queued" }.to_json)
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link",
        content_type: "text/html; charset=UTF-8", body: "<p>Sign in to Chorifico</p>")

      described_class.new(api_token: "test-token").deliver!(mail)

      expect(a_request(:post, "https://app.mailpace.com/api/v1/send").with(
        body: { from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", htmlbody: "<p>Sign in to Chorifico</p>" }
      )).to have_been_made
    end

    # WHY: a real mailer's message rather than one built by hand, so the multipart shape under
    # test is the one Action Mailer produces.
    it "sends both bodies of a multipart mail" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 200, body: { id: 1, status: "queued" }.to_json)
      mail = SignInMailer.link(create(:user)).message

      described_class.new(api_token: "test-token").deliver!(mail)

      expect(a_request(:post, "https://app.mailpace.com/api/v1/send").with(
        body: hash_including("htmlbody" => a_string_including("<a href="), "textbody" => a_string_starting_with("Sign in to Chorifico:"))
      )).to have_been_made
    end

    it "sends a quoted-printable body as the characters it was written in" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 200, body: { id: 1, status: "queued" }.to_json)
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link",
        content_type: "text/plain; charset=UTF-8", content_transfer_encoding: "quoted-printable", body: "Dobro do=C5=A1li, =C5=BDeljka")

      described_class.new(api_token: "test-token").deliver!(mail)

      expect(a_request(:post, "https://app.mailpace.com/api/v1/send").with(body: hash_including("textbody" => "Dobro došli, Željka")))
        .to have_been_made
    end

    it "raises with MailPace's own reason when the api answers an error" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send")
        .to_return(status: 400, body: { error: "Invalid API Token" }.to_json, headers: { "Content-Type" => "application/json" })
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      expect { described_class.new(api_token: "wrong-token").deliver!(mail) }
        .to raise_error(MailpaceDelivery::Error, "MailPace answered 400: Invalid API Token")
    end

    it "raises with the field and its messages when the api answers field errors" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send")
        .to_return(status: 400, body: { errors: { to: [ "is invalid" ] } }.to_json, headers: { "Content-Type" => "application/json" })
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example", subject: "Your sign-in link", body: "Sign in to Chorifico")

      expect { described_class.new(api_token: "test-token").deliver!(mail) }
        .to raise_error(MailpaceDelivery::Error, "MailPace answered 400: to is invalid")
    end

    # WHY: an edge or a proxy in front of MailPace answers HTML, and a delivery method that only
    # understood MailPace's own JSON would report that as a success.
    it "raises with the status when the answer is not MailPace's own json" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send")
        .to_return(status: 502, body: "<html>Bad Gateway</html>", headers: { "Content-Type" => "text/html" })
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      expect { described_class.new(api_token: "test-token").deliver!(mail) }
        .to raise_error(MailpaceDelivery::Error, "MailPace answered 502")
    end

    it "raises with the status when the answer has no body" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send").to_return(status: 500)
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      expect { described_class.new(api_token: "test-token").deliver!(mail) }
        .to raise_error(MailpaceDelivery::Error, "MailPace answered 500")
    end
  end
end
