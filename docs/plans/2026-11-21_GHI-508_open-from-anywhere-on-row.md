> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: open a member or event from anywhere on its row (#508)

## Approach

Both rows take the next-up card's stretched link from `app/views/events/_next_up.html.erb`: the name's link gains `after:absolute after:inset-0`, so its `::after` covers the nearest positioned ancestor, and every control on the row takes `relative z-1` to sit above that overlay. N2 is settled by reading the vendored plugin: `app/assets/tailwind/daisyui.mjs` gives `.list-row` `position: relative`, so the `<li>` is already the containing block and neither row needs a class of its own for it; the row's divider is the `<li>`'s own `::after`, a different element from the link's, so the two never meet.

The controls lifted are every link or button on a row other than the name. On the member row those are Call, Email and the edit pencil. On the event row they are the address's map link in the meta line, which AC3 does not list but which the overlay would otherwise swallow, and the edit pencil; the answer buttons already carry `relative z-1` from `app/views/events/_response.html.erb`, whose `WHY:` comment is corrected to say the rows stretch their link too. The role badges, the "not signed in yet" mark, the avatar, the status icons and the registration's icon are not controls, so pressing them is pressing the row.

No markup is added, so each row still has exactly one link to its screen and the Tab order is unchanged (AC4). The member row's `flex flex-col` column stays as it is; with the overlay in place it no longer decides where the row opens (N3).

## Steps

- ::S1:: In `app/views/members/_member.html.erb`, add `after:absolute after:inset-0` to the name's link and `relative z-1` to Call, Email and the pencil, with a `WHY:` comment on the stretched link in the words the next-up card uses
- ::S2:: In `app/views/events/_row.html.erb`, add `after:absolute after:inset-0` to the name's link and `relative z-1` to the address's map link and the pencil, with the same `WHY:` comment; in `app/views/events/_response.html.erb`, correct the answer buttons' `WHY:` to name the rows beside the next-up card
- ::S3:: In `spec/system/members_list_spec.rb`, add "lands on a member's screen from anywhere on their row", pressing the avatar by its coordinates (AC1), and "keeps every control on a row above the link to its member", asserting Call, Email and the pencil are each topmost at their own centre (AC3)
- ::S4:: In `spec/system/events_list_spec.rb`, add "lands on an event's screen from anywhere on its row", pressing the status icon by its coordinates (AC2), and "keeps every control on a row above the link to its event", asserting the map link, the pencil and each answer button are topmost at their own centre (AC3)
- ::S5:: In `spec/requests/members_spec.rb` and `spec/requests/events_spec.rb`, add an example that a row carries exactly one link to its member's or event's screen, its name (AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-508_open-from-anywhere-on-row.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-508_open-from-anywhere-on-row.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/system/members_list_spec.rb spec/system/events_list_spec.rb` passes; the AC1 and AC2 examples are seen failing against `main`'s partials; the AC3 examples, which pass on `main` where nothing covers the controls, are seen failing against the branch with `relative z-1` removed from Call on the member row and from the map link on the event row
- ::V4:: `mise exec -- bin/rspec spec/requests/members_spec.rb spec/requests/events_spec.rb` passes; the AC4 examples, which pass on `main`, are seen failing against the branch with the avatar wrapped in a second link to the member's screen and the status icon wrapped in a second link to the event's screen
- ::V5:: `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed partials and `mise exec -- bin/rubocop` over the changed specs exit 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The specs prove where a press lands and that no control is covered; they cannot see how the row feels to press, such as the name underlining wherever the pointer hovers over the row, which the next-up card already does and is the owner's to judge.

## Open questions

None.

## Settled

- None yet.
