> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Build the styleguide page

## What the page draws

Every partial under `app/views/events/` and `app/views/shared/`, since that is the set the drift spec lists: `events/_counts`, `_event`, `_form`, `_next_up`, `_roster`, `_row`, `_rsvp`, and `shared/_confirm_sheet`, `_errors`, `_page_header`. On top of those, the items the issue names that are not partials under either directory: `layouts/_flash` as notice and as alert, `AppFormBuilder#field` with a hint and with an error, and every entry of `IconsHelper::ICONS` with its name beneath it. The buttons need no section of their own, because every variant the application draws already arrives through a partial: the RSVP pills, the confirm sheet's `btn-error`, the card's ghost icon buttons, the roster's `btn-sm` and the form's `btn-primary` submit.

Each section is written once and rendered twice, through `styleguides/_section.html.erb` as a `render layout:` whose block receives the theme name, so the light and dark twins sit side by side and cannot drift apart. Each twin is a `data-theme` wrapper painting `bg-base-100 text-base-content`, which is how daisyUI scopes a theme to a subtree. Ids a twin mints itself carry the theme name: the confirm sheet's `id:` and the field form's `namespace:`.

## In memory, and what that leaves empty

The sample records are built in the template with `.new`, as the issue asks, and each carries an id because every partial builds paths from its records, and `ActiveRecord::Integration#to_param` answers nil without one. The ids are negative. An id on an unsaved owner turns off the null scope Active Record gives a new record's `has_many`, so the partials' own queries run with it; probed in development, `Event.new(id: 1)` counted 22 seeded registrations belonging to the real event 1. A negative id is one no saved row carries, so those queries find nothing rather than somebody's development data.

What reads through SQL therefore renders its empty state: `Event#answer_counts` groups in the database, so `events/_counts` draws its "Nobody asked yet" line and never the count tags; `Event#roster` preloads through a relation, so `events/_roster` draws "Nobody is on the list yet"; and `EventsHelper#said_yes_line` draws nothing. `Member#full_name` goes through `has_one :profile, through: :user`, which an unsaved member cannot answer, so no sample event names a manager or a creator and `event_credits` draws nothing either. The first open question below is whether that is the page the owner wants.

## Permission

Every sample record sits in a group no `Member` row belongs to, so `ApplicationPolicy#membership` is nil and every real rule refuses: `events/_rsvp` would draw nothing at all, the RSVP pills the issue lists included. So `StyleguidesController` answers `allowed_to?` itself, privately and always yes, which Action Policy's `helper_method :allowed_to?` hands to the views. The page shows every control a permitted reader sees; who is permitted stays the policies' and their specs' business.

The action authorizes nothing, since there is no record anybody owns, so it carries `skip_verify_authorized`. `.agents/rails-style.md` names every such skip and calls a new one a conversation, so this one joins its list, and the second open question asks the owner to confirm it. The page keeps `require_authentication`: nothing on it needs a reader, but opting out would add it to the signed-out surface `.agents/testing.md` lists, and a signed-in developer is the only reader it has.

## Names, route and layout

`resource :styleguide, only: :show`, drawn `if Rails.env.development?` beside the `RailsIcons` mount that uses the same guard. The issue's technical notes say `StyleguideController`; a singular resource routes to a plural controller, and every singular resource here already follows that (`resource :session` to `SessionsController`), so it is `StyleguidesController`, with `app/views/styleguides/`.

The page takes a layout of its own, `layouts/styleguides.html.erb`, which Rails picks by the controller's name: `layouts/head` and the `yield`, nothing else. The application layout would draw the flash samples a third time in its own flash slot, and its shell of header, switcher and tabs is a screen's chrome rather than a component to judge.

## Specs

`spec/requests/styleguides_spec.rb` holds both. The route guard is asserted the way `spec/requests/rails_icons_spec.rb` asserts its own: `GET /styleguide` answers 404 in test, signed in and signed out. The drift example lists `app/views/{events,shared}/_*.html.erb` and asserts each partial's render name appears in `app/views/styleguides/show.html.erb`. It sits in the request spec because it has no layer of its own: `spec/views` is banned by `.agents/testing.md`, and a top-level describe with no type trips `RSpec/DescribeClass`.

No system spec: the criterion keeps the route out of test, so no browser in the suite can reach the page. The headless Chromium check in `## Verification` is its browser pass, run in development.

## Steps

- Draw the route and add `spec/requests/styleguides_spec.rb` with the two route examples.
- Add `StyleguidesController#show`: `skip_verify_authorized`, `flash.now` notice and alert samples, and the private `allowed_to?`; add the skip to the list in `.agents/rails-style.md`.
- Add `layouts/styleguides.html.erb` and `styleguides/_section.html.erb`.
- Build `styleguides/show.html.erb`: the negative-id sample records, then one section each for the page header, the flash, the hero card and the record facts, the compact rows in every event status, the counts, the RSVP question and answer, the roster, the fields and the error summary, the event form, the confirm sheet, and the legend icons.
- Add the drift example to `spec/requests/styleguides_spec.rb`, watched failing on a throwaway partial.
- Check the page in headless Chromium in development, run `bin/ci`, and tick the boxes.

Every step that writes markup goes through the daisyUI Blueprint MCP server first, per the epic: the `daisyui-blueprint-mcp` skill, then the server's setup, rules and component-syntax tools, the markup, and its quality inspector afterwards.

## Verification

- `bin/ci` is green
- `bin/rspec spec/requests/styleguides_spec.rb` passes, its drift example watched failing with a throwaway `app/views/shared/_probe.html.erb` present and its route examples watched failing with the development guard dropped
- `/styleguide` in development, in headless Chromium, answers 200, draws every section under both `data-theme="light"` and `data-theme="dark"` with the two twins' `base-100` computing to different colours, logs no console error, and axe reports no WCAG 2.1 AA violation

What these gates cannot see is whether either theme looks right, which is what the page is for and is the owner's to read. Nor do they see the empty states above as a gap: they render exactly what the in-memory rule allows.

## Open questions

- The in-memory rule leaves the count tags, the roster's rows and the said-yes line empty, because each reads through SQL. Sample rows created inside a transaction rolled back after rendering would draw all three, at the price of the criterion's "rather than the database". Assumed: in memory, as the criterion says.
- The page answers `allowed_to?` yes for every rule and adds a permanent `skip_verify_authorized`, which `.agents/rails-style.md` calls a conversation. Assumed: both, with the skip added to that file's list.

## Settled

- Settled in the terminal on 2026-09-14, after the headless Chromium gate ran from a session scratchpad: should the page be checked by RSpec system specs instead? Decided by the owner: yes, in `spec/styleguide/`, tagged `type: :system`, kept out of a bare `bin/rspec` and of `bin/ci` by the exclude pattern in `.rspec`, and run with `bin/rspec spec/styleguide`. The page is therefore routed in development and test (`if Rails.env.local?`), the issue's first criterion reads "not routed in production", and the route examples in `spec/requests/styleguides_spec.rb` become the signed-in 200 and the signed-out redirect.
