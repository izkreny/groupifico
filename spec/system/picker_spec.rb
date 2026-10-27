require "rails_helper"

# The picker draws inside its own shadow root, which is why each example reaches its pill and outlines through `shadow_root`.
RSpec.describe "The element picker", type: :system do
  let(:file) { Rails.root.join("tmp/picks-#{SecureRandom.hex(4)}.jsonl") }

  before { allow(Rails.configuration.x).to receive(:picks_file).and_return(file) }
  after { file.delete if file.exist? }

  it "keeps a picked element and its comment as a line of the picks file" do
    member = create(:member, group: create(:group))
    sign_in_as member.user

    visit group_path(member.group)
    find("[data-picker]").shadow_root.find(".pill").click
    find("h2", text: "Nothing in the diary").click
    page.driver.browser.keyboard.type("Less dense", [ :Control, :Enter ])

    expect(find("[data-picker]").shadow_root).to have_css ".outline", text: "1 · Less dense"
    expect(JSON.parse(file.read)).to include("page" => group_path(member.group), "comment" => "Less dense", "text" => "Nothing in the diary")
  end

  it "outlines each pick still in the file, labelled with its comment" do
    member = create(:member, group: create(:group))
    file.write(%({"page":"#{group_path(member.group)}","comment":"Less dense","selector":"h2"}\n))
    sign_in_as member.user

    visit group_path(member.group)

    expect(find("[data-picker]").shadow_root).to have_css ".outline", text: "1 · Less dense"
  end

  it "counts a pick whose element is gone as not found" do
    member = create(:member, group: create(:group))
    file.write(%({"page":"#{group_path(member.group)}","comment":"Less dense","selector":"#gone"}\n))
    sign_in_as member.user

    visit group_path(member.group)

    expect(find("[data-picker]").shadow_root).to have_css ".pill", text: "Pick · 1 here · 1 in all · 1 not found"
  end
end
