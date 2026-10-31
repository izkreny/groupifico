> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: repair the UX/UI to match the wireframes (#364)

## How this branch was worked

This plan is written after the work, on purpose. The owner chose the order for #364: each acceptance criterion was collected as it was solved, one signed commit per AC, and the plan and the pull request come last. The ACs below are the commits in order; two test-only commits that support them, `c6b1f6b` and `7634f9b`, carry no AC number of their own.

The owner steered from the running app: they picked elements on screen with the development element picker (AC 3), and the choices that needed one were drawn side by side as options before anything was built. The styleguide carries every component the ACs touch. Screens were built through the daisyUI Blueprint MCP server, with the local `daisyui-blueprint-mcp` skill loaded first, and every UI decision was checked against Mobbin's library of shipped apps before it was put to the owner.

The wireframes set each screen's behaviour and copy, never its styling: daisyUI's defaults win unless the owner changes something for the whole theme, such as a status colour, a radius or an icon size.

## Steps

- AC 1 · fix(frontend): swap to Alegreya and Commissioner
- AC 2 · docs(frontend): keep the font pairings page
- AC 3 · feat(fullstack): pick elements on every dev page
- AC 4 · fix(frontend): soften alerts, calm status colours
- AC 5 · fix(frontend): sync the dark status colours
- AC 6 · fix(frontend): one smaller radius, scaled by size
- AC 7 · feat(frontend): alert icons and a dismiss button
- AC 8 · fix(frontend): make the duplicate notice an info alert
- AC 9 · feat(fullstack): count reserved places in the tally
- AC 10 · fix(frontend): draw Who's coming as WW's 4c does
- AC 11 · fix(frontend): tally tags as coloured icons alone
- AC 12 · fix(frontend): tally beneath the credits, stock arrow
- AC 13 · fix(frontend): drop the said-yes names for now
- AC 14 · feat(frontend): link the card's responses to the list
- AC 15 · fix(frontend): draw Responses as a fact line
- AC 16 · fix(frontend): tags beside Who's coming
- AC 17 · fix(frontend): quieter icons beside the event facts
- AC 18 · fix(frontend): a little more room after fact icons
- AC 19 · fix(frontend): ask Who's coming? on card and screen
- AC 20 · fix(frontend): one spacing for Who's coming? rows
- AC 21 · fix(frontend): answer buttons apart, chosen in colour
- AC 22 · fix(frontend): name the dimmed inks as theme tokens
- AC 23 · fix(frontend): roster pills apart, in tally colours
- AC 24 · feat(frontend): show the app's colour tokens
- AC 25 · fix(frontend): roster status as a bare icon
- AC 26 · fix(frontend): reserved icon beside the plane
- AC 27 · fix(frontend): roster icons at one spacing
- AC 28 · fix(frontend): Who's coming? tags below on a phone
- AC 29 · fix(frontend): lit roster pill without a fill
- AC 30 · fix(frontend): answer buttons beside the question
- AC 31 · fix(frontend): status colour on unchosen answers
- AC 32 · fix(frontend): more room before answer buttons
- AC 33 · fix(frontend): hero answer buttons after question
- AC 34 · fix(frontend): drop the asked-ago line
- AC 35 · fix(frontend): centre the event row's status icon
- AC 36 · fix(frontend): minus-circle for a no answer
- AC 37 · fix(frontend): check-badge for a confirmed event
- AC 38 · fix(frontend): shield-check for a concluded event
- AC 39 · feat(frontend): fold the styleguide's sections
- AC 40 · fix(frontend): row answer at the end, in colour
- AC 41 · fix(frontend): every registration on its row
- AC 42 · fix(frontend): row icons at 24px, status muted
- AC 43 · chore(frontend): drop the stale reserved note
- AC 44 · fix(frontend): answer icons at the tally's size
- AC 45 · fix(frontend): question in the buttons' weight
- AC 46 · fix(frontend): answer row above Who's coming?
- AC 47 · refactor(frontend): fold the roster in its details
- AC 48 · fix(frontend): answer row above the card
- AC 49 · fix(frontend): tighter roster rows
- AC 50 · feat(frontend): answer on the event in place
- AC 51 · fix(frontend): hold the view through an answer
- AC 52 · fix(backend): duplicate an event with an address
- AC 53 · fix(frontend): size the invite button's icon
- AC 54 · fix(frontend): take-off first, apart from status
- AC 55 · feat(frontend): answer in place, wherever pressed
- AC 56 · feat(frontend): group switcher as a dropdown menu
- AC 57 · fix(frontend): space the group switcher's rows
- AC 58 · fix(frontend): centre a badge's letters
- AC 59 · fix(frontend): 8px between switcher rows
- AC 60 · feat(frontend): events list menu as a dropdown
- AC 61 · fix(frontend): open map links in a new tab
- AC 62 · feat(frontend): pushed screen's title in the header
- AC 63 · fix(frontend): back to the screen pushed from
- AC 64 · fix(frontend): header tabs on forms, dock off
- AC 65 · fix(frontend): sign-in screens as wireframed
- AC 66 · fix(frontend): edit pencil on hero and event rows
- AC 67 · fix(frontend): row question under the name again
- AC 68 · fix(frontend): 20px pencil on event rows
- AC 69 · fix(frontend): row pencil 20px from the answer
- AC 70 · fix(frontend): duplicate button on the hero card
- AC 71 · fix(frontend): 24px dismiss icon on alerts
- AC 72 · feat(frontend): collapse and expand all SG sections
- AC 73 · feat(frontend): filled Heroicons at every size
- AC 74 · fix(frontend): 24px icons in the phone dock
- AC 75 · fix(frontend): 20px icons on the member row
- AC 76 · fix(frontend): 20px icons on the roster rows
- AC 77 · fix(frontend): 20px Duplicate and Edit on the hero
- AC 78 · fix(frontend): 20px switcher chevron and pencil
- AC 79 · fix(frontend): 20px icons on the answer buttons
- AC 80 · fix(frontend): 20px Duplicate and Edit on the event
- AC 81 · fix(frontend): 24px tab icons in the header
- AC 82 · fix(frontend): 20px answer icon on the event row
- AC 83 · fix(frontend): 20px icons on the member screen
- AC 84 · fix(frontend): group name as the header's h1
- AC 85 · fix(frontend): keep the scrollbar gutter on desktop
- AC 86 · fix(frontend): 14px above the hero card's answer
- AC 87 · fix(frontend): Delete first in the edit forms' row
- AC 88 · fix(frontend): no Delete on the event screen
- AC 89 · fix(frontend): 32px tap target for the back chevron
- AC 90 · feat(frontend): SG section for labelled buttons
- AC 91 · fix(frontend): 20px pencil on the group's address
- AC 92 · fix(frontend): 20px icons, 8px gap in labelled buttons
- AC 93 · fix(frontend): roster take-off 30px before the strip
- AC 94 · fix(frontend): an icon in every labelled button
- AC 95 · fix(frontend): hero kicker as a secondary eyebrow

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-31_GHI-364_repair-ux-ui-to-match-wireframes.md`
- `bin/ci` is green on the pushed head, the browser suite included
- Every example added on the branch was watched red before the commit that makes it pass, on the pre-fix code or, where it passed there, under a mutation that removes the fix; the removals (ACs 13, 34, 43, 88) add no example, since a removed element is not asserted absent

The issue's own criterion, the heading face drawing `Č Ć Đ Š Ž` and `č ć đ š ž` with no fallback, is held by the font-fallback example in `spec/system/group_shell_spec.rb`, which `bin/ci` runs. No gate can say whether a screen matches the wireframes' idea; the owner judged each AC on the styleguide and the running app as it landed.

## Settled

Decisions the owner made along the way that have no commit of their own:

1. Section roots (Events, Members) keep the group name and its switcher in the header; only pushed screens show a section title, as Mobbin's BFF, ClickUp, Deel and Felt screens do.
2. The edit pencil on the hero card and the event rows stays at the trailing edge (AC 66): Mobbin shows a trailing pencil for editing an item and a pencil beside the name only for an inline rename.
3. Icons are Heroicons filled at every size (AC 73); a fixed 2px non-scaling stroke was tried and rejected.
4. Icon sizes by role: 16px beside text, 20px for icon controls and labelled buttons, 24px standalone, chosen section by section on the options page.
5. The back control stays a plain 20px chevron; a 24px Base 200 circle with a 16px chevron was built and reverted.
6. More than one h1 per page is allowed and not enforced; the group name and the brand are h1.
7. With JavaScript off, Delete deletes on the first press without the confirm sheet, as before.
8. The alert's dismiss keeps its 4px inset (a 24px glyph in a 32px button) to match the alert's icon; the header's 8px and 16px gaps are on purpose; the several ways the 20px control gap is built stay until #388 names them as theme tokens.

## Open questions

None.
