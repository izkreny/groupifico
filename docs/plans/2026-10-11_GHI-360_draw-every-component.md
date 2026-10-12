> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Draw every component on the styleguide

## The partials the page does not draw yet

Each joins `app/views/styleguides/show.html.erb` as its own section, drawn from the styleguide group the way the event sections are, and picked by status rather than by name so the spec's planted group draws as well as the seeded one:

- `groups/_group` twice, on the owner's membership and on a paused member's, so both of its badges draw; `groups/_form` on the group itself, whose saved home address draws the address card.
- `addresses/_address` and `addresses/_form` on that home address. `addresses/_form_fields` is already on the page, through `events/_form`'s new-address fields.
- `members/_member` for the owner and the paused member in a `list`, with `manages: true`, so `members/_roles`, the status badge and the "not signed in yet" badge all draw through it; `members/_form` on a new member, so the email field and the role checkboxes draw.
- `user_profiles/_user_profile` and `user_profiles/_form` on the owner's profile.
- `layouts/_header` with the group, its initials, the pencil, a switcher and the tabs, beside `layouts/_group_switcher` on the owner's and the paused member's memberships; `layouts/_group_tabs` once more inside a `dock` wrapper with `in_dock: true`, so `dock-active` draws. daisyUI's `dock` is `position: fixed`, so the wrapper carries `static` and stays inside its twin.

The members are read through `Member.preloaded`, since a member row reads its user, profile and roles and a lazy `has_many` load raises under test.

## Twins that mint the same ids

`groups/_form`, `members/_form`, `addresses/_form` and `user_profiles/_form` call `form_with(model:)` with nothing to tell two copies apart, so each twin would mint the same field ids and the label example in `spec/requests/styleguides_spec.rb` goes red, as does axe on `members/_form`'s `aria-describedby` hint ids. Each takes an optional `namespace:` local passed through to `form_with`, as `events/_form` already does, and every existing caller keeps its ids by passing nothing. `layouts/_header` gets a per-theme `switcher_id`, and `layouts/_group_switcher` the same id, so each `aria-controls` names its own dialog.

## Tokens and type

The colour swatches read the palette from its one home, the two `@plugin "./daisyui-theme.mjs"` blocks in `app/assets/tailwind/application.css`, through `StyleguidesHelper` in `app/helpers/styleguides_helper.rb` (new), so no second copy of the palette exists to drift. Each twin draws a table of its theme's `--color-*` tokens: the name, a swatch painting `var(--color-{name})`, the hex, and the WCAG contrast against its pair, which is `X-content` for `X` and back, and `base-content` for each `base-*`. `docs/design/organic-theme.js` (delete) also carried a source note per token and a ratio on `base-100`; neither carries over.

The type ladder names the six `--text-*` tokens `app/assets/tailwind/application.css` defines, each as its literal utility so Tailwind compiles it: `text-record`, `text-hero`, `text-shell` and `text-row-title` in Caprasimo through `font-heading`, `text-card-fact` and `text-meta` in Figtree, and a body line at the default size in 400, 600 and 700.

## Components no partial reaches

Most of the daisyUI components the app uses arrive through a partial, because the inventory of `class` attributes under `app/views` and in `app/form_builders/app_form_builder.rb` puts all but these in one. A components section draws the rest, each in the variant its screen uses: `collapse collapse-arrow collapse-title` from `events/show`, `select select-ghost` from `events/index`, `btn btn-primary btn-block` from `groups/index`, and the bare `alert` with `role="status"` from `events/duplicate`. A request example holds the page to it, per the first open question: it collects the daisyUI component classes from those files' `class` attributes against a hand-written list of daisyUI's component stems, and expects each class in the rendered page.

## Specs

- `spec/requests/styleguides_spec.rb` widens its template example to `app/views/**/_*.html.erb`, less `layouts/_head` and `styleguides/_section`, with `rendered_by` entries for the partials reached only through another: `addresses/form_fields` through `events/form`, `members/roles` through `members/member`, beside the two it carries.
- The same file gains an example finding a token's name and its hex from each theme on the page, and the components example above.
- `spec/helpers/styleguides_helper_spec.rb` (new) holds the palette read and the contrast ratio to hand-derived literals.
- `spec/styleguide/styleguide_spec.rb` gains an example that every swatch in both twins paints the hex it prints, counting the swatches, and one that the heading rungs compute to Caprasimo and the body rungs to Figtree.
- `spec/support/styleguide_helper.rb` plants a paused member and a home address on the group. Its users have never signed in, since the factory sets no `first_signed_in_at`, so that badge needs nothing.

## Seen red

- The widened template example fails on the unchanged template, which renders none of the thirteen partials.
- The tokens example fails on the unchanged page, which prints no hex.
- The components example fails on the unchanged page, which draws no `collapse`.
- The helper spec fails with the 0.05 offsets dropped from the contrast formula.
- The swatch and ladder examples fail on the unchanged page on their counts, since it has no swatch and no ladder.

## Deleted

`docs/design/organic-theme.html` (delete) and `docs/design/organic-theme.js` (delete) go once the page draws what they drew, and the comment in `app/assets/tailwind/application.css` naming the first points at `/styleguide` instead. Older plans that name them stay as written.

## Steps

- Reset the test database with `bin/rails db:test:prepare`.
- Widen the template example in `spec/requests/styleguides_spec.rb` and watch it fail on the unchanged template.
- Add the `namespace:` local to `groups/_form`, `members/_form`, `addresses/_form` and `user_profiles/_form`, in a commit of its own.
- Grow `plant_styleguide_group` and draw the thirteen partials' sections, through the daisyUI Blueprint MCP server, and watch the template example pass.
- Add `StyleguidesHelper` and its spec, watching it fail on the mutated formula, then draw the token tables and the type ladder with their request and styleguide examples, each watched failing first.
- Draw the components section with its request example, watched failing first.
- Delete `docs/design/organic-theme.html` (delete) and `docs/design/organic-theme.js` (delete), and repoint the comment in `app/assets/tailwind/application.css`.
- Run `bin/rspec spec/styleguide` on a freshly reset test database, then `bin/ci`.

Every step that writes markup goes through the daisyUI Blueprint MCP server, per the epic: the `daisyui-blueprint-mcp` skill first, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards, each finding checked against the rendered page before it is acted on.

## Verification

- `bin/rspec spec/requests/styleguides_spec.rb spec/helpers/styleguides_helper_spec.rb` passes, each new example having failed as *Seen red* says
- `bin/rspec spec/styleguide` passes on a test database just reset by `bin/rails db:test:prepare`, its accessibility audit included
- `bin/ci` is green

What these gates cannot see is whether either theme looks right, which is what the page is for and the owner's to judge on `/styleguide` against a seeded development database. They also cannot see inside the two dialogs, which render closed, nor whether the Blueprint inspector's static findings were weighed rightly.

## Open questions

- The issue's third criterion has no spec of its own. A request example diffing the daisyUI classes under `app/views` against the rendered page would hold it for components added later, at the price of a hand-kept list of daisyUI's component stems. Assumed: yes, as above.
- The group switcher and the confirm sheet are `<dialog>`s and render closed until their opener is pressed. Assumed: a closed dialog with a working opener counts as drawn.
- The contrast column keeps one ratio per token, against its pair, and drops the old page's source note and its ratio on `base-100`. Assumed: one column.

## Settled

None yet.
