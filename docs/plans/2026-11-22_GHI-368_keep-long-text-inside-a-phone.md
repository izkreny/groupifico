> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: keep every long member-typed text inside a phone (#368)

## Approach

A probe at 390px seeded every N1 field with a long one-word value ("Simpsoncalifragilisticexpialaciousannoyedgruntcious") and a long multi-word one ("The Extraordinarily Long Named Riverside Community Choir Of Greater Springfield"), then read each screen's sideways scroll and every element past the screen's edge. The table below is its result and the AC1 list: one row per screen, the fields it draws, the behaviour each gets, and whether the screen fits today. An email is one word by its format, so it is tested only as a long one-word value; a mobile is free text up to 50 characters, so it gets both.

**The rule: wrap by default, and trim only fixed-height chrome whose full value a tap reaches.** Three sources agree on it. Design systems wrap content and truncate as the exception: Carbon forbids truncating page titles and notifications, Atlassian says never to truncate, and Primer, Polaris and the HTML spec all reject a `title` tooltip as the way to a trimmed value, because touch and keyboard users never see one; the WCAG Reflow guidance's own example keeps the full text one link or control away. Mobbin's apps trim a workspace name in a header and an account menu's lines, wrap record headings, toasts and saved-address cards, and reach a trimmed value by tapping through, never by tooltip or long-press. Among the Rails examples, Fizzy's OAuth stylesheet wraps a long email inside a flex row with `overflow-wrap: anywhere`, and Zammad's stylesheet says why `anywhere` beats `break-word`: it lets a long word shrink the flex item instead of overflowing the row.

So a wrapped field takes Tailwind's `wrap-anywhere`, which needs no `min-w-0` beside it. Only two places trim: the header's group name and the Me menu's name and email, each a single line in chrome whose height is fixed. Both come from one helper, `trimmed` in `app/helpers/trim_helper.rb` (new), which draws the tag with `truncate` and a `title` carrying the whole value, so AC4's one place keeps the desktop's hover too. Fizzy's `tag.span(name, class: "overflow-ellipsis")` in its menu helper is the shape. The `title` is the desktop's extra, never the way in: with a second group, tapping the header's name opens the switcher, whose rows now wrap the full name; the Me menu's Edit profile row opens the Me screen, whose heading now wraps the full name, with the email whole in its field. A one-group member's header has no tap target, so their full group name reaches them only as the `h1`'s accessible name and `title`, which AC2 admits and the design systems do not; the PR raises that as a decision rather than adding a control nobody asked for.

That rule reverses two shipped trims: the Me screen's heading and the group form's saved address name now wrap. The group form also needs `min-w-0` on its "Where you meet" fieldset, which otherwise sizes to its content's min-content. AC4 covers trimming only; N3's "unify" over the wrapping sites is read narrowly, so a newly fixed site wraps with `wrap-anywhere` and the `break-words` sites that already fit stay as they are.

| Screen | Fields | Behaviour | Today at 390px |
| --- | --- | --- | --- |
| Header, every group screen | group name | trims, existing; a tap on it opens the switcher where there is one | fits |
| Group switcher, open | each group's name, beside its badges | wraps, new | 112px over with one word |
| Me menu, open | full name, email | trims, existing; Edit profile shows both whole | fits |
| Groups list | group name, beside its badges | wraps, new | 68px over with one word |
| Home's next-up card | event name, address name | wraps, new | 7px over with one word |
| Events list, Upcoming and To do tabs | event name, address name | wraps, existing | fits |
| Event screen | event name, address name and street, the credits' names, the roster's names | wraps; new for the address and the credits | 31px over with one word |
| Event screen, after Send again | the flash's member name | wraps, new | 66px over with one word |
| Event form, new, edit and duplicate | manager and place selects, the list's member names | the select's own box trims and its picker lists the whole option; names wrap, existing | fits |
| Address screen | name, street, area, home group's name, Used by event names | wraps, new | 301px over with one word |
| Address edit | address name | to be found by S9 | 13px over with one word, no element past the edge |
| Members list | full name, email, mobile | wraps, existing | fits |
| Member screen | full name, email, mobile, managed event names | wraps, new | 313px over with one word, 128px with many |
| Member edit | full name | to be found by S11 | 197px over with one word, no element past the edge |
| Me screen | full name; the sole-owner notice's and the delete sheet's group names | wraps; the name changes from trimming | the notice runs 29px past the edge with one word |
| Group form, edit | saved address name, address summary | wraps; the name changes from trimming | 197px over with one word, 238px with many |
| Sign-in link page | email | wraps, existing | fits |
| Sign-up confirmation | email, group name | wraps, existing | fits |
| Join page | group name | wraps, existing | fits |
| Every page's `<title>` | event, member, group or address name | whole value; the browser trims its own tab | not drawn in the page |

Each screen's examples go into the system spec that already covers it, two per screen, one per value kind, at `ViewportHelper::MOBILE` set before `visit`. Each asserts `horizontal_overflow` is `0` and, where the screen has a control beside the text, `gap_to_row_end` of that control is not negative, the half that catches a row clipped inside a card. A trimmed field's examples assert `truncated?` first, so the AC2 assertions after it cannot pass on text that fitted: the `title` holds the whole value, and the screen a tap reaches draws it untruncated.

## Steps

- ::S1:: Add `app/helpers/trim_helper.rb` (new) with `trimmed(text, tag_name = :span, **options)` drawing `truncate`, and move the trims that stay onto it: the header's three `h1`s in `app/views/layouts/_header.html.erb` and the name and email in `app/views/layouts/_me_menu.html.erb`; a refactor commit, the rendered classes unchanged
- ::S2:: Give `trimmed` the `title` carrying the whole value, with `spec/helpers/trim_helper_spec.rb` (new); a behaviour commit apart from S1
- ::S3:: Header and switcher: wrap each switcher row's group name in `app/views/layouts/_group_switcher.html.erb`, the badges kept whole; in `spec/system/group_shell_spec.rb` add the header's and the open switcher's examples, the header's trimmed name asserted by its `title` and by the open switcher drawing it untruncated
- ::S4:: Me menu and Me screen: wrap the heading in `app/views/user_profiles/_user_profile.html.erb` and the group names in the sole-owner notice and the delete sheet's sentence; in `spec/system/me_spec.rb` add the open menu's examples, its trimmed name and email asserted by `title` and by the Me screen drawing the name untruncated, and the Me screen's examples; the delete sheet's examples in `spec/system/account_deletion_spec.rb`
- ::S5:: Groups list: wrap the card title's name in `app/views/groups/_group.html.erb`, examples in `spec/system/groups_index_spec.rb`, the badge kept inside the card
- ::S6:: Home: wrap the next-up card's links in `app/views/events/_next_up.html.erb`, examples in `spec/system/group_home_spec.rb`
- ::S7:: Events list: examples for the Upcoming and To do tabs in `spec/system/events_list_spec.rb`, the row's pencil kept on the screen
- ::S8:: Event screen: wrap the address links and the credits in `app/views/events/_event.html.erb` and the flash's text in `app/views/layouts/_flash.html.erb`; examples in `spec/system/event_detail_spec.rb` for the screen, the open roster and the flash after Send again; examples in `spec/system/event_form_spec.rb` for the new, edit and duplicate forms
- ::S9:: Address screen and its edit: wrap the heading and the facts in `app/views/addresses/_address.html.erb` and the Used by names in `app/views/addresses/show.html.erb`, Correct kept on the screen; find the edit screen's 13px with a `Range` over each text node, fix it at its source; examples in `spec/system/address_detail_spec.rb` and `spec/system/address_edit_page_spec.rb`
- ::S10:: Members list and member screen: wrap the heading, email, mobile and managed event names in `app/views/members/show.html.erb`, the pencil and the Email and Call buttons kept on the screen; examples in `spec/system/members_list_spec.rb` and `spec/system/member_detail_spec.rb`
- ::S11:: Member edit: find the 197px the same way as S9, fix it at its source, examples in `spec/system/member_edit_page_spec.rb`
- ::S12:: Group form: add `min-w-0` to the "Where you meet" fieldset and wrap the saved address name and summary in `app/views/groups/_form.html.erb`, examples in `spec/system/group_form_spec.rb`, the pencil kept on the screen
- ::S13:: Entry screens: examples for the sign-in link page in `spec/system/authentication_spec.rb`, the sign-up confirmation in `spec/system/sign_up_spec.rb` and the join page in `spec/system/join_page_spec.rb`
- ::S14:: List the table's screens in the PR body under AC1, behaviour and spec file for each, corrected for whatever S9 and S11 find, and post the one-group header as a numbered decision for the owner

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-22_GHI-368_keep-long-text-inside-a-phone.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-22_GHI-368_keep-long-text-inside-a-phone.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/helpers/trim_helper_spec.rb` passes, its `title` example seen failing against S1's helper, before S2
- ::V4:: `mise exec -- bin/rspec spec/system/group_shell_spec.rb spec/system/me_spec.rb spec/system/account_deletion_spec.rb spec/system/groups_index_spec.rb spec/system/group_home_spec.rb` passes; the examples of a screen that overflows today, and the Me screen's untruncated-name assertion, are seen failing against `main`'s views; those that pass on `main` (the header's, the menu's and every multi-word example here) are seen failing with `truncate` taken out of `trimmed` for a trimmed field, and with the field's wrap class replaced by `whitespace-nowrap` for a wrapped one
- ::V5:: `mise exec -- bin/rspec spec/system/events_list_spec.rb spec/system/event_detail_spec.rb spec/system/event_form_spec.rb` passes; the event screen's and the flash's one-word examples are seen failing against `main`'s views; the events list's, the forms' and the roster's, which pass on `main`, are seen failing with the row's name, the list's names and the roster cell's wrap class replaced by `whitespace-nowrap`
- ::V6:: `mise exec -- bin/rspec spec/system/address_detail_spec.rb spec/system/address_edit_page_spec.rb spec/system/members_list_spec.rb spec/system/member_detail_spec.rb spec/system/member_edit_page_spec.rb spec/system/group_form_spec.rb` passes; the address, address edit, member, member edit and group form one-word examples and the member's and group form's multi-word ones are seen failing against `main`'s views; the members list's and the remaining multi-word ones, which pass on `main`, are seen failing with the field's wrap class replaced by `whitespace-nowrap`
- ::V7:: `mise exec -- bin/rspec spec/system/authentication_spec.rb spec/system/sign_up_spec.rb spec/system/join_page_spec.rb` passes; these pass on `main`, and each is seen failing with its heading's `break-words` replaced by `whitespace-nowrap`
- ::V8:: `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views and `mise exec -- bin/rubocop` over the changed Ruby files exit 0
- ::V9:: `mise exec -- bin/ci` passes, browser suite included

The specs prove nothing scrolls sideways and no control leaves the screen at 390px, at the default text size; they cannot judge whether a heading wrapped over four lines reads well, and they do not check 200% text size, which WCAG's F69 names and the owner may want as its own issue.

## Open questions

None.

## Settled

- None yet.
