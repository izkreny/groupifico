require "rails_helper"

RSpec.describe "Authentication", type: :system do
  # WHY: here rather than for every system spec, because it swaps the job adapter for the test one, and only this file reads a mail a page sent.
  include ActiveJob::TestHelper

  # The one spec that pays for the whole cycle in the browser, so the flow every other spec skips
  # by setting the cookie is still covered somewhere.
  # WHY: #498 AC1, a member of one group landing on its page when signing in.
  it "signs a member in through the emailed link, landing on their one group, per AC1" do
    member = create(:member)

    sign_in_through_the_browser member.user

    expect(page).to have_current_path group_path(member.group)
  end

  # The route #208 gives somebody an owner or administrator invited: the invitation's link opens the
  # sign-in form already holding their address, the button asks for a sign-in link, and that link
  # lands them on the profile form, since an invitee is known by the address alone (#472 AC1).
  # The sign-in link is minted rather than read out of a delivered mail, which is what
  # `sign_in_through_the_browser` already does.
  it "signs an invitee in from the invitation, landing on the profile form" do
    member = Member.create!(group: create(:group, name: "Riverside Choir"), email: "added@example.com", status: :pending)
    link   = URI.parse(MemberMailer.invitation(member).text_part.decoded[%r{https?://\S+?/session/new\?\S+}])

    visit link.request_uri
    expect(page).to have_field "Email", with: "added@example.com"
    click_button "Email me a sign-in link"
    expect(page).to have_text "Check your inbox"

    sign_in_through_the_browser member.user
    expect(page).to have_current_path edit_user_profile_path, ignore_query: true
  end

  # WHY: #430 AC1 walked in the browser, with the link read out of the delivered mail so every hop is the real one; the event's creator is the member, since the factory makes them one of its group.
  it "returns a member who opened an event page signed out to it after signing in" do
    event = create(:event)

    visit group_event_path(event.group, event)
    fill_in "Email", with: event.creator.user.email
    perform_enqueued_jobs do
      click_button "Email me a sign-in link"
      expect(page).to have_text "Check your inbox"
    end
    visit mailed_sign_in_link(event.creator.user.email).request_uri
    click_button "Sign in"

    expect(page).to have_current_path group_event_path(event.group, event)
  end

  # WHY: #446 AC7 walked in the browser, a visitor nobody has heard of yet following a join link and coming back to it, with the link read out of the delivered mail so every hop is the real one; landing on the profile form from the Sign in button is the session having started, since a refused link lands on the sign-in form, and #472 AC1 sends a visitor known by the address alone there first, carrying the join page that its Save returns to.
  it "returns a visitor who asked from a join link towards the join page, signed in" do
    token = JoinLink.mint(create(:group))

    visit new_join_request_path(token:)
    fill_in "Your email", with: "visitor@example.com"
    perform_enqueued_jobs do
      click_button "Email me a sign-in link"
      expect(page).to have_text "Check your inbox"
    end
    visit mailed_sign_in_link("visitor@example.com").request_uri
    click_button "Sign in"

    expect(page).to have_current_path edit_user_profile_path(return_to: new_join_request_path(token:))
  end

  # Guards the helper every other system spec depends on: a cookie the browser rejects would make
  # each of them fail as though its own subject were broken.
  it "signs in without the browser when the cookie helper is used" do
    member = create(:member)

    sign_in_as member.user
    visit root_path

    # Positive rather than "not the sign-in page": a negation immediately after `visit` can be
    # satisfied before the navigation resolves, which is what `Capybara/RSpec/
    # NegationMatcherAfterVisit` exists to catch. It caught this line.
    expect(page).to have_current_path group_path(member.group)
  end

  # The one screen in this flow nothing under `spec/system` had asserted about. The examples above
  # pass through it on their way to the root, which proves the button submits and says nothing
  # about whether a reader can see it: `spec/system/sign_in_page_spec.rb` carries why a class the
  # stylesheet never compiled leaves a control in the DOM with its label intact.
  describe "the page the emailed sign-in link opens" do
    let(:user) { create(:member).user }
    let(:link) { sign_in_path(token: SignInToken.mint(user)) }

    before do
      visit link
    end

    it "paints the button that spends the link" do
      expect(page).to paint ".btn-primary"
    end

    # Frame 10a sets the address in the secondary colour, #526539, on a line of its own.
    it "sets the address in the secondary colour" do
      expect(find("h1 span", text: user.email).evaluate_script("getComputedStyle(this).color")).to eq "rgb(82, 101, 57)"
    end

    # `spec/system/sign_in_page_spec.rb` carries why the heading is the measure.
    it "stretches the button across the column" do
      expect(width_of(".btn-primary")).to eq width_of("h1")
    end

    # What catches the failure no other layer reaches on this screen: the heading names an address,
    # and the only control is a `button_to` whose form has no label of its own.
    it "has no accessibility violations" do
      expect(page).to be_accessible
    end

    # The screen that carries the longest sentence in the flow, and the one the overflow this
    # guards against bit hardest: 304px past a 390px viewport. `spec/system/sign_in_page_spec.rb`
    # carries why no other matcher sees it, and why the width is stated before the page is opened
    # rather than after.
    #
    # The address is a literal, and a long one, rather than the factory's. An email has no break
    # opportunity in it, so whether this heading fits is decided by how long the address is - and
    # the factory's sequence makes that depend on how many users the examples before this one
    # happened to create, which is a guard that passes or fails by running order.
    it "does not scroll sideways at phone width" do
      user = create(:user, email: "kassandra.wetherington.blythe@example.com")

      resize_to ViewportHelper::MOBILE
      visit sign_in_path(token: SignInToken.mint(user))

      expect(horizontal_overflow).to eq 0
    end
  end
end
