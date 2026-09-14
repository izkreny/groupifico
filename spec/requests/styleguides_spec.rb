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

  # Not a request, and here anyway: the page is not routed in test, `spec/views` is banned by
  # `.agents/testing.md`, and this is the one file that is the styleguide's. What the suite can hold
  # the page to is that its template renders every partial it exists to show.
  describe "its template" do
    it "renders every partial under app/views/events and app/views/shared" do
      template = Rails.root.join("app/views/styleguides/show.html.erb").read
      partials = Rails.root.glob("app/views/{events,shared}/_*.html.erb").map do |path|
        "#{path.dirname.basename}/#{path.basename.to_s.delete_prefix("_").delete_suffix(".html.erb")}"
      end
      # The summary is reached only through the builder, which draws it after the fields it reads.
      rendered_by = { "shared/errors" => "form.with_error_summary" }

      expect(partials).not_to be_empty
      expect(partials.reject { template.include?(rendered_by.fetch(it, %(render "#{it}"))) }).to be_empty
    end
  end
end
