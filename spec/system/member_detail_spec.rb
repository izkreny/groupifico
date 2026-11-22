require "rails_helper"

# Only what a browser adds. Which facts the screen states, and the pencil per reader, are
# `spec/requests/members_spec.rb`'s assertions. What is left: that the role badge and the contact
# card paint, that the screen, its description list included, has no accessibility violations,
# and the size its icons draw at.
RSpec.describe "The member detail page", type: :system do
  it "paints the member screen in light, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  it "paints the member screen in dark, with no accessibility violations" do
    reader = create(:member, :active, :with_all_attributes)
    target = create(:member, :active, :events_administrator, :with_all_attributes, group: reader.group)
    sign_in_as reader.user
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "##{ActionView::RecordIdentifier.dom_id(target)} .badge-soft"
    expect(page).to paint ".card"
    expect(page).to be_accessible
  end

  # WHY: #368; the screen wraps a long name and mobile, and keeps the pencil and the Email and Call buttons inside it, a long email included.
  it "wraps a long one-word name and mobile inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group, user: create(:user, first_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", last_name: "Simpsoncalifragilisticexpialaciousannoyedgruntcious", email: "simpsoncalifragilisticexpialaciousannoyedgruntcious@example.com"))
    target.profile.update!(mobile_phone: "+38591234567890123456789012345678901234567890123")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(target)} a[aria-label='Edit']", "##{ActionView::RecordIdentifier.dom_id(target)}")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Email ']", "main .card-body")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Call ']", "main .card-body")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  it "wraps a long multi-word name and mobile inside the screen on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group, user: create(:user, first_name: "Maximilian Bartholomew Featherstonehaugh", last_name: "Montgomery Worthington Smythe"))
    target.profile.update!(mobile_phone: "+385 91 234 5678 extension 9012 the office desk")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(gap_to_row_end("##{ActionView::RecordIdentifier.dom_id(target)} a[aria-label='Edit']", "##{ActionView::RecordIdentifier.dom_id(target)}")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Email ']", "main .card-body")).to be >= 0
    expect(gap_to_row_end("main a[aria-label^='Call ']", "main .card-body")).to be >= 0
    expect(horizontal_overflow).to eq 0
  end

  # WHY: #370 AC5; once the email can be copied it trims rather than wraps, within three quarters of its row, the cap read from the computed style so a class Tailwind never compiled fails it.
  it "trims a long email within three quarters of its row on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group, user: create(:user, email: "simpsoncalifragilisticexpialaciousannoyedgruntcious@example.com"))
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(truncated?("main dd span[title]")).to be true
    expect(page.evaluate_script(<<~JS)).to eq [ "75%", true ]
      (email => [ getComputedStyle(email).maxWidth, email.getBoundingClientRect().width <= email.parentElement.getBoundingClientRect().width * 0.75 + 0.5 ])(document.querySelector("main dd span[title]"))
    JS
    expect(horizontal_overflow).to eq 0
  end

  # WHY: #368; Manages trims a long event name, which links to the event's screen, so the list stays inside the screen.
  it "trims a long one-word managed event name on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group)
    create(:event, group: owner.group, creator: owner, manager: target, name: "SimpsoncalifragilisticexpialaciousannoyedgruntciousSimpsoncalifragilisticexpialaciousannoyedgruntcious")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(page).to have_css "#manages"
    expect(truncated?("section[aria-labelledby='manages'] li a")).to be true
    expect(horizontal_overflow).to eq 0
  end

  it "trims a long multi-word managed event name on a phone" do
    owner = create(:member, :active, :owner)
    target = create(:member, :active, group: owner.group)
    create(:event, group: owner.group, creator: owner, manager: target, name: "The Extraordinarily Long Named Spring Concert Of The Riverside Community Choir")
    sign_in_as owner.user
    resize_to ViewportHelper::MOBILE

    visit group_member_path(target.group, target)

    expect(page).to have_css "#manages"
    expect(truncated?("section[aria-labelledby='manages'] li a")).to be true
    expect(horizontal_overflow).to eq 0
  end

  # WHY: the copy buttons sit inline after their values, so their glyphs are the inline size while the Edit, Email and Call buttons keep the control size.
  it "draws its edit, email and call icons at 20px and its copy icons at 16px" do
    reader = create(:member, :active, :members_administrator, :with_all_attributes)
    target = create(:member, :active, :with_all_attributes, group: reader.group)
    sign_in_as reader.user

    visit group_member_path(target.group, target)

    expect(page.evaluate_script(<<~JS)).to eq [ 20, 20, 20, 16, 16 ]
      [ "a[aria-label^='Edit']", "a[aria-label^='Email ']", "a[aria-label^='Call ']", "button[aria-label$=' email']", "button[aria-label$=' mobile']" ]
        .map(control => document.querySelector(`main ${control} svg`).getBoundingClientRect().width)
    JS
  end

  # WHY: an inline glyph after text sits `text-icon`, 12px, after it; the button's box around the glyph is what the margin has to account for.
  it "sets each copy glyph 12px after its value" do
    reader = create(:member, :active)
    target = create(:member, :active, group: reader.group)
    sign_in_as reader.user

    visit group_member_path(target.group, target)

    expect(page.evaluate_script(<<~JS)).to eq [ 12, 12 ]
      [ ...document.querySelectorAll("main dd [data-clipboard-target='idle'] svg") ].map(glyph => Math.round(glyph.getBoundingClientRect().left - glyph.closest("div").firstElementChild.getBoundingClientRect().right))
    JS
  end

  # WHY: #370 AC2, walked in the browser, since only the browser can tell that the copy wrote the clipboard and confirmed it on the screen it was pressed on.
  context "with the copy buttons" do
    def clipboard(permission, setting)
      # WHY: granted or denied in the browser context Cuprite opened for this session rather than Chrome's default one, where a setting reaches no page here.
      page.driver.browser.page.command("Browser.setPermission", origin: page.evaluate_script("location.origin"), browserContextId: page.driver.browser.page.context_id, permission: { name: permission }, setting:)
    end

    it "copies the email and confirms it on the button" do
      reader = create(:member, :active)
      target = create(:member, :active, group: reader.group)
      sign_in_as reader.user

      visit group_member_path(target.group, target)
      clipboard "clipboard-read", "granted"
      click_on "Copy #{target.full_name}'s email"

      expect(page).to have_css "button[aria-label$=' email'] [data-clipboard-target='done']:not([hidden])", visible: :all
      expect(page).to have_css "[role='status'].sr-only", exact_text: "Email copied", visible: :all
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq target.email
      expect(page).to have_current_path group_member_path(target.group, target)
    end

    it "copies the mobile and confirms it on the button" do
      reader = create(:member, :active)
      target = create(:member, :active, group: reader.group)
      sign_in_as reader.user

      visit group_member_path(target.group, target)
      clipboard "clipboard-read", "granted"
      click_on "Copy #{target.full_name}'s mobile"

      expect(page).to have_css "button[aria-label$=' mobile'] [data-clipboard-target='done']:not([hidden])", visible: :all
      expect(page).to have_css "[role='status'].sr-only", exact_text: "Mobile copied", visible: :all
      expect(page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")).to eq target.mobile_phone
    end

    it "turns the check back into the copy icon" do
      reader = create(:member, :active)
      target = create(:member, :active, group: reader.group)
      sign_in_as reader.user

      visit group_member_path(target.group, target)
      click_on "Copy #{target.full_name}'s email"

      expect(page).to have_css "button[aria-label$=' email'] [data-clipboard-target='done']:not([hidden])", visible: :all
      expect(page).to have_css "button[aria-label$=' email'] [data-clipboard-target='idle']:not([hidden])", visible: :all, wait: 4
    end

    it "says so when the browser refuses the copy" do
      reader = create(:member, :active)
      target = create(:member, :active, group: reader.group)
      sign_in_as reader.user

      visit group_member_path(target.group, target)
      clipboard "clipboard-write", "denied"
      click_on "Copy #{target.full_name}'s email"

      expect(page).to have_css "[role='status']:not(.sr-only)", text: "Couldn't copy. Select the email and copy it yourself."
    end
  end
end
