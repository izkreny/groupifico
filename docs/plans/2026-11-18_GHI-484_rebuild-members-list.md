> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: rebuild the members list like the events list (#484)

## Approach

The events list's screen is lifted first, unchanged, into shared pieces, and only then does the members list take them, so the refactor and the new behaviour land as separate commits and the events specs guard the first one (AC9). What both filters need moves from `Event::Filter` into `app/models/concerns/list_filter.rb` (new): the tab links that keep every filter on, the chips' remove links, `cleared` and the funnel's `narrowed?`, each list naming its own tabs and filters. The views split the same way: `app/views/shared/` takes the title row, the tabs, the chip row, the sheet, the form and one fieldset of picks, each given the list's path, its noun and its own fields, so every styling value the two lists share is written once in one of them, and a value still repeated after that becomes a `@theme` variable in `app/assets/tailwind/application.css` (AC10). `app/javascript/controllers/events_filter_controller.js` (delete) becomes `app/javascript/controllers/filter_controller.js` (new), the same code under a name both lists can use.

`Member::Filter` in `app/models/member/filter.rb` (new) reads the tab from `status`: none for Active, then `paused`, `pending` and `inactive`, the last two offered only where `MemberPolicy#oversee?` holds, which the controller asks and passes in, so a tab the reader is not offered is dropped and the list opens on Active (AC2, AC7, AC8). Its filters are `role[]` over `Role::NAMES`, matching a member holding any of them through the `roles` rows, `manages=1` for a member who manages one of the group's events, and `not_signed_in=1` for an overseer, reading `first_signed_in_at` as the row's mark does (AC3, AC4). Each filter answers its tab counts from the filtered relation before the tab narrows it: one `group(:status).count` for members, one count per list for events, so a tab names what it would list with every chip on, zero included (AC12). The tabs partial writes the count as "Active (19)" with the noun in a screen-reader-only span, so the link's name is "Active (19 members)" while the visible label stays inside it (AC13).

## Steps

- ::S1:: Refactor, behaviour unchanged: extract `ListFilter` from `Event::Filter`, and lift `events/_filter_tabs`, `events/_filter_chips`, `events/_filter_sheet` and `events/_filter_form` (each delete) plus the title row and the list's closing line into `app/views/shared/` partials, the event-only picks into `app/views/events/_filter_fields.html.erb` (new), and `app/javascript/controllers/events_filter_controller.js` (delete) into `app/javascript/controllers/filter_controller.js` (new); the styleguide's Events filter section and its `rendered_by` map in `spec/requests/styleguides_spec.rb` follow (AC9, AC10)
- ::S2:: Give the events tabs their counts: `Event::Filter` separates narrowing from the tab so it can count each list under the filters that are on, and the shared tabs partial writes "Upcoming (4)" named "Upcoming (4 events)", with examples in `spec/models/event/filter_spec.rb` and `spec/requests/events_spec.rb` (AC12, AC13)
- ::S3:: Add `Member::Filter` with `spec/models/member/filter_spec.rb` (new): the offered tabs per reader, dropped values, role, manages and not-signed-in narrowing, chips in sheet order, `narrowed?` and the per-status counts (AC2, AC3, AC4, AC7, AC8, AC12)
- ::S4:: Make `MembersController#index` read `Member::Filter`, its `inactive` refusal becoming AC8's ignore, and rewrite the index examples of `spec/requests/members_spec.rb` for the tabs, the filters and the ignored values, removing the count, Invite and inactive-toggle examples whose features go (AC1, AC2, AC4, AC7, AC8)
- ::S5:: Rebuild `app/views/members/index.html.erb` from the shared partials: the "Members" title with the join link, an icon-only "+" named "Invite member" and the funnel, the tabs, the chips, the "Filter members" sheet with `app/views/members/_filter_fields.html.erb` (new), and an empty sentence per tab and for a narrowed list (AC1, AC2, AC3, AC4, AC5, AC6)
- ::S6:: Draw the members filter's fields in the styleguide beside the events', so `spec/requests/styleguides_spec.rb` finds every new partial rendered
- ::S7:: Extend `spec/system/members_list_spec.rb` for the title row, the tabs keeping filters, the sheet's count, applying, chips, Clear all, the funnel's two inks, the buttons stacking, and axe with the tabs and with the sheet open in organic and organic-dark, and `spec/system/events_list_spec.rb` for its tabs' counts and names (AC1, AC2, AC3, AC5, AC6, AC11, AC12, AC13)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-18_GHI-484_rebuild-members-list.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-18_GHI-484_rebuild-members-list.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/event/filter_spec.rb spec/models/member/filter_spec.rb` passes; every new example is seen red, the count examples against counts taken before the filters narrow, the AC8 examples against a filter that keeps every tab and value, the role, manages and not-signed-in examples against a filter that ignores each, and the default-tab example against one that opens on Paused
- ::V4:: `mise exec -- bin/rspec spec/requests/members_spec.rb spec/requests/events_spec.rb spec/requests/styleguides_spec.rb` passes; the new members examples are seen red on `main`'s index, the ignored Pending and Inactive examples against a filter that offers them to everyone, and the tab-count examples against tabs without counts
- ::V5:: `mise exec -- bin/rspec spec/system/members_list_spec.rb spec/system/events_list_spec.rb` passes, the events list's existing examples unchanged by S1; the members sheet's count example is seen red with the frame's `src` left unset, the stacking example against a row without `flex-wrap-reverse`, the muted-funnel example against a funnel that is always primary, and the tab-name examples against tabs without the screen-reader noun
- ::V6:: `mise exec -- bin/rspec spec/helpers spec/styleguide` passes
- ::V7:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V8:: `mise exec -- bin/ci` passes, browser suite included

The specs prove the members list filters, counts and stacks as the events list does, not that the two lists read as one pattern on screen or that no shared value is still written twice (AC10): those are the owner's to judge from the diff and the screenshots the round posts.

## Open questions

None.

## Settled

None yet.
