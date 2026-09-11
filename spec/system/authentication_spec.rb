require "rails_helper"

RSpec.describe "Authentication", type: :system do
  # The one spec that pays for the whole cycle in the browser, so the flow every other spec skips
  # by setting the cookie is still covered somewhere.
  it "signs a member in through the emailed link" do
    member = create(:member)

    sign_in_through_the_browser member.user

    expect(page).to have_current_path root_path
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
    expect(page).to have_current_path root_path
  end

  # The one screen in this flow nothing under `spec/system` had asserted about. The examples above
  # pass through it on their way to the root, which proves the button submits and says nothing
  # about whether a reader can see it: `spec/system/sign_in_page_spec.rb` carries why a class the
  # stylesheet never compiled leaves a control in the DOM with its label intact.
  describe "the page the emailed sign-in link opens" do
    before do
      visit sign_in_path(token: SignInToken.mint(create(:member).user))
    end

    it "paints the button that spends the link" do
      expect(page).to paint ".btn-primary"
    end

    # What catches the failure no other layer reaches on this screen: the heading names an address,
    # and the only control is a `button_to` whose form has no label of its own.
    it "has no accessibility violations" do
      expect(page).to be_accessible
    end

    # The screen that carries the longest sentence in the flow, and the one the overflow this
    # guards against bit hardest: 304px past a 390px viewport. `spec/system/sign_in_page_spec.rb`
    # carries why no other matcher sees it.
    it "does not scroll sideways at phone width" do
      resize_to ViewportHelper::MOBILE

      expect(horizontal_overflow).to eq 0
    end
  end
end
