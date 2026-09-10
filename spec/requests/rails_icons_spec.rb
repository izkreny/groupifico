require 'rails_helper'

# Two routes live under this prefix and they arrive by different routes of their own: the browser
# is mounted by `config/routes.rb`, and the sprite is prepended by the gem's own engine
# initializer, which runs in every environment and reads nothing this application configures.
RSpec.describe "The rails_icons routes", type: :request do
  it "does not mount the icon browser outside development, where it would list every synced glyph to anyone" do
    get "/rails_icons"

    expect(response).to have_http_status(:not_found)
  end

  it "does not answer the sprite outside development either, though sprite mode is off and its body is empty" do
    get "/rails_icons/sprite.svg"

    expect(response).to have_http_status(:not_found)
  end
end
