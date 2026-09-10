> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Add an icon helper

Implementation plan for [#238](https://github.com/izkreny/groupifico/issues/238). The issue holds the acceptance criteria; this answers how.

## Approach

`rails_icons` supplies the Heroicons SVGs and the rendering; `IconsHelper` supplies this application's opinions about them. The gem's `icon` helper takes a file name and returns inline SVG, and everything the issue asks for beyond that - stroke width 2, `aria-hidden` by default, a name per legend meaning, a raise on an unknown status - is a thin layer in `app/helpers/icons_helper.rb` over that call.

The legend is recorded as one frozen `Hash` constant in that helper, so a view never spells a Heroicons file name and the mapping has exactly one home. `status_icon(record)` reads the record's `status` out of it with `fetch`, which is what makes an unknown status raise rather than render nothing.

## What the gem does and does not give us

Read from the gem's README before planning against it; each claim is re-checked against the generated initializer and the installed gem once `bundle add` has run, and a difference is reported rather than worked around silently.

- **Inline SVG is the default.** Sprite mode is opt-in through `config.default_sprite_location`, so leaving that key alone is what keeps `currentColor` and the theme's semantic classes working. Nothing is configured to achieve this.
- **The initializer carries `default_library` and `default_variant`**, which is exactly the pair the issue asks to be set to `heroicons` and `outline`.
- **Per-call defaults are not an initializer key.** `stroke_width:` is an option on the helper call, so "set once rather than at each call site" means `IconsHelper`, not `config/initializers/rails_icons.rb`.
- **The preview route is not development-only.** The generator mounts it and the README says to restrict it in production if needed, so the dev-only criterion is ours to satisfy: the mount goes inside a `Rails.env.development?` guard in `config/routes.rb`, and a request spec proves it 404s in test.
- **Attribute pass-through is unverified.** If arbitrary attributes reach the `<svg>`, `IconsHelper` passes `aria-hidden` and `aria-label` straight through; if they do not, it wraps the gem's output. Which one it is gets settled by reading the installed gem, not by trying it once.

## Naming the icons

The legend draws each icon as inline Heroicons outline path data, so the names are recoverable rather than guessed: normalise the `d` attributes of a legend SVG (every `<path>` joined, whitespace stripped) and match them against the files the generator syncs into `app/assets/svg/icons/heroicons/outline/`. An exact match names the icon; anything that fails to match is named in the handoff rather than filled in by eye.

Not every entry the issue lists is a legend row. The four event statuses, the five registration statuses and most of the interface set are; `home`, `events`, `close panel`, `back`, `go to` and `dismiss or cancel` are read off the screen frames instead - the tab bar, the pushed-screen back chevron, the disclosure pair and the form dismiss - and matched the same way. Sourcing those is its own step because the method differs, not the mapping.

## The two overrides the legend states

Heroicons outline ships at stroke 1.5 and the legend overrides it to 2 everywhere, so 2 is the helper's default. The back chevron alone passes 2.5, per the legend's group-mark panel and the issue. Both are decisions the legend states in prose rather than styling values read off a frame, so `## Wireframe fidelity` on the issue does not send them back to a component default: no daisyUI component has an opinion on icon stroke.

## Steps

- `bundle add rails_icons`, then `rails generate rails_icons:install --library=heroicons --variants outline solid`. Check the `Gemfile.lock` diff by eye afterwards: only `rails_icons` and its dependencies should have moved, and `BUNDLED WITH` should not have, per [`.agents/dependencies.md`](../../.agents/dependencies.md).
- Commit the synced SVG files. They are read from `app/assets/svg/icons/` at render time, so the suite needs them present; confirm Propshaft is happy with that tree rather than assuming it.
- Set `default_library` to `heroicons` and `default_variant` to `outline` in `config/initializers/rails_icons.rb`, and leave the sprite keys alone so rendering stays inline.
- Move the generator's `/rails_icons` mount inside a `Rails.env.development?` guard in `config/routes.rb`.
- Add `app/helpers/icons_helper.rb`: the frozen legend `Hash` - four event statuses, five registration statuses, and one entry per interface meaning the issue names - plus a single call into the gem that applies stroke width 2 and `aria-hidden="true"` unless an accessible label is passed, in which case the label is set and `aria-hidden` is not.
- Add `status_icon(record)` in the same helper, reading `record.status` out of the legend with `fetch` so an unknown status raises.
- Give the summary alert in `app/views/shared/_errors.html.erb` the warning triangle, which #239 shipped text-only pending this helper. The icon's placement inside the alert comes from the daisyUI Blueprint MCP server, loading the `daisyui-blueprint-mcp` skill first, per the epic.
- Add `spec/helpers/icons_helper_spec.rb`: one event status, one registration status, the unknown-status raise, the default stroke width, `aria-hidden` by default and the labelled form.
- Add a request spec proving `/rails_icons` answers 404 outside development.

## Verification

- `bin/ci`

What those gates cannot see: whether an icon reads as the thing it means. The mapping is proved correct against the legend by the path-data match, not by the suite, so what is left for the owner is whether the legend itself is right and whether the warning triangle sits where they want it in the alert.

The unknown-status raise is watched failing first, against a plain `[]` lookup that returns `nil` and renders nothing, before `fetch` goes in - `enum :status, validate: true` allows an invalid value on an unsaved record, so `build(:event, status: "bogus")` is a real case rather than a contrived one. The `/rails_icons` 404 spec is watched failing against the unguarded mount.

## Open questions

None.

## Settled

None yet.
