> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: name icon sizes and spacing as theme tokens (#388)

## The tokens

The issue's ten go in `app/assets/tailwind/application.css`'s `@theme`, each with a comment saying where it applies, and `.btn`'s gap reads `--spacing-icon-label`. Three derived tokens join them, because each is used more than once or feeds another:

- `--spacing-control-inset`, `(control - icon-control) / 2`, 6px: a 20px glyph's inset in its 32px button.
- `--spacing-label-control`, `icon-label - control-inset`, 2px: the box gap that sets a label 8px from a button's glyph.
- `--spacing-tally-rest`, `tally - icon-text`, 6px: what a tag's margin adds to its row's 6px gap to make 12px.

## Which sites take a token

A token goes where #366's comment names the rule, never everywhere its value happens to match:

- `size-icon-inline`, `size-icon-control` and `size-icon-standalone` replace every icon's `size-4`, `size-5` and `size-6`, and the header's `w-5 h-5` slot takes `size-icon-control`.
- `size-control` replaces `size-8` on the roster's status box and the header's back link. The colour swatches and the avatar stay raw: neither is an icon button.
- `gap-controls` replaces `gap-2` on the icon strips in `app/views/events/_event.html.erb`, `app/views/events/_next_up.html.erb`, `app/views/members/_member.html.erb` and `app/views/events/_roster.html.erb`. A row of labelled buttons stays `gap-2`, since no token names that gap.
- `gap-icon-text` replaces `gap-1.5` on the fact lines and `gap-x-1.5` in the tally. The checkbox label in `app/views/members/_form.html.erb` stays raw: it holds no icon.
- `gap-card-row` replaces the hero card's `gap-2`. The record facts in `app/views/events/_event.html.erb` stay raw: #366 names the hero card alone.

## The raw steps the issue names

Each derives from the tokens, with the one number no token holds written in the `calc()` at its site. None keeps its raw step.

| Raw step | Becomes | Arithmetic | Spec holding the pixel |
|---|---|---|---|
| event row `-ml-0.5` | `ml-[calc(var(--spacing-controls)+var(--spacing-control-inset)-1rem)]` | 8 + 6 - daisyUI's 16px row gap = -2 | `spec/system/events_list_spec.rb`, answer to pencil 20 |
| header `gap-0.5` | `gap-label-control` | 8 - 6 = 2 | `spec/system/group_shell_spec.rb`, name to chevron 8 |
| header `-ml-2` | `ml-[calc(var(--spacing-label-control)-0.625rem)]` | 2 - the navbar's 10px gap = -8 | `spec/system/group_shell_spec.rb`, name to pencil 8 |
| header `-ml-1.5` | `ml-[calc(1rem-2*var(--spacing-control-inset)-0.625rem)]` | 16 - 12 - 10 = -6 | `spec/system/group_shell_spec.rb`, chevron to pencil 16 |
| roster `mr-2.5` | `mr-[calc(1.875rem-var(--spacing-controls)-2*var(--spacing-control-inset))]` | 30 - 8 - 12 = 10 | `spec/system/event_detail_spec.rb`, `[30, 20, 20, 20, 20]` |

Two neighbours fall to the same rule. The back link's `-m-1.5` is exactly the inset, so it becomes `-m-control-inset`. The rsvp's `mt-1.5` on the hero card becomes `mt-[calc(var(--spacing-card-break)-var(--spacing-card-row))]`, since `mt-card-break` alone would land 22px on top of the row gap, which `spec/system/events_list_spec.rb`'s `[8, 14]` holds.

The tally keeps its markup, because `spec/system/events_list_spec.rb` reads the tags through the label's parent: `gap-x-icon-text` stays on the row and `mr-tally-rest` replaces each `mr-1.5`, so the 12px is named without moving anything.

## `VARIANTS`

The raw keys go rather than sitting beside the new ones, so `size-5` raises and a view cannot drift back to a raw step. The two specs naming them move in the same commit: `spec/helpers/icons_helper_spec.rb` and `svg.size-5` in `spec/requests/events_spec.rb`. Neither is a spec that measures, so the system specs stay untouched as the issue asks.

## The styleguide

The "Legend icons", "Button" and "Buttons with an icon and a label" sections each gain a line naming the tokens they draw with, asserted by a new example in `spec/requests/styleguides_spec.rb`.

## Seen red

The refactor's proof is that the existing measurements pass unchanged, which only counts if they read through the tokens. So each token is mutated in turn, the stylesheet rebuilt and the system spec file holding it run, watching it go red before reverting. A token no example catches gets one, in the file covering its view.

The new examples: `spec/helpers/icons_helper_spec.rb`'s raw-size refusal is seen red with the raw keys still in `VARIANTS`, and `spec/requests/styleguides_spec.rb`'s token names with the lines removed.

## Steps

- Add the tokens to the `@theme`, point `.btn` at `--spacing-icon-label`, and add the new size classes to `IconsHelper::VARIANTS` beside the raw ones.
- Move every view's icon sizes and the control box to the role tokens.
- Move the strips, fact lines, tally and hero card to their spacing tokens.
- Replace the named raw steps with their derivations, updating the `WHY:` comments that name the old steps.
- Drop the raw keys from `IconsHelper::VARIANTS`, moving the two specs that name them.
- Name the tokens in the styleguide.
- Mutate each token and watch its spec go red.

## Verification

- `bin/rails tailwindcss:build`, then every token utility the views use has a rule in the built stylesheet, checked with `grep`
- Each token's mutation seen red in the spec holding it, and each new example seen red, as above
- `git diff --numstat main -- spec/system spec/styleguide` shows no deleted line, so every existing measurement passes unchanged
- `bin/rspec spec/styleguide`, which `bin/ci` does not run
- `bin/ci`

No gate here compares a page before and after at a pixel level beyond what the specs measure, so a gap no spec holds rests on the arithmetic above.
