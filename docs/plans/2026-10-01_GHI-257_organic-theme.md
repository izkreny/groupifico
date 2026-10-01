> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add the organic theme (#257)

## Approach

The palette is settled, and the issue's *Technical notes* hold every value: it was built on a sample page in headless Chromium, each token read back from the paint and measured against WCAG AA in both themes, with the owner choosing on the page. That page lands in `docs/design/organic-theme.html` (new) as the record of the decision, opened from disk with no build; the live reference is the styleguide, which renders the real theme.

`app/assets/tailwind/application.css` is where almost everything changes. The main plugin's `themes` goes to `false`, two `@plugin "./daisyui-theme.mjs"` blocks register `organic` as the default and `organic-dark` for `prefers-color-scheme: dark`, and a `@theme` block names the two font families so Tailwind's `font-heading` utility exists and `--font-sans` resolves to Figtree for everything else. Headings take Caprasimo on the `h1`, `h2` and `h3` elements, since every title in the app is one of those and no view carries a font utility today.

The fonts vendor as the four woff2 files the Google Fonts endpoint serves: Caprasimo in a latin and a latin-ext subset, and Figtree as one variable file per subset covering 400, 600 and 700, with the SIL Open Font License beside them. The `@font-face` sources are written as `url("/fonts/...")`: Propshaft's CSS compiler resolves a leading slash against its load path, which includes `app/assets/fonts/` (new), and rewrites it to the digested path in the built stylesheet.

Four rules sit beside the themes. The focus rule puts a 2px primary border and no outline on `.btn:focus-visible` and on `.input` and `.select` when focused or open, so a mouse click leaves a button alone. The input border rises to 50% of the text colour and placeholders to 65%, each because daisyUI's default fails AA on this ground, with error inputs excluded so they keep their red border. The heading font sets `font-synthesis: none`, since daisyUI asks for weight 600 and Caprasimo ships only 400. daisyUI's CSS is layered in the Tailwind build, so an unlayered rule beats it regardless of specificity; whether the `!important` flags the sample page needed are still needed is read off the built CSS, and they go if not.

The styleguide's twins name the themes: `app/views/styleguides/_section.html.erb` iterates `light` and `dark` into `data-theme`, and `spec/styleguide/styleguide_spec.rb` selects on the same two values, so both move to the new names. Nothing else does. Every system spec that asserts a theme reads `color-scheme` off the root through `rendered_colour_scheme`, which both organic themes set, so those stay as they are.

The dark theme is not the light theme inverted, by construction. On the dark ground no lightness lets a fill carry pale text at 4.5:1 and also read at 4.5:1 as text on the ground, and `text-primary` is what the shell tabs and the icon buttons use, so the dark fills are pale with dark text. The light error reads 5.3:1 and the dark 5.2:1 as text on `base-100`, which is #299's criterion met by the token alone; that issue stays open to add its own assertion.

## Steps

- Commit the sample page as `docs/design/organic-theme.html` (new), on its own as a `docs` commit, after reading it once more for anything that names a machine
- Fetch the four woff2 files from the Google Fonts endpoint into `app/assets/fonts/` (new), put `app/assets/fonts/OFL.txt` (new) beside them, and write the `@font-face` rules with each subset's `unicode-range` and `font-display: swap`
- Rewrite the daisyUI plugin block in `app/assets/tailwind/application.css` to `themes: false` plus the two theme blocks, the `@theme` fonts, the heading element rule, the focus rule, the input and placeholder rules and the synthesis rule, all values from the issue
- Rename the styleguide twins in `app/views/styleguides/_section.html.erb` and the selectors in `spec/styleguide/styleguide_spec.rb` to `organic` and `organic-dark`
- Run `bin/rails tailwindcss:build` and read the built stylesheet for the digested font URLs, the layer the daisyUI rules sit in, and whether any `!important` is still needed
- Run the daisyUI Blueprint quality inspector over the stylesheet and the styleguide, verifying each finding against the cascade before acting on it, then walk the styleguide in headless Chromium under both colour schemes
- Extend `spec/system/group_shell_spec.rb` with three examples, each watched red first: `text_contrast` on the current shell tab reads 4.5 or better under each scheme, red against the stock themes; a Tab onto a button computes `outlineStyle` of `none` and a 2px border, red with the focus rule removed; `document.fonts.check` answers true for both families, red with the `@font-face` rules removed
- Run `bin/ci`, then `bin/rspec spec/styleguide`

## Verification

- `bin/ci` passes
- `bin/rspec spec/styleguide` passes
- The three new examples in `spec/system/group_shell_spec.rb` were each seen red on the case they catch before the change that makes them pass

What these gates cannot see: whether the palette is right, which the owner settled on the sample page and the styleguide now shows for real; the Blueprint inspector's verdict, which is static and composition-blind, so its findings are checked against the rendered page rather than acted on; and the browser walk itself, which is where a class that paints nothing would show.

## Open questions

None.

## Settled

- Primary is accent-700 with pale text, not the brand's `#c67139` with ink, and accent equals primary. Pale text on the brand terracotta reads 3.3:1, and the owner preferred the deeper fill once both were on the page; daisyUI's black, wireframe and silk themes make accent and primary one colour too, and no view uses the accent role.
- Warning is a true yellow at oklch 80% and is fill-only. Every darker amber was rejected on the page; a solid badge or alert carries ink at 8.9:1, and no frame or view paints warning as text or as a soft variant.
- Tabs get no rule. The sample page carried one for daisyUI's `.tab`, but no view renders that component: the shell tabs are links in the dock and the segmented control is the form builder's own.
