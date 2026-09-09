require "rails_helper"

# Only what a browser adds. Which groups the index lists, and for whom, is `spec/requests/
# groups_spec.rb`'s assertion and per the duplication rule in `.agents/testing.md` it does not come
# back here. What no request spec can reach is whether either theme reaches the page at all: the
# markup is identical under both, and the whole difference lives in the compiled stylesheet.
#
# Each example states its own preference rather than one of them relying on the driver reset, so
# the pair passes under either order, as `config.order = :random` requires.
RSpec.describe "The groups index", type: :system do
  it "paints in light when the device prefers light" do
    member = create(:member)
    sign_in_as member.user
    prefer_colour_scheme :light

    visit groups_path

    expect(rendered_colour_scheme).to eq "light"
    expect(page).to paint ".btn-primary"
    expect(page).to be_accessible
  end

  # `.btn-primary` for the same reason `spec/system/paint_matcher_spec.rb` picks it: Tailwind
  # compiles only the classes it finds, and the index's own "New group" link carries these, so they
  # are certain to be in the build. `body` would not do - light `base-100` is `oklch(100% 0 0)`,
  # identical to the surface the matcher composites against, so a correctly painted page scores 1.0
  # and reads as painting nothing.
  it "paints in dark when the device prefers dark" do
    member = create(:member)
    sign_in_as member.user
    prefer_colour_scheme :dark

    visit groups_path

    expect(rendered_colour_scheme).to eq "dark"
    expect(page).to paint ".btn-primary"
    expect(page).to be_accessible
  end
end
