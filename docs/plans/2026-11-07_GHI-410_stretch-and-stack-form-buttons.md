> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: stretch and stack form buttons (#410)

## Approach

Every form's button row moves into one partial, `app/views/shared/_form_actions.html.erb` (new), which takes the row's buttons as a block and the edit screens' Delete trigger as `leading:`, exactly as the forms receive it today. The row is its own `@container`, because the form around it is `class="contents"` and cannot host one. Below a threshold width it is `flex flex-col-reverse`, so each button stretches to the full width and the stack reads Save, Cancel, Delete from the top; at or above it the row turns `flex-row` and every button takes `flex-1`, sharing the row equally.

DOM order stays Delete, Cancel, Save, which is the order on one line. So only the stacked layout is reversed by CSS, and there keyboard focus runs bottom to top, Delete first; the one-line layout, every desktop and most two-button phones keep focus and reading order matched. Reordering the DOM instead would put the mismatch on the layout most people see.

The threshold is per row shape, because the approved criteria stack a row only when it does not fit: a two-button row fits the 358px phone column and stays on one line there, while a three-button row led by "Delete my account" does not and stacks. The partial picks between two literal container-query classes on whether `leading:` is present, each set to the narrowest row width at which the widest row of that shape fits at an equal share, measured in headless Chromium on the real screens rather than estimated.

The members form's row has no `mt-4`, since its edit screen spaces it with the wrapper's `gap-4`, and the feedback form's row carries `mb-[env(safe-area-inset-bottom)]`; the partial takes a `classes:` local for that spacing, so neither screen moves.

The two "+ New" buttons get the noun: "New event" on the events list and "Invite member" on the members list, with the styleguide's inert copies in `app/views/styleguides/components/_labelled_buttons.html.erb` renamed to match.

## Steps

- Add `app/views/shared/_form_actions.html.erb` (new) and move the button rows of `app/views/addresses/_form.html.erb`, `app/views/events/_form.html.erb`, `app/views/groups/_form.html.erb`, `app/views/members/_form.html.erb`, `app/views/user_profiles/_form.html.erb` and `app/views/feedbacks/new.html.erb` into it, with the thresholds measured in headless Chromium
- Cover the row in the browser: in `spec/system/me_spec.rb`, Edit profile's three buttons share one line equally at `DESKTOP` and stack full width at `MOBILE` with Save on top and Delete my account at the bottom; in `spec/system/address_edit_page_spec.rb`, the two-button row stays on one line, sharing it equally, at `MOBILE`; no form screen scrolls sideways at `MOBILE`
- Rename the events list's "New" to "New event" and the members list's "Invite" to "Invite member", in the views, the styleguide copies and their request specs: `spec/requests/members_spec.rb` already asserts "Invite" and changes with it, and `spec/requests/events_spec.rb` gains the label next to its `href` assertion

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-07_GHI-410_stretch-and-stack-form-buttons.md`
- `bin/ci` is green on the pushed head, the browser suite included
- `bin/rspec spec/styleguide` is green, since the styleguide draws every form and `bin/ci` never runs it
- Every example added on the branch was watched red before the commit that makes it pass: the equal-share and stacked-order examples on the pre-fix rows, which sit left-aligned and wrap ragged, and the "New event" and "Invite member" labels on the pre-fix copy; the two-button one-line example passes pre-fix, so it is watched red under a mutation that drops the two-button threshold and stacks every row

No gate can say whether the rows read well, or whether the members and feedback screens kept their spacing; both are checked in headless Chromium at both widths and in both themes, and the owner judges them in the running app.

## Settled

1. Rows span the form's width and share it equally; when they do not fit, every button stacks full width with the main action on top and Delete at the bottom. Chosen by the owner on #410 after a Mobbin search of mobile edit screens (Coinbase, Beside, Fly Delta, Headspace, Linktree, Zocdoc) and narrow-column web forms (HBO Max, Calm).
2. The scope is form button rows and the "+ New" buttons; listing and judging every other button on every screen was dropped from #410.
