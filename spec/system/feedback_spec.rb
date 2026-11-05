require "rails_helper"

# Only what a browser adds: the screens painting, the draft kept across a visit, the picked screenshots drawn as thumbnails, and the device details only JavaScript can read. What the form draws and what a submission saves without them is `spec/requests/feedbacks_spec.rb`'s.
RSpec.describe "Sending feedback", type: :system do
  it "paints the form in light, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :light
    resize_to ViewportHelper::MOBILE

    visit new_feedback_path

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint "form .btn-primary"
    expect(page).to be_accessible
  end

  it "paints the form in dark, with no accessibility violations" do
    sign_in_as create(:user)
    prefer_colour_scheme :dark
    resize_to ViewportHelper::MOBILE

    visit new_feedback_path

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint "form .btn-primary"
    expect(page).to be_accessible
  end

  it "keeps a typed description when the member leaves the form and comes back" do
    sign_in_as create(:user)

    visit new_feedback_path
    fill_in "Please describe the issue in as much detail as possible.", with: "The dock covers Save."
    visit root_path
    visit new_feedback_path

    expect(page).to have_field "Please describe the issue in as much detail as possible.", with: "The dock covers Save."
  end

  it "draws each picked screenshot and hides the tile once three are picked" do
    sign_in_as create(:user)

    visit new_feedback_path
    attach_file "feedback[screenshots][]", file_fixture("screenshot.png").to_s
    attach_file "feedback[screenshots][]", file_fixture("screenshot-2.png").to_s
    attach_file "feedback[screenshots][]", file_fixture("screenshot-3.png").to_s

    expect(page).to have_button "Remove screenshot 3"
    expect(page).to have_no_text "Add screenshot"

    click_button "Remove screenshot 2"

    expect(page).to have_text "Add screenshot"
  end

  it "draws no picked screenshot when the member comes back to the form" do
    sign_in_as create(:user)

    visit new_feedback_path
    pick_screenshot_made_in_page
    click_link "Cancel"
    expect(page).to have_no_field "Please describe the issue in as much detail as possible."
    page.go_back

    expect(page).to have_text "Add screenshot"
    expect(page).to have_no_button "Remove screenshot 1"
  end

  it "sends a screenshot and the device details, then thanks the member" do
    user = create(:user)
    sign_in_as user
    resize_to ViewportHelper::MOBILE

    visit new_feedback_path
    pick_screenshot_made_in_page
    fill_in "Please describe the issue in as much detail as possible.", with: "The dock covers Save."
    click_button "Send"

    expect(page).to have_text "Thank you"
    expect([ user.feedbacks.sole.screenshots.count, user.feedbacks.sole.viewport_width ]).to eq [ 1, "390" ]
  end

  it "forgets the draft once the feedback is sent" do
    sign_in_as create(:user)

    visit new_feedback_path
    fill_in "Please describe the issue in as much detail as possible.", with: "The dock covers Save."
    click_button "Send"
    expect(page).to have_text "Thank you"
    visit new_feedback_path

    expect(page).to have_field "Please describe the issue in as much detail as possible.", with: ""
  end

  it "paints the thank-you page, with no accessibility violations" do
    feedback = create(:feedback)
    sign_in_as feedback.user
    resize_to ViewportHelper::MOBILE

    visit feedback_path(feedback)

    expect(page).to paint "main .btn-primary"
    expect(page).to be_accessible
  end

  # WHY: a file CDP attaches cannot be read back in headless Chromium, so its thumbnail draws broken and submitting or leaving the page stalls the browser; a file the page makes itself goes through the same input as a phone's pick.
  def pick_screenshot_made_in_page
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const canvas = document.createElement("canvas")
      canvas.width = 120
      canvas.height = 200
      canvas.toBlob(blob => {
        const input = document.querySelector("input[type=file]")
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "made-in-page.png", { type: "image/png" }))
        input.files = transfer.files
        input.dispatchEvent(new Event("input", { bubbles: true }))
        done()
      }, "image/png")
    JS
    expect(page).to have_button "Remove screenshot 1"
  end
end
