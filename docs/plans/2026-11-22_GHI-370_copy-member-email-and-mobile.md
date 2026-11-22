> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: copy a member's email and mobile (#370)

## Approach

The join link's Copy button already settles how a copy confirms itself: the button swaps to a check, turns back after two seconds, and a status line tells a screen reader, showing only when the copy fails. The member screen's copy buttons reuse that behaviour through `app/javascript/controllers/clipboard_controller.js`, per N2, rather than a second controller.

Reuse forces one refactor first, because the controller is written for the join link alone: it reads the copied text from an input's `value`, hard-codes "Link copied" and the failure sentence, and toggles `btn-primary` and `btn-secondary`, which would paint a ghost icon button. The copied text becomes a Stimulus `content` value, the shape every basecamp clipboard controller uses (Campfire, Fizzy and Writebook share one controller, which takes the text as `data-copy-to-clipboard-content-value`). The two sentences become `copied` and `failed` values, and the colour swap becomes the `idle` and `done` classes, which the join link passes and the member rows leave out. The join link partial is in the diff only to pass those, with nothing it draws or does changed.

Each contact `dd` becomes the controller's element. Inside it, one flex row holds the value, the copy button right after it, and the Email or Call button pushed to the row's end with `ms-auto`, so a short value keeps its copy button beside it. Below that row sits the status line. As a fourth flex child the visible failure line would squeeze the row, and as a sibling it stays out of it. The copy button is icon-only, `copy` swapping to `copied` per N3, and is named "Copy {name}'s email" or "Copy {name}'s mobile".

The email then trims through `trimmed`, per N1, capped at `max-w-3/4` of the row with `min-w-0`. The mobile keeps wrapping, as N1 trims only the email. The row being the flex row that spans the whole `dd` is what makes the cap three quarters of the row. At 390px the cap and the space the two buttons leave are within a few pixels of each other, so the AC5 example asserts the span's computed `max-width` resolves to three quarters of the row as well as `truncated?`, which a missing or uncompiled class fails where a width comparison might not.

## Steps

- ::S1:: Refactor `app/javascript/controllers/clipboard_controller.js` to copy its `content` value, say its `copied` and `failed` values and toggle its `idle` and `done` classes, and make `app/views/groups/_join_link.html.erb` pass the link, its two sentences and `btn-primary` and `btn-secondary`; a refactor commit, the join link behaving exactly as before
- ::S2:: Add the copy buttons in `app/views/members/show.html.erb`: each contact `dd` a `clipboard` controller holding the value, its copy button and the Email or Call button in one row and the status line below, the mobile's inside its `if`; request examples in `spec/requests/members_spec.rb` for each button's name and content and for no mobile copy button without a mobile, browser examples in `spec/system/member_detail_spec.rb` for the copy reaching the clipboard, the check turning back, the refused copy saying so, and the copy icons drawing at 20px, each naming its `#370 AC` key
- ::S3:: Trim the email through `trimmed` with `max-w-3/4 min-w-0`, update the `WHY:` comments it makes stale in `app/views/members/show.html.erb` and `app/helpers/trim_helper.rb`, add a request example for the email's `title`, and rework the #368 one-word example in `spec/system/member_detail_spec.rb` to assert the email trims within three quarters of the row with nothing scrolling sideways

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-22_GHI-370_copy-member-email-and-mobile.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-22_GHI-370_copy-member-email-and-mobile.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/system/members_list_spec.rb spec/styleguide` passes before and after S1, its join link examples unchanged, the styleguide's included because `bin/ci` never runs it and the styleguide draws the join link
- ::V4:: `mise exec -- bin/rspec spec/requests/members_spec.rb` passes; the copy buttons' examples are seen failing against `main`'s view, the no-mobile example, which passes on `main`, is seen failing with the mobile copy button moved outside its `if`, and the email `title` example is seen failing against S2's view
- ::V5:: `mise exec -- bin/rspec spec/system/member_detail_spec.rb` passes; the copy, turn-back, refusal and icon-size examples are seen failing against `main`'s view, and the reworked trim example is seen failing against S2's view and again with `max-w-3/4` taken out
- ::V6:: `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views and `mise exec -- bin/rubocop` over the changed Ruby files exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove the copy reaches the clipboard in Chromium on `localhost`; they cannot see whether a check icon on a ghost button reads as "copied" at a glance, or how a phone's own clipboard toast stacks with it.

## Open questions

None.

## Settled

- None yet.
