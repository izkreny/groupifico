> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Enable the daisyUI light and dark themes

## What the build already does

daisyUI's `themes` option defaults to exactly what #243 asks to be written down. The vendored bundle carries `themes = ["light --default", "dark --prefersdark"]` as the parameter default, so `@plugin "./daisyui.mjs";` with no option block compiles the same stylesheet the explicit form would. Read back out of the current `app/assets/builds/tailwind.css`: `light` lands on bare `:root`, and `:root:not([data-theme]){color-scheme:dark;...}` sits inside the file's one `@media (prefers-color-scheme:dark)` block.

daisyUI also paints the root itself, which is what makes the second acceptance criterion already true: `:root,[data-theme]{background:var(--page-scroll-bg,var(--root-bg));color:var(--color-base-content)}` with `:where(:root,[data-theme]){--root-bg:var(--color-base-100)}`. No `bg-base-100` on `<body>` is needed, and adding one would be a second spelling of a fact the plugin already states.

So writing the option out changes no byte of the build. It is worth writing anyway: it makes the two themes a decision this repository made rather than one it inherited, and #257 edits that same line when the organic theme arrives.

## The empty block is not inert

`@plugin "./daisyui-theme.mjs"{ /* custom theme here */ }` compiles a theme named `custom-theme` into the stylesheet: the build carries `:root:has(input.theme-controller[value=custom-theme]:checked),[data-theme=custom-theme]{...}` and its full token block. Nothing in `app/views/` sets `data-theme` or renders a `theme-controller`, so those rules can never match. Removing the block is the one output change this row makes, and diffing the built stylesheet is how it gets proven.

The `app/assets/tailwind/daisyui-theme.mjs` file stays. It is the vendored plugin `bin/update-daisyui` refreshes, and #257 needs it back.

## Where the raw colours are

A sweep of `app/views/`, `app/helpers/`, `app/javascript/` and `app/assets/stylesheets/` for hex, `rgb()`, `hsl()` and Tailwind's own palette scales returns nothing. The third acceptance criterion holds across every ERB template as written.

One file is outside that answer and the sweep's regex could not see it: `app/views/pwa/manifest.json.erb` carries `"theme_color": "red"` and `"background_color": "red"`, Rails' scaffold defaults. It is a view by location, but a web app manifest is parsed by the operating system rather than painted by the page, so it cannot reference `bg-base-100` and has to hold a literal. It is the one place the criterion's wording and its intent disagree, so it went up as an open question rather than being settled silently; `## Settled` below carries the answer and the step list carries the work.

## The spec

New file. `spec/system/group_refusal_spec.rb` covers a refusal flow and nothing covers the groups index, so per `.agents/testing.md` this is a view no file covers yet.

Dark is reached through the DevTools Protocol, `Emulation.setEmulatedMedia` with a `prefers-color-scheme` feature, sent before `visit`. Ferrum exposes `command` publicly and Cuprite's driver exposes `browser`, so the helper is two lines and belongs in `spec/support/` beside the other driver-level helpers.

`.btn-primary` is the element asserted on, the index's own "New group" link, chosen the way `spec/system/paint_matcher_spec.rb` chooses its positive control: a class this page already carries is certain to be in the Tailwind build. `body` is the wrong target in the other direction — light `base-100` is `oklch(100% 0 0)`, identical to the matcher's default surface, so a correctly painted body scores 1.0 and reads as unpainted.

A theme assertion that only measures paint is unfalsifiable, because a silently ignored emulation leaves the page in light and every expectation still passes. Each example therefore also reads `getComputedStyle(document.documentElement).colorScheme` back and expects the theme it asked for.

## Steps

- Put the `@plugin "./daisyui.mjs"` line through the daisyUI Blueprint MCP server's setup tool, with the `daisyui-blueprint-mcp` skill loaded first, and take its verdict on the option syntax.
- Rewrite `app/assets/tailwind/application.css`: `@plugin "./daisyui.mjs" { themes: light --default, dark --prefersdark; }`, and delete the `daisyui-theme.mjs` plugin block with its placeholder comment.
- Rebuild the stylesheet and diff it against the pre-change build, expecting the `custom-theme` rules gone and nothing else moved.
- Add a `prefers-color-scheme` emulation helper to `spec/support/`, sending `Emulation.setEmulatedMedia` through the Cuprite driver's Ferrum page.
- Watch the helper fail: assert dark, stub the emulation out, and see the `colorScheme` expectation go red rather than the example passing in light.
- Add `spec/system/groups_index_spec.rb`, signing in as a member and asserting on the index in both themes that `.btn-primary` paints, that the root's `color-scheme` is the one requested, and that the page is accessible.
- Run the light example after the dark one and confirm it is not inheriting the emulation from its predecessor.
- Replace the two `red` literals in `app/views/pwa/manifest.json.erb` with the light theme's compiled `base-100`, naming in an ERB comment the token it copies and that #257 owns the next value.
- Run `bin/ci`.

## Verification

- `bin/ci`
- The built stylesheet compared before and after the rebuild, split on `}` so a single-line file diffs at all, showing only the `custom-theme` rule removed

`bin/ci` is this repository's one gate, per `.agents/gh-solo.md`. Its `Tests: Stylesheet` step runs `bin/rails tailwindcss:build`, so a malformed option block dies there rather than in a view, and its `Tests: System` step runs the browser suite that the new spec joins.

What the gate cannot see: the built stylesheet is gitignored, so the comparison above runs on this machine and reports to nothing, and its tick is the whole of the evidence that it ran. Nor does any gate prove that the emulation is what put the page in dark — only the `colorScheme` expectation inside the spec does, and that expectation is worth exactly as much as the fail-watch named in the steps.

## Open questions

None.

## Settled

- `app/views/pwa/manifest.json.erb` holds `"theme_color": "red"` and `"background_color": "red"`, and the plan proposed leaving both to #257 on the grounds that a manifest cannot carry a semantic class. Decided: replace them now with `base-100`, the owner's answer being to use that token, or `--color-error` where the context is an error - and neither key is. It goes in as the light theme's compiled value, because `light` is the `--default` theme and a manifest has no way to switch on the device preference. Hex rather than the `oklch()` the stylesheet uses, since a manifest is parsed by the operating system and `oklch()` support across Android and iOS is not something this branch can verify.
