> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: repair the UX/UI of the Me screen (#386)

## How this branch was worked

This plan is written after the work, on purpose, as #386 asks: it is worked as #364 was, each acceptance criterion collected as it was solved, one signed commit per AC, and the plan and the pull request last. The ACs below are the commits in order; one test-only commit, `cd5a14d`, which points the switcher's specs at the switcher now that the Me menu is a second `<details>` in the header, carries no AC number of its own.

The owner asked for the avatar to open a dropdown like the group switcher and the events list menu, with no separate profile screen. The options were drawn side by side after a Mobbin search of how shipped apps open an account menu, and the owner chose the one where the menu leads to the existing edit screen. The menu was built through the daisyUI Blueprint MCP server and checked in headless Chromium in both themes.

## Steps

- AC 1 · feat(fullstack): open a Me menu from the avatar
- AC 2 · feat(frontend): draw icons on the Me menu rows
- AC 3 · fix(frontend): name the Me menu rows for what they hold
- AC 4 · fix(frontend): quiet the Me menu icons, a person for profile
- AC 5 · fix(frontend): the Me menu's email in secondary

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-03_GHI-386_repair-ux-ui-of-me-screen.md`
- `bin/ci` is green on the pushed head, the browser suite included
- Every example added on the branch was watched red before the commit that makes it pass, on the pre-fix code or, where it passed there, under a mutation that removes the fix; the removed Me screen loses its specs and adds no example asserting it is gone

No gate can say whether the menu reads well; the owner judged each AC in the running app as it landed.

## Settled

Decisions the owner made along the way that have no commit of their own:

1. The avatar opens a menu that links to Edit profile, the profile's one screen; the Me screen is gone. Editing inside the dropdown was rejected, and so was a sheet, because the app's modals only ever confirm a delete, never hold a form.
2. The row and the screen are both called Edit profile, not a list of the fields, because notifications and settings will join it.
3. Delete my account leads Edit profile's button row, as a delete does on every edit screen, rather than sitting in the menu; Back, Cancel and Save go home.
4. The menu stays a `<details>` like the switcher and the events list, against the daisyUI MCP's popover rule: Chromium shows no accessibility difference, and about 6% of the browsers the app admits would open a popover menu mid-screen or not at all. Moving all three menus is #400, marked someday.
5. The rows carry icons, unlike the switcher and the events list, as most account menus on Mobbin do: Heroicons' `user` for Edit profile, since a pencil would not tell its future siblings apart, the legend's `new` for New group, and Heroicons' sign-out arrow. They sit at 20px, 8px from the label, as every icon-and-label control does, in the muted icon ink the event screen gives the icons beside its facts.
