require 'rails_helper'

# Production is the one environment the page is kept out of. The guard in `config/routes.rb` is `Rails.env.local?`, which answers true for this suite, so "its routes in production" draws them as production would.
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
      # Signed in as the owner, whose policies draw every labelled control the page holds.
      it "points every label at exactly one control" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        ids = html.css("[id]").map { it["id"] }.tally
        expect(html.css("label[for]").map { it["for"] }.uniq.reject { ids[it] == 1 }).to be_empty
      end

      # What reads through SQL: the roster's rows, the credits and the count tags.
      # A table of their own under daisyUI's, so the app's tokens are never read as daisyUI's.
      it "lists the app's own colour tokens apart from daisyUI's" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        rows = Nokogiri::HTML(response.body).css("#app_tokens_organic tr")
        expect(rows.map { [ it.at_css("code").text, it.css("td").size ] }).to eq [ [ "icon-muted", 5 ], [ "muted", 5 ] ]
      end

      it "draws the styleguide group's records" do
        plant_styleguide_group(manager: "Ana Horvat", invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        expect(html.css("[id^='roster_registration_']").map { it.text.squish }).to include "Ivan Kovačević"
        expect(page_text(response.body)).to include "Managed by Ana H."
        expect(html.css("[aria-label='no reply']")).not_to be_empty
      end

      # The owner may answer for every member and take anyone off the list, so every row draws both controls.
      it "draws the roster's controls on every row for the owner" do
        plant_styleguide_group(manager: "Ana Horvat", invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        expect(html.css("button[aria-label='Yes for Ivan Kovačević']")).not_to be_empty
        expect(html.css("button[aria-label='Take Marija Babić off the list']")).not_to be_empty
      end

      # The page asks the signed-in user's own policies, so a user outside the group is offered nothing they could not do.
      it "draws none of the roster's controls for a user outside the group" do
        plant_styleguide_group(invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        expect(html.css("button[aria-label='Yes for Ivan Kovačević']")).to be_empty
        expect(html.css("button[aria-label='Take Marija Babić off the list']")).to be_empty
      end

      it "draws the member rows' Edit pencils for the owner" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("a[aria-label='Edit Luka Marić']")).not_to be_empty
      end

      it "draws no Edit pencil on the member rows for a member who may not manage members" do
        plant_styleguide_group(invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("a[aria-label^='Edit Ana'], a[aria-label^='Edit Luka']")).to be_empty
      end

      # The paused member has never signed in, so a member who oversees the list sees the mark on that row; the owner's own row has none, since signing in stamps their first sign-in.
      it "marks the member rows not signed in yet for the owner" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Member rows, owner and paused" }
        expect(section.text).to include "not signed in yet"
      end

      it "draws no not-signed-in mark on the member rows for a member who does not oversee the list" do
        plant_styleguide_group(invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Member rows, owner and paused" }
        expect(section.text).not_to include "not signed in yet"
      end

      it "draws the confirm sheet's Delete event for the owner" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Confirm sheet" }
        expect(section.css("button").map { it.text.squish }).to include "Delete event"
      end

      # The sections drawing a screen only some members reach, each asked as that screen's controller asks.
      it "draws every gated screen's section for the owner" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("section h2").map(&:text)).to include("Event form", "Confirm sheet", "Group form", "Address form", "Member form")
      end

      it "draws none of the gated screens' sections for a member who may reach none of them" do
        plant_styleguide_group(invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("section h2").map(&:text) & [ "Event form", "Confirm sheet", "Group form", "Address form", "Member form" ]).to be_empty
      end

      it "draws the signed-in member's own profile" do
        plant_styleguide_group(manager: "Ana Horvat", invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Profile" }
        expect(section.css("h1").map { it.text.squish }.uniq).to eq [ "Ivan Kovačević" ]
      end

      it "draws the header's Edit group link for the owner" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("a[aria-label='Edit group']")).not_to be_empty
      end

      it "draws no Edit group link for a member who is not an owner" do
        plant_styleguide_group(invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("a[aria-label='Edit group']")).to be_empty
      end

      # Which members, in the order they joined; how each is labelled is the helper spec's.
      it "lists every member of the group in the switcher, in the order they joined" do
        plant_styleguide_group(manager: "Ana Horvat", invited: "Ivan Kovačević", said_yes: "Marija Babić")
        sign_in_as(create(:user))

        get "/styleguide"

        listed = Nokogiri::HTML(response.body).css("#member_switcher select option[value!='']").map { it["value"].to_i }
        expect(listed).to eq [ "Ana Horvat", "Ivan Kovačević", "Marija Babić", "Luka Marić" ].map { planted_member(it).id }
      end

      it "names the signed-in user in the switcher, though they are not a member" do
        plant_styleguide_group
        sign_in_as(create(:user, :with_full_profile, first_name: "Vesna", last_name: "Pisac"))

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).at_css("#member_switcher select option[value='']").text).to eq "Vesna Pisac (not a member)"
      end

      # The prompt is what a user outside the group starts on, and its blank value is a request the switch refuses as malformed, so the browser is told never to send it.
      it "requires a member to be picked before the switch submits" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).at_css("#member_switcher select")["required"]).not_to be_nil
      end

      it "selects the signed-in member in the switcher" do
        plant_styleguide_group(invited: "Ivan Kovačević")
        sign_in_as(planted_member("Ivan Kovačević").user)

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("#member_switcher select option[selected]").map { it["value"].to_i }).to eq [ planted_member("Ivan Kovačević").id ]
      end

      # Each twin draws its own theme's tokens, so a twin printing the other's palette fails here. The ratios were derived outside `StyleguidesHelper`, so a cell reading the wrong pair fails too.
      it "draws every colour token of both themes with its hex" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        html = Nokogiri::HTML(response.body)
        section = html.css("section").find { it.at_css("h2")&.text == "Colour tokens" }
        light, dark = %w[ organic organic-dark ].map { |theme| section.css("#daisyui_tokens_#{theme} tr").map { it.text.squish } }
        expect([ light.size, dark.size ]).to eq [ 20, 20 ]
        expect(light).to include "primary #8c491a 6.22:1 vs primary-content 5.72:1"
        expect(dark).to include "primary #e09675 6.00:1 vs primary-content 5.90:1"
      end

      # A surface is read against nothing, so it stays untagged however faint it is on the page, where a colour as faint is tagged; a cell asking with the wrong token's name turns one of them.
      it "tags every faint colour on the page but the surfaces" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Colour tokens" }
        tagged = section.css("#daisyui_tokens_organic-dark tr").to_h { [ it.at_css("code").text, it.css(".badge").any? ] }
        expect(tagged.values_at("base-200", "base-300", "neutral")).to eq [ false, false, true ]
      end

      # The switcher's commonest row is a group that is not the current one, which a switcher listing only the current group never draws.
      it "draws the owner's groups in the switcher, one current and one paused" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        rows = Nokogiri::HTML(response.body).css("#group_switcher_organic .menu a")
        expect(rows.map { it["aria-current"] }).to contain_exactly "true", nil
        expect(rows.flat_map { it.css(".badge").map(&:text) }).to contain_exactly "owner", "paused"
      end

      # What holds the page to every daisyUI component the app uses, in each variant, as the template example holds it to every partial. The classes are read from `class` attributes only, since the same words run through the comments, and a variant prefix such as `sm:` is dropped. The form builder is read for every quoted literal too, because it picks `textarea` and `select` from a map rather than writing them in a `class`. The stems are daisyUI 5's components, by hand, and a class counts only where the vendored daisyUI bundle defines it, which leaves out every Tailwind utility sharing a stem's prefix, such as `list-disc` or `mask-none`.
      it "draws every daisyUI class the app's views use" do
        plant_styleguide_group(manager: "Ana Horvat")
        sign_in_as(planted_member("Ana Horvat").user)

        get "/styleguide"

        stems = %w[ alert avatar badge breadcrumbs btn calendar card carousel chat checkbox collapse countdown diff divider dock drawer dropdown fab fieldset file-input filter footer hero indicator input join kbd label link list loading mask menu mockup modal navbar pagination progress radial-progress radio range rating select skeleton stack stat status steps swap tab tabs table textarea timeline toast toggle tooltip validator ]
        sources = Rails.root.glob("{app/views/**/*.erb,app/helpers/*.rb,app/form_builders/*.rb}").reject { it.to_s.include?("styleguide") }
        used = sources.flat_map { it.read.scan(/class(?:=|:\s*)("[^"]*"|\[[^\]]*\]|\{[^}]*\}|\([^)]*\))/).flatten.flat_map { it.scan(%r{[\w:/-]+}) } }.map { it[/[^:]*\z/] }
        used += Rails.root.join("app/form_builders/app_form_builder.rb").read.scan(/"([^"#]*)"/).flatten.flat_map(&:split)
        drawn = Nokogiri::HTML(response.body).css("[class]").flat_map { it["class"].split }.map { it[/[^:]*\z/] }
        daisyui = Rails.root.join("app/assets/tailwind/daisyui.mjs").read.scan(/\.([a-z][a-z0-9-]*[a-z0-9])(?![a-z0-9-])/).flatten.to_set
        expect(used.uniq.select { |name| daisyui.include?(name) && stems.any? { name == it || name.start_with?("#{it}-") } } - drawn).to be_empty
      end

      # The deleted `docs/design/organic-theme.html` drew these variants of components the app uses, and no view uses them yet; the page keeps them so the theme is still judged against them. Its `tabs-box` is left out, since no view uses tabs at all.
      it "draws the variants of the app's components that no view uses yet" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        variants = %w[ btn-secondary btn-accent btn-neutral btn-outline btn-soft btn-disabled input-error badge-primary badge-secondary badge-accent badge-neutral badge-outline badge-info badge-success badge-warning badge-error card-border alert-info alert-warning alert-soft ]
        expect(variants - Nokogiri::HTML(response.body).css("[class]").flat_map { it["class"].split }).to be_empty
      end

      it "links each daisyUI component section to its page in the daisyUI docs" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("section a[href^='https://daisyui.com/']").map { it["href"] }).to contain_exactly(
          "https://daisyui.com/components/alert/", "https://daisyui.com/components/badge/", "https://daisyui.com/components/button/",
          "https://daisyui.com/components/card/", "https://daisyui.com/components/collapse/", "https://daisyui.com/components/dropdown/",
          "https://daisyui.com/components/input/", "https://daisyui.com/components/select/"
        )
      end

      it "draws every legend glyph once, beside its Heroicons name" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Legend icons" }
        rows = section.css("[data-theme=organic] tbody tr")
        expect(rows.map { it.css("td")[1].text.squish }).to eq IconsHelper::ICONS.values.uniq
        expect(rows.map { it.at_css("td svg").present? }.uniq).to eq [ true ]
      end

      # A glyph serving two meanings lists both in one row, each with where the app draws it.
      it "lists each meaning a legend glyph is used for, with where the app draws it" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Legend icons" }
        used = section.css("[data-theme=organic] tbody tr").to_h { [ it.css("td")[1].text.squish, it.css("td")[2] ] }
        expect(used.values_at("check-circle", "calendar", "plus").map { |cell| cell.css("li code").map(&:text) }).to eq [ %w[ yes success ], %w[ when events ], [] ]
        expect(IconsHelper::ICONS.reject { |meaning, name| used.fetch(name).text.squish.include?("#{meaning} - #{StyleguidesHelper::ICON_USES.fetch(meaning)}") }).to be_empty
      end

      it "links the rest of Heroicons from the legend's header" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Legend icons" }
        expect(section.css("a[href='https://heroicons.com']").map(&:text)).to eq [ "The rest of Heroicons" ]
      end

      # The members' names are Croatian, so the letters a font may lack are drawn in every rung a name is set in.
      it "draws the Croatian letters in each body weight and in the record title" do
        plant_styleguide_group
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Character set" }
        expect(section.css("[data-theme=organic] p").map(&:text).count { it.include?("ČĆĐŠŽ čćđšž") }).to eq 4
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

      it "names the seed command when the owner is paused in no second group" do
        group = plant_styleguide_group
        Member.where.not(group:).delete_all
        sign_in_as(create(:user))

        get "/styleguide"

        expect(page_text(response.body)).to include "bin/rails db:seed:replant"
      end

      it "names only what the database lacks once the group's ongoing event has ended" do
        plant_styleguide_group
        sign_in_as(create(:user))
        travel 4.days

        get "/styleguide"

        expect(Nokogiri::HTML(response.body).css("main li").map { it.text.squish }).to eq [ "an event under way" ]
      end

      # The seed makes two active owners; the page draws the one seeded first, whose paused place in a second group the switcher needs.
      it "draws the owner who joined first when the group has two active owners" do
        plant_styleguide_group(manager: "Ana Horvat")
        create(:member, :active, :owner, group: Group.find_by(name: StyleguidesController::GROUP_NAME), user: create(:user, :with_full_profile, first_name: "Zrinka", last_name: "Zec"))
        sign_in_as(create(:user))

        get "/styleguide"

        section = Nokogiri::HTML(response.body).css("section").find { it.at_css("h2")&.text == "Member rows, owner and paused" }
        expect(section.at_css("[data-theme=organic] li a").text.squish).to eq "Ana Horvat"
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

  # Not a request either, and here for the reason the template's example gives. `config/routes.rb` is drawn into a route set of its own while `Rails.env` answers production, so the application's own routes are never redrawn and both stubs end with the example.
  describe "its routes in production" do
    it "draws no route to the page" do
      routes = ActionDispatch::Routing::RouteSet.new
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      allow(Rails.application).to receive(:routes).and_return(routes)

      load Rails.root.join("config/routes.rb")

      expect { routes.recognize_path("/styleguide") }.to raise_error ActionController::RoutingError
    end

    it "draws no route to the member switch" do
      routes = ActionDispatch::Routing::RouteSet.new
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      allow(Rails.application).to receive(:routes).and_return(routes)

      load Rails.root.join("config/routes.rb")

      expect { routes.recognize_path("/styleguide/session", method: :post) }.to raise_error ActionController::RoutingError
    end
  end

  # Not a request, and here anyway: `spec/views` is banned by `.agents/testing.md`, and this is the
  # styleguide's own file. What it holds the page to is that its template renders every partial it
  # exists to show.
  describe "its template" do
    it "renders every partial under app/views but the head and its own section" do
      # The styleguide's own partials are read with it, since a section may render one, which renders the app partials it draws.
      template = Rails.root.glob("app/views/styleguides/{show.html.erb,**/_*.html.erb}").map(&:read).join
      partials = Rails.root.glob("app/views/**/_*.html.erb").map do |path|
        "#{path.dirname.relative_path_from(Rails.root.join("app/views"))}/#{path.basename.to_s.delete_prefix("_").delete_suffix(".html.erb")}"
      end
      # The summary is reached only through the builder, which draws it after the fields it reads,
      # and the confirm sheet through the event's delete partial, which is where its strings live.
      # The address fields and the role tags are each drawn by the one partial that renders them.
      # The switcher is drawn through the header, the tabs through the layout's own wrappers, and an alert's frame and the roster toggle each wrap what they are rendered around.
      rendered_by = { "shared/errors" => "form.with_error_summary", "shared/confirm_sheet" => %(render "events/delete"), "addresses/form_fields" => %(render "events/form"), "members/roles" => %(render "members/member"), "layouts/group_switcher" => %(render "layouts/header"), "layouts/group_tabs" => %(render "layouts/dock"), "shared/alert" => %(render layout: "shared/alert"), "events/roster_toggle" => %(render layout: "events/roster_toggle") }

      expect(partials).not_to be_empty
      expect((partials - %w[ layouts/head styleguides/section ]).reject { template.include?(rendered_by.fetch(it, %(render "#{it}"))) }).to be_empty
    end
  end
end
