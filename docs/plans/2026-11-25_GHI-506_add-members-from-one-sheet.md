> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add members from one sheet (#506)

## Approach

The members list's join link dialog becomes the "Add member" dialog, and its trigger becomes the list's one +. The dialog moves from `app/views/groups/_join_link_dialog.html.erb` (delete) to `app/views/members/_add_dialog.html.erb` (new), with the id `add_member_dialog`, since it now belongs to the members list rather than to the link. `app/views/members/index.html.erb` passes it to `shared/filter_bar` as `actions` and passes no `add_path`, so the bar draws one + and `app/views/shared/_filter_bar.html.erb` stays as it is, the events list keeping its own `add_path`.

The "Add member" heading, its x and the invite form sit outside the `join_link` Turbo Frame, and only the "Share join link" section sits inside it. Creating, regenerating or deleting the link swaps the frame's content, so anything inside it is redrawn: a half-typed address there would be wiped. `app/views/groups/_join_link.html.erb` therefore loses its own heading row for an `h3` "Share join link", and the dialog takes `aria-labelledby` from the new `h2`.

The invite form posts to the existing `members#create`, built on the `unattached` member the index already makes, so inviting from the sheet is the member form's invitation by construction (AC3). A refused address, such as one already in the group, lands on `members/new` with its error, as the form's does today, so that page and its route stay. The create's notice names the address, "Invitation sent to {email}.", which is what says who was invited for both ways in. The email field is labelled by its section heading, as the link's input is labelled by its own, and its hint is the AC4 line.

AC6 needs no new focus rule: each link state's primary control keeps the `autofocus` that Turbo's frame swaps rely on, and `showModal` focuses the first `autofocus` descendant, which is that control below the email field. The AC6 example proves the email field is not focused, and is watched failing with `autofocus` added to the field. Should Chromium land elsewhere, `autofocus` moves onto the `dialog` element itself, which the frame swaps leave alone.

## Steps

- ::S1:: Turn the join link dialog into the "Add member" dialog behind one +: move it to `app/views/members/_add_dialog.html.erb` (new) with the `:new` icon named "Add member", the `h2` and x outside the frame, and `app/views/groups/_join_link.html.erb` headed by an `h3` "Share join link"; pass it as `actions` from `app/views/members/index.html.erb` with no `add_path`; update the members bar sample, the `rendered_by` map in `spec/requests/styleguides_spec.rb`, and the `new`, `invite_link` and `delete` notes in `app/helpers/styleguides_helper.rb`; in `spec/system/members_list_spec.rb` open the dialog from the + and drop "lands on the invite form from the +", whose behaviour is removed; request examples for AC1 and AC5 in `spec/requests/members_spec.rb`, the "offers no +" example repointed at the + button
- ::S2:: Add the "Invite by email" section above the link: an email field and a "Send invitation" button with the `send_invite` icon posting to `group_members_path`, each section's AC4 line beneath it, and the create's notice naming the address in `app/controllers/members_controller.rb`, `spec/system/member_new_page_spec.rb` following it; request examples for AC2's sections and AC4's lines, browser examples in `spec/system/members_list_spec.rb` for inviting from the sheet (AC3) and for the email field staying unfocused (AC6), the paint and axe examples' selectors narrowed to the link section now that two forms share the dialog, and the `send_invite` note updated

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-25_GHI-506_add-members-from-one-sheet.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-25_GHI-506_add-members-from-one-sheet.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/members_spec.rb spec/requests/styleguides_spec.rb` passes; the AC1 example is seen failing against `main`'s view, the repointed AC5 example is seen failing with the dialog rendered outside `if may_add`, and the AC2 and AC4 examples are seen failing against S1's view
- ::V4:: `mise exec -- bin/rspec spec/system/members_list_spec.rb spec/system/member_new_page_spec.rb` passes, every join link example opening the dialog from the +; the AC3 example is seen failing against S1's view, and the AC6 example, which passes once S2 lands, is seen failing with `autofocus` added to the email field
- ::V5:: `mise exec -- bin/rspec spec/styleguide` passes, since `bin/ci` never runs it and the styleguide draws the join link and the members bar
- ::V6:: `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views and `mise exec -- bin/rubocop` over the changed Ruby files exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove where focus lands in Chromium; they cannot see whether a real phone's keyboard stays down on opening, nor how the taller sheet sits above a phone's own browser chrome.

## Open questions

None.

## Settled

- None yet.
