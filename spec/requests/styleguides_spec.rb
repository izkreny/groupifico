require 'rails_helper'

# Production is the one environment the page is kept out of, and no spec runs there; the guard in
# `config/routes.rb` is `Rails.env.local?`, which answers true for this suite.
RSpec.describe "The styleguide", type: :request do
  describe "GET /styleguide" do
    context "when signed in" do
      it "draws the page" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        expect(response.body).to include "Every colour, type size, component and partial, drawn from sample records"
      end

      # Every section is drawn twice, so an id a partial mints for itself is on the page twice unless
      # the twin names it; a label pointing at a repeated id labels the first twin's control only.
      it "points every label at exactly one control" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        ids = html.css("[id]").map { it["id"] }.tally
        expect(html.css("label[for]").map { it["for"] }.uniq.reject { ids[it] == 1 }).to be_empty
      end

      # What reads through SQL: the roster's rows, the said-yes line, the credits and the count tags.
      it "draws the styleguide group's records" do
        plant_styleguide_group(manager: "Ana Horvat", invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        expect(html.css("[id^='roster_registration_']").map { it.text.squish }).to include "Ivan Kovačević"
        expect(page_text(response.body)).to include "Marija Babić said yes"
        expect(page_text(response.body)).to include "Managed by Ana H."
        expect(html.css(".badge [aria-label='no reply']")).not_to be_empty
      end

      # A signed-in user who belongs to no group still gets every control a permitted member would.
      it "draws the roster's controls on every row" do
        plant_styleguide_group(invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        expect(html.css("button[aria-label='Yes for Ivan Kovačević']")).not_to be_empty
        expect(html.css("button[aria-label='Take Marija Babić off the list']")).not_to be_empty
      end

      # Each twin draws its own theme's tokens, so a twin printing the other's palette fails here.
      it "draws every colour token of both themes with its hex" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        light, dark = %w[ organic organic-dark ].map { |theme| html.css("[data-theme='#{theme}'] tbody tr").map { it.text.squish } }
        expect([ light.size, dark.size ]).to eq [ 20, 20 ]
        expect(light).to include a_string_starting_with("primary #8c491a")
        expect(dark).to include a_string_starting_with("primary #e09675")
      end

      # What holds the page to every daisyUI component the app uses, in each variant, as the template example holds it to every partial. The classes are read from `class` attributes only, since the same words run through the comments, and a variant prefix such as `sm:` is dropped. The stems are daisyUI 5's components, by hand.
      it "draws every daisyUI class the app's views use" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        stems = %w[ alert avatar badge breadcrumbs btn calendar card carousel chat checkbox collapse countdown diff divider dock drawer dropdown fab fieldset file-input filter footer hero indicator input join kbd label link list loading mask menu mockup modal navbar pagination progress radial-progress radio range rating select skeleton stack stat status steps swap tab tabs table textarea timeline toast toggle tooltip validator ]
        sources = Rails.root.glob("{app/views/**/*.erb,app/helpers/*.rb,app/form_builders/*.rb}").reject { it.to_s.include?("/styleguides/") }
        used = sources.flat_map { it.read.scan(/class(?:=|:\s*)("[^"]*"|\[[^\]]*\]|\{[^}]*\}|\([^)]*\))/).flatten.flat_map { it.scan(%r{[\w:/-]+}) } }.map { it[/[^:]*\z/] }
        drawn = Nokogiri::HTML(response.body).css("[class]").flat_map { it["class"].split }.map { it[/[^:]*\z/] }
        expect(used.uniq.select { |name| stems.any? { name == it || name.start_with?("#{it}-") } } - drawn).to be_empty
      end

      it "names the seed command when the styleguide group is missing" do
        sign_in_as(create(:user))

        get "/styleguide"

        expect(page_text(response.body)).to include "bin/rails db:seed:replant"
      end

      it "names the seed command once the styleguide group's ongoing event has ended" do
        plant_styleguide_group
        sign_in_as(create(:user))
        travel 4.days

        get "/styleguide"

        expect(page_text(response.body)).to include "bin/rails db:seed:replant"
      end

      it "names the seed command when no group carries the styleguide group's name" do
        plant_styleguide_group.update!(name: "Our own choir")
        sign_in_as(create(:user))

        get "/styleguide"

        expect(page_text(response.body)).to include "bin/rails db:seed:replant"
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
    it "renders every partial under app/views but the head and its own section" do
      template = Rails.root.join("app/views/styleguides/show.html.erb").read
      partials = Rails.root.glob("app/views/**/_*.html.erb").map do |path|
        "#{path.dirname.relative_path_from(Rails.root.join("app/views"))}/#{path.basename.to_s.delete_prefix("_").delete_suffix(".html.erb")}"
      end
      # The summary is reached only through the builder, which draws it after the fields it reads,
      # and the confirm sheet through the event's delete partial, which is where its strings live.
      # The address fields and the role tags are each drawn by the one partial that renders them.
      rendered_by = { "shared/errors" => "form.with_error_summary", "shared/confirm_sheet" => %(render "events/delete"), "addresses/form_fields" => %(render "events/form"), "members/roles" => %(render "members/member") }

      expect(partials).not_to be_empty
      expect((partials - %w[ layouts/head styleguides/section ]).reject { template.include?(rendered_by.fetch(it, %(render "#{it}"))) }).to be_empty
    end
  end
end
