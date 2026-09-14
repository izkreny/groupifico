require 'rails_helper'

# The page is drawn in development alone, so what the suite can prove about the controller is that
# nothing else answers for it.
RSpec.describe "The styleguide", type: :request do
  describe "GET /styleguide" do
    context "when signed in" do
      it "is not routed outside development" do
        sign_in_as(create(:user))

        get "/styleguide"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "is not routed outside development" do
        get "/styleguide"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
