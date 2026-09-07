> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Update daisyUI to the latest release

## Which version is vendored

The bundle under `app/assets/tailwind/` is daisyUI **5.5.19**, not the 5.0 release #237 assumes. Two independent checks agree: `app/assets/tailwind/daisyui.mjs` matches the published `v5.5.19` release asset byte for byte by SHA-256, and the file carries `var version = "5.5.19"` on line 954. The install commit, `97d0504 build: install daisyUI 5`, names no version, which is why the issue had to guess at one.

`bin/update-daisyui` fetches from `/releases/latest/download/`, so it takes no version argument and the target is whatever is latest on the day it runs — 5.7.28 at plan time, published 2026-09-03. The version that actually lands is read back out of the downloaded bundle's own `var version` line, and that line is what the commit body records. This is the mechanism behind the issue's first acceptance criterion, which asks for the version in the commit body without saying where to read it.

## What the upgrade can reach

`app/views/` and `app/helpers/` use twenty daisyUI classes: `btn`, `btn-ghost`, `btn-primary`, `btn-error`, `label`, `input`, `select`, `textarea`, `link`, `link-hover`, `divider`, `fieldset`, `fieldset-legend`, `alert`, `alert-error`, `alert-success`, `alert-vertical`, `navbar`, `navbar-start` and `navbar-end`. Most of them arrive through Rails form helpers as `class: "..."` rather than as an HTML `class="..."` attribute, so an inventory that greps only for the attribute form misses `btn`, `input`, `select`, `textarea` and `label` entirely — which is most of the form surface. Eight forms carry `fieldset`, among them `app/views/groups/_form.html.erb`.

No template sets `data-theme`, and the `@plugin "./daisyui-theme.mjs"` block in `app/assets/tailwind/application.css` is empty. The application therefore renders on daisyUI's default theme order, and the theme file carries no custom surface for an upgrade to break.

## What the changelog says

The GitHub release bodies are boilerplate — a link to the changelog and an `npm i` line, nothing more — so the range cannot be read from the API. A grep across all 53 release bodies in the range returns nothing whatever the release changed, which reads as "no relevant change" and means "no content". The changelog lives at https://daisyui.com/docs/changelog/ and has to be read there.

Read there at plan time, the 5.5.20 to 5.7.28 range carries no breaking change, no renamed class and no removed class. It does carry one entry that lands squarely on this application: v5.6.0's "improve input, textarea, select, and floating label sizing" names `input`, `textarea`, `select` and `label`, and all four are in the list above. The change is a sizing improvement rather than a break, so nothing should need adjusting — but the eight forms are where an unexpected shift would show, and they are what the headless walk is for.

## Steps

- Run `bin/update-daisyui`, overwriting `app/assets/tailwind/daisyui.mjs` and `app/assets/tailwind/daisyui-theme.mjs` from the latest release.
- Read the landed version out of the new bundle's `var version = "..."` line and confirm it against the latest release tag.
- Re-read https://daisyui.com/docs/changelog/ across the range that actually landed, confirming or correcting the plan-time finding above, and list in the pull request every breaking change that touches one of the twenty classes.
- Adjust the views for any breaking change that list turns up, and say in the pull request when it turns up none.
- Run `bin/ci`.
- Walk the groups index and one `fieldset`-bearing form headless, comparing each against the same page rendered from the pre-update bundle, per the `browser-verification` skill. v5.6.0's form sizing entry is the specific thing to look for.
- Commit as `build`, naming the from and to versions in the commit body.

## Verification

- `bin/ci`

`bin/ci` is this repository's one gate, per `.agents/gh-solo.md`, and two of its steps carry this change. `Tests: Stylesheet` runs `bin/rails tailwindcss:build`, which compiles the new bundle, so a plugin-API break dies there rather than inside a view. `Tests: System` runs the browser suite, whose `paint` matcher composites an element over the first ancestor that paints an opaque background and reports the real contrast ratio, and whose `be_accessible` matcher runs axe.

What the gate cannot see: of the twenty classes, the browser suite asserts on three renderings — the sign-in page's submit button and notice, and the paused-member refusal's `alert alert-error`. Nothing asserts on `input`, `select`, `textarea`, `label`, `fieldset`, `fieldset-legend`, `navbar` or `divider`, and the first four are exactly what v5.6.0 resized. A sizing or spacing shift on a form or on the shell therefore passes `bin/ci` green. The headless walk named in the steps is the judgement that closes that gap; it is #237's third acceptance criterion, and it is ticked on the issue rather than here.

## Open questions

None.

## Settled

- #237's Overview said the vendored bundle was "a 5.0 release"; it is 5.5.19 by checksum and by the version string in the file. Correct the issue body? Decided: correct it. The issue's Overview now names 5.5.19 and says how both checks were made.
