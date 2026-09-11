> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Build the mobile shell

## What the frames are, and what they are not

The Groupifico Wireframes are wireframes: they settle structure, order, which controls a reader sees and how the screen feels. They are not a pixel specification, and their own custom properties — `--color-accent-700`, `--space-6`, `--radius-md`, a 10px dot in a 20px slot, a 32px avatar growing to 34px — are the export's design system, not this application's. Through the beta milestone this application is stock daisyUI: its components as they ship, its semantic colour classes, its own spacing and radii.

So every frame fact below is read for structure and never transcribed as a measurement. Where a frame draws a bottom bar of three icons, the answer is daisyUI's `dock`, not a flex row rebuilt to the export's paddings. Where it draws a pulled-down sheet, the answer is `modal`. Where it draws an accent dot, the answer is `bg-primary`.

## What the shell replaces

`app/views/layouts/application.html.erb` renders `layouts/_navigation` — a `navbar` with a Home link and, depending on `authenticated?`, either a Log out button or the Log in and Start a group links — then `layouts/_flash`, then `<main class="container mx-auto mt-28 px-5 flex">`. Every screen inside a group therefore carries a chrome that names neither the group nor the section, and the `container` cap is Tailwind's breakpoint ladder rather than the single column the frames show.

Three of those links have no home after this change, and each is settled below rather than left to be discovered at implementation time.

## The daisyUI components each row is built from

Named here so the diff is judged against a decision rather than against whatever the markup ended up as. The MCP server's component syntax expert settles the exact markup for each; this is which component, not how to write it.

| Row              | Component                                              |
|------------------|--------------------------------------------------------|
| Header           | `navbar`, with `navbar-start` and `navbar-end`         |
| Avatar           | `avatar avatar-placeholder`, initials as its content   |
| Switcher sheet   | `modal`, `modal-top`, `modal-box`                      |
| Switcher rows    | `menu`, one `li` per group                             |
| Row tags         | `badge`, `badge-primary` for `owner` and `badge-ghost` for `paused` |
| Tabs, mobile     | `dock`, three `dock-label`-less icon links, `dock-active` on the current one |
| Tabs, desktop    | the same three links inside `navbar-end`               |
| Flash            | `alert alert-success` and `alert alert-error`, unchanged |
| Chevron, pencil  | `btn btn-ghost btn-circle btn-sm`                      |

`dock` is daisyUI's own bottom navigation and is in the vendored bundle — checked, along with `navbar`, `modal`, `avatar`, `badge` and `menu`. It is what makes the mobile tab row a component rather than a layout: it fixes itself to the bottom, sizes its own icons, and carries `dock-active` for the current section, so nothing here reimplements any of that.

The flash keeps the classes it has. `spec/system/group_refusal_spec.rb` asserts `#alert` *paints*, so a class daisyUI does not define leaves the element in the DOM with its text intact and turns that spec red — which is exactly what it was written to catch.

## Who renders which piece

The frames draw one header row and one tab row, and both belong to the layout: they are the same markup on every screen inside a group, and the alternative — every screen row rendering them — is the `content_for` handshake the issue's own ownership line rules out ("screen rows render the page header and never edit the layout").

So the split is:

- **`app/views/layouts/application.html.erb`** renders, in order, the header, the flash, the content column, and the dock. It is the only file here that reads a controller instance variable.
- **`app/views/layouts/_group_header.html.erb`** is the header: the mark slot, the group name with its chevron and pencil, and the avatar. Strict locals.
- **`app/views/layouts/_group_switcher.html.erb`** is the sheet the chevron opens. Strict locals.
- **`app/views/layouts/_group_tabs.html.erb`** is the three tab links, rendered once by the dock and once inside the header on desktop. Strict locals.
- **`app/views/shared/_page_header.html.erb`** is the pushed screen's title block, rendered *by the screen row* under the header. Strict locals `(title:)`. It is the one partial in this issue a screen row calls, which is what the issue's ownership line describes.

The back chevron is not in `_page_header`. Frame 4c puts it in the header row, in the same slot the group mark occupies, and that is the whole mechanism behind the fifth acceptance criterion: every title starts at the same x because one row lays out both. `_page_header` renders the title text; the header renders the chevron.

## How the layout knows

`Current` carries `session` and `brand` and no group; #227 adds one and is open, so the layout reads `@group`, exactly as the issue's technical notes allow. Two facts make that safe to read directly:

- **The test is `@group&.persisted?`, never `@group.present?`.** `GroupsController#new` assigns `Group.new`, and a failed `#create` re-renders `:new` with an unsaved group whose `name` is whatever was typed. `present?` would draw a header naming a group that does not exist and a switcher pointing at `group_path(nil)`.
- **Every controller nested under a group already sets it.** `EventsController`, `MembersController` and `RegistrationsController` each carry `before_action :set_group`; `GroupsController` sets it for `show`, `edit`, `update` and `destroy`. `AddressesController`, `UsersController`, `UserProfilesController` and the four unauthenticated controllers set none, which is the correct answer for them: they are the screens outside a group.

Which section is current, and whether tabs paint at all, are derived in `ApplicationHelper` from `controller_name` and `action_name` rather than declared per controller. Declaring it per controller would put this issue's diff into eight controllers that own their own rows; deriving it keeps the whole shell inside the files named above plus one helper.

- `group_shell_section` maps `groups` → `:home`, `events` and `registrations` → `:events`, `members` → `:members`, anything else → `nil`. That mapping is what gives a section's whole stack the same `aria-current="page"`: an event, its roster and the events list all answer `:events`, which frame 4c confirms by keeping Events highlighted on an event detail.
- `group_shell_tabs?` is false for the form actions, and the list is `new`, `create`, `edit`, `update` and `duplicate` — not the three the issue names. `create` and `update` re-render their form on a failed save, so a list keyed on the GET actions alone would draw tabs on exactly the screens a reader reaches by getting a form wrong.

## The icons

#238 adds the icon helper the issue's notes point at. It is open and is not a blocker of #244, so this branch inlines Heroicons outline paths in the three `app/views/layouts/` partials it owns: home, calendar and users for the tabs, chevron-down and chevron-up for the switcher, pencil-square for the edit link, chevron-left for the back control. Stroke 2 throughout, and the back chevron at stroke 3 per the issue's notes.

Sizes come from the components. `dock` sizes its own icons, and the header's icons sit inside `btn-sm` circles, so nothing here carries a pixel dimension the frames could disagree with. `stroke="currentColor"` everywhere, which is what keeps #235's third acceptance criterion true: no raw colour value reaches a view, and the organic theme recolours every icon from `app/assets/tailwind/application.css` when #257 lands.

When #238 lands, its row replaces these inline SVGs with helper calls. That is a smaller and more obvious diff than the reverse order would have been, and it is why building a local helper here would be the wrong move: two helpers of the same name is a merge conflict, and one helper in this branch is a file #238 owns.

The frames name no Heroicons component names — their icons are identified only by inline path data — so each path is copied from the Heroicons package itself and the export's geometry is only what confirms the right icon was picked.

## The type ladder, the one custom token

This is the one place the branch adds a token of its own, and it needs its reason stated because the standing rule for the beta is that daisyUI's defaults win on styling.

Tailwind's default scale supplies four of the eleventh acceptance criterion's eight rungs exactly — `text-xs` 12, `text-sm` 14, `text-base` 16, `text-xl` 20 — and none of the other four: 11, 13, 22 and 25 have no default utility. Taking the nearest default for each would collapse 11 into 12 and 13 into 14, which leaves six rungs where the criterion names eight and makes "detail facts" and "card facts" the same size.

So the eight go in `app/assets/tailwind/application.css` as `@theme` entries, named by what they are for rather than by their size, so a screen row reads `text-row-title` rather than `text-16` and #257 can retune a rung without a sweep:

| Utility            | px | For                                                                  |
|--------------------|----|----------------------------------------------------------------------|
| `text-record`      | 25 | a record title — the screen's whole subject                          |
| `text-hero`        | 22 | the hero card title; the group name and a pushed title from 640px up  |
| `text-shell`       | 20 | the group name and a pushed screen's title on mobile                  |
| `text-row-title`   | 16 | a list-row title                                                     |
| `text-fact`        | 14 | detail facts                                                         |
| `text-card-fact`   | 13 | card facts and buttons                                               |
| `text-meta`        | 12 | row meta and labels                                                  |
| `text-hint`        | 11 | helper text                                                          |

Everything else — colour, spacing, radius, shadow, component sizing — is stock daisyUI, per the beta decision above. This ladder is the single exception, and it is one because the criterion asks for it by name rather than because a frame drew it.

Only the rungs this branch's own markup uses get exercised here; the rest exist for the screen rows that follow, which is what "one set of utilities the screen rows reuse" asks for. That is the one place this plan builds past the case in front of it, and it is deliberate: a ladder introduced a rung at a time is a ladder whose rungs disagree.

`app/assets/tailwind/application.css` is also the file #257 rewrites for the organic theme. Nothing in that row touches `@theme` type entries, so the two changes do not collide.

## The brand name, in one place

"Groupifico" appears twice in the layout today, as the `<title>` fallback and as the `application-name` meta, and the header needs it a third time for the groups index and the screens outside a group. `Brand` already resolves per-domain facts from `request.domain` and carries `group_type` alone; a `name` reading from a map of the same shape is where #223 will swap it per domain, so the third reader goes there rather than into the layout. Three callers, no speculative generality: a constant is being de-duplicated, not prepared for.

Frame 2a heads the groups index "Your groups" instead. The issue's technical notes say the brand, and the notes are what this row is built against; the frame's own string is a screen-level title and belongs to #247's row, which owns that view.

## What happens to Log out, Log in and Start a group

The navbar is the only place any of the three appears, and no spec clicks any of them — checked across `spec/`.

- **Log out** moves to the Me screen, which is #254 and is open. Until it lands there is no control that ends a session. That is a real gap and this branch opens it, so it is stated here rather than discovered: `DELETE /session` still answers, and #254 is the row that gives it a button. The alternative — keeping a log-out control in the header — would put on the header something the frames draw on Me, and #254 would have to remove it again.
- **Log in** already has a link on the sign-up form, "Already have an account? Log in".
- **Start a group** has no counterpart on the sign-in form, so removing the navbar leaves `/session/new` with no route to sign-up at all. `app/views/sessions/new.html.erb` gets the mirror of the line the sign-up form already carries. That file is #236's row to redesign; a one-line link is not that redesign, and leaving a dead end for one merge is worse than the overlap.

## The switcher

daisyUI's `modal` with `modal-top`, which is the component whose behaviour matches frame 2d's sheet pulled down from the header over a dimmed screen — the dim is the component's own backdrop rather than a colour this branch picks. A `<dialog>` underneath it, so it takes the top layer and closes on Escape without script, and so axe reads a real modal's focus handling where it cannot read a `<details>` pretending to be one.

A Stimulus controller opens it, closes it and flips the chevron between down and up, which is the one piece of state beyond open and closed. Not a route: frame 2d draws it as an overlay on any group screen.

Each row is a group with its tag and its next event, and nothing else. The tag reads `owner` where `Member#owner?` answers true and `paused` where the membership's status is; both come from the reader's own `Member` row, not from a policy call — a policy asks "may this reader act", where the tag says "what is this reader here".

The next event is `group.events.upcoming.order(:starts_at).first`, and the switcher takes the whole collection as a local so the layout does the loading. Frame 2d draws its rows without that line and puts the "next: Tue 2 Sep" meta on the 2a index cards instead; the issue's first acceptance criterion asks for the next event on the switcher row, and an acceptance criterion is the gate this branch is measured against.

Rows carry no `dom_id`: `spec/requests/groups_spec.rb` asserts `group_<id>` is absent from the *index*, which has no switcher, but a navigation list is not a record listing and giving its rows record ids would make that assertion depend on which page it runs against.

The chevron is absent for a reader with one group, so the switcher is not rendered at all there — not rendered rather than hidden, since an empty overlay is a focus trap with nothing in it.

## The desktop shell

One breakpoint, `sm`, and frames 6a and 6b change three things at it and nothing else: the column caps and centres, the three tab links move out of the dock and into `navbar-end`, and the group name and a pushed title step from `text-shell` to `text-hero`. The frames' own avatar and padding growth is design detail rather than structure and is left to the components.

The cap is 640px, which the seventh acceptance criterion states outright and which Tailwind 4 has no named `max-w-*` for, so it is written as an arbitrary value on the one element that carries it.

The ground does not change. daisyUI paints `:root` from `--color-base-100` already, which #243's plan established by reading the built stylesheet, so the centred column sits on the same surface with no `bg-*` of its own.

## The export's accessibility gaps are not the spec

The export's tab cells are bare `<div>`s with no link, no text and no `aria-label`; its switcher chevron is an unlabelled `<span>`; its avatars are empty `<span>`s. Every one of those fails the fourth, third and tenth acceptance criteria, which ask for tabs that link to a section root and carry `aria-current="page"`, an avatar that links to `/user/profile`, and a screen axe reports clean.

So the controls are built as controls: each tab an `<a>` with an `aria-label`, the switcher chevron a `<button>` with one, the avatar an `<a>` whose initials are its accessible name. A wireframe is a drawing of a layout, and where it and axe disagree about semantics, axe is the gate `bin/ci` actually runs.

## The spec

New file, `spec/system/group_shell_spec.rb`. Nothing under `spec/system` covers the group home or navigation between sections: `spec/system/groups_index_spec.rb` covers the index, `spec/system/group_refusal_spec.rb` a refusal flow, and the rest are the two matchers' own controls, the sign-in page and the authentication cycle. So this is a flow no file covers yet, per `.agents/testing.md`.

It asserts what a browser adds and nothing a request spec already reaches:

- the header and the dock **paint**, per the suite's matcher, on the group home;
- clicking the Events tab **lands** on `group_events_path` and the Members tab on `group_members_path` — a Turbo navigation, which is the assertion no request spec can make;
- the switcher **opens** on the chevron and its row leads to the other group;
- the screen has **no accessibility violations**, which is what catches an icon-only tab or the chevron and pencil having no accessible name — the one failure mode of an icon-only control, and unreachable from every other layer.

Which controls a given reader sees — the pencil for an owner, the chevron for a reader with two groups, nothing at all for a signed-out visitor — is `spec/requests/groups_spec.rb`'s assertion under the duplication rule, and the request specs get those cases rather than this file.

The paint targets are chosen the way `spec/system/groups_index_spec.rb` chooses `.btn-primary`: a class this markup itself carries, so Tailwind is certain to have compiled it. `.dock` and the header's own class, never `body` — light `base-100` is `oklch(100% 0 0)` and composites to 1.0 against the matcher's surface, so a correctly painted body reads as painting nothing.

## Steps

- Load the `daisyui-blueprint-mcp` skill, then run the daisyUI Blueprint MCP sequence for the shell: setup expert with one workflow id for the whole issue, rules enforcer, page architect for the header and dock, and component syntax expert for `navbar`, `dock`, `modal`, `menu`, `avatar` and `badge`.
- Add the eight `@theme` type rungs to `app/assets/tailwind/application.css`, and rebuild the stylesheet to confirm each compiles its `text-*` utility.
- Add `Brand#name`, and read the `<title>` fallback, the `application-name` meta and the header's brand text from it.
- Add `group_shell_section` and `group_shell_tabs?` to `ApplicationHelper`, with a helper spec covering the `registrations` → `:events` mapping and the `create`/`update` suppression.
- Watch that helper spec fail: drop `create` and `update` from the suppressed list and see the example that names them go red.
- Add `UserProfile#initials`, mirroring `#full_name`'s fallback to the email local-part, with a model spec covering a profile whose names are both blank.
- Write `layouts/_group_header.html.erb` with strict locals: a `navbar` whose leading slot holds either the `bg-primary` mark or the back chevron, then the group name, the switcher chevron and the pencil under their conditions, and the avatar linking to `user_profile_path`.
- Write `layouts/_group_switcher.html.erb` with strict locals, a `modal modal-top` over a `<dialog>` and a `menu` of rows, and the Stimulus controller that opens it, closes it and flips the chevron.
- Write `layouts/_group_tabs.html.erb` with strict locals, three icon links with `aria-current="page"` on the current section and an `aria-label` on each, so the dock and the desktop header render the same partial.
- Write `shared/_page_header.html.erb` with strict locals `(title:)`.
- Rewrite `layouts/application.html.erb`: the header, the flash under it, the capped column, the dock, and the `sm` breakpoint moving the tabs into the header.
- Delete `layouts/_navigation.html.erb`, and add the "Start a group" link to `app/views/sessions/new.html.erb`.
- Render the pushed-screen header from one existing screen — `groups/show` is the group home and `groups/edit` the pushed screen — so the back chevron and the title block are exercised by something before the screen rows land.
- Add `spec/system/group_shell_spec.rb`, covering paint, the two tab navigations, the switcher opening, and accessibility.
- Add the reader-dependent control cases to `spec/requests/groups_spec.rb`: the pencil for an owner and its absence for an administrator, the chevron for a two-group reader and its absence for a one-group reader, and no header at all for a signed-out visitor.
- Run the daisyUI Blueprint quality inspector with `auditIntent: "fix_changes"` over the changed templates, and judge its findings against the `daisyui-blueprint-mcp` skill.
- Verify the shell in headless Chromium per the `browser-verification` skill, in both themes and at both widths, reading the accessible names of the icon-only controls off the accessibility tree.
- Run `bin/ci`.

## Verification

- `bin/ci`
- `bin/rspec spec/helpers spec/models/user_profile_spec.rb spec/requests/groups_spec.rb` while iterating, since the browser suite is the slow half of the gate
- The built stylesheet grepped for the eight `text-*` utilities, proving each `@theme` rung compiled

`bin/ci` is this repository's one gate, per `.agents/gh-solo.md`. Its `Style: ERB` step runs `herb-lint` over the four new templates, its `Tests: Stylesheet` step builds the Tailwind output so a malformed `@theme` entry dies there rather than in a view, and its `Tests: System` step runs the browser suite the new spec joins.

What the gate cannot see: whether the shell reads like the frames. `bin/ci` proves the markup lints, the elements paint and axe is quiet, and none of that is a claim about structure or feel. The frames are read by eye, at both widths and in both themes, and the headless-Chromium pass named in the steps is the whole of that evidence — it reports nowhere, so its box is the record that it happened. Nor does any gate prove the ladder is *used* rather than merely compiled: a rung nothing references still emits a utility once `@theme` declares it.

## Open questions

None.

## Settled

- The frames' own tokens and measurements are not this application's. Decided: through the beta milestone the shell is stock daisyUI — its components, its semantic colour classes, its spacing and radii — and the frames are read for structure, order and which controls a reader sees. So a bottom bar of three icons is `dock` rather than a flex row rebuilt to the export's paddings, a pulled-down sheet is `modal modal-top`, an accent dot is `bg-primary`, and no pixel padding, radius or shadow from the export reaches a template. The one exception is the type ladder, which an acceptance criterion names in px and Tailwind's default scale cannot supply.
- The issue's ownership line reads as though `shared/_page_header` carries the pushed screen's whole header, back chevron included, while its fifth acceptance criterion puts the chevron in the group mark's slot, which is in the header the layout owns. Decided: the chevron is the layout's and the title text is the partial's. The criterion's own reason for existing is that every title starts at the same x, and two files cannot agree on an x.
- The frames and the issue disagree three times, and the issue wins each time, because an acceptance criterion is what this branch is measured against and a wireframe is a drawing. Frame 2d's switcher rows carry no next-event line, where the first criterion asks for one. Frame 2b's avatar is an unlabelled empty circle, where the third asks for the reader's initials linking to `/user/profile`. Frame 2a heads the groups index "Your groups", where the technical notes ask for the brand.
