> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: make field errors readable in the light theme (#299)

## Approach

The contrast fix itself landed with #257: its error token reads 5.28:1 on `base-100` in light and 5.19:1 in dark, and the styleguide's axe audit in `spec/styleguide/styleguide_spec.rb` passes in both twins. What this branch adds is the guard. Three system examples audit a refused save with `be_accessible` and no colour scheme, so each audits whatever theme the machine prefers, and a dark-preferring machine never runs the light audit that would have caught the defect.

Each of the three states `prefer_colour_scheme :light` before the `visit` that produces the refused page, and asserts `rendered_colour_scheme` is `"light"` beside its `be_accessible`, which is what the helper in `spec/support/colour_scheme_helper.rb` says makes a scheme claim falsifiable:

- `spec/system/me_spec.rb`, the example "paints a refused save's messages under their fields and the summary on top", which is self-contained, so the call goes after `sign_in_as`
- `spec/system/address_edit_page_spec.rb` and `spec/system/member_edit_page_spec.rb`, whose `visit` sits in the context's `before`, so the call goes at the top of that `before` and the whole context runs light

The guard is only evidence once it has been seen red. `app/assets/builds` is gitignored and nothing in `bin/rspec` rebuilds it, so each swap of the light `--color-error` in `app/assets/tailwind/application.css` is followed by `bin/rails tailwindcss:build` before the examples run.

## Steps

- Add `prefer_colour_scheme :light` and the `rendered_colour_scheme` assertion to the three examples named above
- Set the light theme's `--color-error` in `app/assets/tailwind/application.css` back to daisyUI's `#ff627d`, rebuild the stylesheet, and watch all three examples fail on the colour-contrast violation
- Restore `#b32e2a`, rebuild, and watch all three pass
- Run `bin/rspec spec/styleguide`, then `bin/ci`

## Verification

- `bin/ci` passes
- `bin/rspec spec/styleguide` passes
- The three examples were each seen red with the light `--color-error` set to `#ff627d` and the stylesheet rebuilt, before being seen green on `#b32e2a`

What these gates cannot see: the refused-save pages in dark, which these examples no longer audit on a dark-preferring machine; the dark error token is covered by the styleguide's dark twin instead, as text on `base-100`. The colour comparisons that share the two `before` blocks now always run light, which changes nothing they assert, since each compares two computed colours on the same page.

## Open questions

None.

## Settled

- The three audits run light only, with no dark twin. The issue's criterion asks for the colour scheme to be stated so the light audit runs everywhere, and the first criterion's dark half is the styleguide's dark twin, which already audits the error token as text on `base-100`.
