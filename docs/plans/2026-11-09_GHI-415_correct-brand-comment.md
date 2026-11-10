> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: correct the brand comment on registered domains (#415)

## Approach

The one-line comment above `GROUP_TYPES` in `app/models/brand.rb` is rewritten to give the real reason the map holds one entry: `chorifico.com` is the only branded domain, and `groupifico.com` is registered too but belongs to the general brand, so it needs no row. The rewritten line opens with `WHY:`, the marker the rest of `app` already uses for a comment that explains a choice. Nothing else in the file moves, including the `DEFAULT_GROUP_TYPE` comment that already names `groupifico.com`, and the decision record that calls `groupifico.com` unregistered stays as written per the issue's notes.

## Steps

- ::S1:: Rewrite the comment above `GROUP_TYPES` in `app/models/brand.rb` as one line: `chorifico.com` is the only branded domain, `groupifico.com` is registered but is the general brand's and needs no row, and a second branded domain is a row here

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-09_GHI-415_correct-brand-comment.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-09_GHI-415_correct-brand-comment.md` exits 0
- ::V3:: `git grep -n -i -E 'only registered domain|groupifico\.com.{0,20}not registered' -- app config` finds nothing and exits 1, having been seen to find `app/models/brand.rb:10` and exit 0 on `main`
- ::V4:: `mise exec -- bin/rubocop app/models/brand.rb` exits 0
- ::V5:: `mise exec -- bin/ci` passes, browser suite included

No gate here reads whether the new sentence is true; that is AC1, which the owner proves by reading the line.

## Open questions

None.

## Settled

None yet.
