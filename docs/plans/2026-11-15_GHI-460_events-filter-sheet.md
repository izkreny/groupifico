> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: build the events filter sheet (#460)

## Approach

What a member is looking at becomes one value object, `Event::Filter` in `app/models/event/filter.rb` (new), built for the reader from the request: URL parameters when any are present, otherwise the cookies (AC9, AC10). It holds the list (`nil` for upcoming, `past`, `canceled`), the categories, the answers and the managed flag. It drops any value the list does not offer, the managed flag included for a member who manages none of the group's events, the way `EventsHelper#roster_order` drops an order (AC3, AC11). It narrows a relation, answers `narrowed?` for the funnel (AC7), and names its chips. "Not answered" means on the event's list with a held place or a waiting request: an event the reader is not listed on has no answer of theirs, so no answer filter matches it.

Applying writes, and it goes through a resource of its own, as the roster order does: `resource :event_filter, only: :update, module: :groups` routes to `Groups::EventFiltersController#update` (new). It stores the offered values in permanent cookies and redirects to the events list, so a URL-borne filter never reaches the cookies unless the member applies it (AC10). A chip's ✕ submits the applied picks less that one through the same update, so removing a filter saves like applying one (AC5).

`EventsController#index` asks `Event::Filter` for its list and replaces `events/_scope_menu` (delete) with an "Events" title, the funnel and the chip row (AC1, AC5, AC6). The sheet is a `modal-bottom` dialog opened through the existing `dialog` controller, headed like the join link's (AC2). Its count needs no endpoint of its own: `events_filter_controller.js` (new) points a Turbo Frame around "Show N events" at the events list's own URL carrying the sheet's picks, which the index already reads per AC10, so the count is the same query the list would run (AC4). The same controller's Reset returns the sheet's inputs to Upcoming with no filters and refreshes the count (AC8).

Cookies are per browser, not per group, like the roster order: a category or an answer means the same thing in every group, and the managed flag is dropped wherever it is not offered.

## Steps

- ::S1:: Add `Event::Filter` in `app/models/event/filter.rb` (new) with its spec in `spec/models/event/filter_spec.rb` (new): URL parameters over cookies, unoffered values dropped, the managed flag offered only to a member managing one of the group's events, narrowing by category, answer and manager, `narrowed?`, and the chips in sheet order (AC3, AC7, AC9, AC10, AC11)
- ::S2:: Route `resource :event_filter, only: :update, module: :groups` and add `Groups::EventFiltersController#update` (new), authorized as reading the group, storing only offered values and redirecting to the events list; cover it in `spec/requests/groups/event_filters_spec.rb` (new) with the signed-in and signed-out pairing, a stored filter, a dropped unoffered value and a member refused the group (AC9, AC11)
- ::S3:: Make `EventsController#index` read the list and its narrowing from `Event::Filter`, with an empty-list sentence for a narrowed list; extend `spec/requests/events_spec.rb` for a cookie applied, a URL parameter winning for that request while the cookies stay as they were, an unoffered value ignored, and the Other group offered only to a manager (AC3, AC9, AC10, AC11)
- ::S4:: Add the meanings `filter: "funnel"`, `reset: "arrow-path"` and `apply: "check"` to `IconsHelper::ICONS`, each with its `StyleguidesHelper::ICON_USES` entry
- ::S5:: Replace `events/_scope_menu` (delete) in `app/views/events/index.html.erb` with the title, the funnel, `app/views/events/_filter_chips.html.erb` (new) and `app/views/events/_filter_sheet.html.erb` (new), driven by `app/javascript/controllers/events_filter_controller.js` (new); the funnel is `text-primary` when `narrowed?` and dimmed with a theme colour otherwise, every chip is primary, only filter chips carry a ✕, and the sheet's buttons sit in a `flex-wrap-reverse` row so "Show N events" stacks first (AC1, AC2, AC4, AC5, AC6, AC7, AC8)
- ::S6:: Point the styleguide's Dropdown section in `app/views/styleguides/show.html.erb` at a dropdown that remains, since its sample was the scope menu
- ::S7:: Extend `spec/system/events_list_spec.rb`: the sheet opens from the funnel and from a chip, picks update the count, applying narrows the list and shows chips, a chip's ✕ removes its filter alone, Reset returns to Upcoming, the choice survives a new visit, the funnel paints muted and primary, the buttons stack Show-first on a narrow viewport, and axe passes with the sheet open in organic and organic-dark (AC1, AC2, AC4, AC5, AC6, AC7, AC8, AC9, AC12)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-15_GHI-460_events-filter-sheet.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-15_GHI-460_events-filter-sheet.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/event/filter_spec.rb` passes; the AC11 examples are seen failing against a filter that keeps every value it is given, and the AC10 example against one that reads the cookies first
- ::V4:: `mise exec -- bin/rspec spec/requests/groups/event_filters_spec.rb spec/requests/events_spec.rb` passes; the URL-parameter example is seen failing against an index that stores what it reads, and the Other group example against a sheet that offers it to everyone
- ::V5:: `mise exec -- bin/rspec spec/system/events_list_spec.rb` passes; the count example is seen failing with the frame's `src` left unset, the stacking example against a row without `flex-wrap-reverse`, and the muted-funnel example against a funnel that is always primary
- ::V6:: `mise exec -- bin/rspec spec/helpers spec/styleguide` passes
- ::V7:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The specs prove the sheet filters, counts, saves and stacks, not that it reads as the artifact's version 2 or that the chip row and funnel balance the header: that is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

- ::Q1:: Should the events list remember a member's filters between visits? Settled by the owner on 2026-11-16: no, filters live in the URL alone. A remembered filter that a link visit left untouched read as a hidden second state, and Mobbin showed no app saving filters silently. So the sheet is a GET to the events list, a chip's ✕ is a link, and the controller, route and cookies of S2 go.
