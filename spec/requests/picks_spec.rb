require 'rails_helper'

# The store answers signed out as signed in, since the sign-in screens load the picker too, so each action is asserted in both.
RSpec.describe "Picks", type: :request do
  let(:file) { Rails.root.join("tmp/picks-#{SecureRandom.hex(4)}.jsonl") }
  let(:pick) { { id: 1, page: "/groups/1", comment: "Less dense", selector: "main > h1", text: "Samplifichoir", html: "<h1>Samplifichoir</h1>", templates: [ "app/views/groups/show.html.erb" ] } }

  before { allow(Rails.configuration.x).to receive(:picks_file).and_return(file) }
  after { file.delete if file.exist? }

  describe "GET /picks" do
    it "answers every pick in the file, skipping a blank line" do
      file.write(%({"id":1,"comment":"Less dense"}\n\n{"id":2,"comment":"Wider"}\n))

      get "/picks"

      expect(response.parsed_body).to eq [ { "id" => 1, "comment" => "Less dense" }, { "id" => 2, "comment" => "Wider" } ]
    end

    it "answers no picks before the file exists" do
      get "/picks"

      expect(response.parsed_body).to eq []
    end

    it "answers signed in as it does signed out" do
      file.write(%({"id":1,"comment":"Less dense"}\n))
      sign_in_as(create(:user))

      get "/picks"

      expect(response.parsed_body).to eq [ { "id" => 1, "comment" => "Less dense" } ]
    end

    it "answers 404 where no picks file is set" do
      allow(Rails.configuration.x).to receive(:picks_file).and_return(nil)

      get "/picks"

      expect(response).to have_http_status :not_found
    end
  end

  describe "POST /picks" do
    it "appends the pick to the file as one JSON line" do
      file.write(%({"id":0}\n))

      post "/picks", params: { pick: }, as: :json

      expect(response).to have_http_status :created
      expect(file.readlines.map { JSON.parse(it) }).to eq [ { "id" => 0 }, pick.deep_stringify_keys ]
    end

    it "appends signed in as it does signed out" do
      sign_in_as(create(:user))

      post "/picks", params: { pick: }, as: :json

      expect(file.readlines.map { JSON.parse(it) }).to eq [ pick.deep_stringify_keys ]
    end

    it "answers 404 and writes nothing where no picks file is set" do
      allow(Rails.configuration.x).to receive(:picks_file).and_return(nil)

      post "/picks", params: { pick: }, as: :json

      expect(response).to have_http_status :not_found
      expect(file).not_to exist
    end
  end
end
