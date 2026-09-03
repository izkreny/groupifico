require 'rails_helper'

RSpec.describe MailpaceDelivery do
  describe "#deliver!" do
    # MailPace's own 4xx bodies carry an `error` key and the gem raises on those. This is the shape
    # it does not recognise: an edge or a proxy answering with HTML, where the gem's
    # `handle_response` falls through and reports a success that never happened.
    it "raises when the api answers a status the gem does not recognise" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send")
        .to_return(status: 502, body: "<html>Bad Gateway</html>", headers: { "Content-Type" => "text/html" })
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      expect { described_class.new(api_token: "test-token").deliver!(mail) }
        .to raise_error(Mailpace::DeliveryError)
    end

    it "returns the response when the api accepts the message" do
      stub_request(:post, "https://app.mailpace.com/api/v1/send")
        .to_return(status: 200, body: { id: 1, status: "queued" }.to_json, headers: { "Content-Type" => "application/json" })
      mail = Mail.new(from: "Chorifico <hello@chorifico.com>", to: "member@example.com", subject: "Your sign-in link", body: "Sign in to Chorifico")

      response = described_class.new(api_token: "test-token").deliver!(mail)

      expect(response.code).to eq(200)
    end
  end
end
