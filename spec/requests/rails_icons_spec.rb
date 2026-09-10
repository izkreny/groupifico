require 'rails_helper'

RSpec.describe "The rails_icons preview", type: :request do
  it "is not mounted outside development, where it would list every synced glyph to anyone" do
    get "/rails_icons"

    expect(response).to have_http_status(:not_found)
  end
end
