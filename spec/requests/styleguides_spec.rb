require 'rails_helper'

# Production is the one environment the page is kept out of, and no spec runs there; the guard in
# `config/routes.rb` is `Rails.env.local?`, which answers true for this suite.
RSpec.describe "The styleguide", type: :request do
  describe "GET /styleguide" do
    context "when signed in" do
      it "draws the page" do
        sign_in_as(create(:user))

        get "/styleguide"

        expect(response.body).to include "Every shared partial, drawn from sample records"
      end

      # Every section is drawn twice, so an id a partial mints for itself is on the page twice unless
      # the twin names it; a label pointing at a repeated id labels the first twin's control only.
      it "points every label at exactly one control" do
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        ids = html.css("[id]").map { it["id"] }.tally
        expect(html.css("label[for]").map { it["for"] }.uniq.reject { ids[it] == 1 }).to be_empty
      end
    end

    context "when not signed in" do
      it "redirects to the login page" do
        get "/styleguide"

        expect(response).to redirect_to new_session_path
      end
    end
  end

  # Not a request, and here anyway: `spec/views` is banned by `.agents/testing.md`, and this is the
  # styleguide's own file. What it holds the page to is that its template renders every partial it
  # exists to show.
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
