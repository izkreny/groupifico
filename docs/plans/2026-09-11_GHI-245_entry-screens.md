> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the entry screens

## Which frames this is built from

Frames 9a to 9e and 10a to 10d, plus the flow map 1a. **There is no frame 9f** — the issue's "9a to 9f" names one that the export does not contain, and the 9-series it does contain is 9a, 9b, 9c, 9d, 9e, 9g, 9h, 9h2, 9i, 9k, 9l, 9m, 9o, 9p, of which everything from 9g on belongs to other rows. So nothing is missing and no screen is unaccounted for; the range in the issue is one letter long.

Read for pattern, copy, control set and states only, per the wireframe-fidelity note the issue and the epic both carry. The export's brand is "Chorifico" and its group type is "choir" throughout; `Brand#name` answers "Groupifico" for every domain until #223, and the group type is not on `SignUp` until #137, so both read as the general brand here.

## What these four screens are today

Every one of them is the scaffold shape: an `h1`, a paragraph of prose explaining the mechanism, a control, and a cross-link to the other flow. The prose is where the redesign lands — the frames replace an explanatory paragraph above the control with one hint line below it, and the copy is tighter and says different things.

| Screen | Today | After |
|--------------------------------|--------------------------------------------------|-------------------------------------------------------|
| `sessions/new` heading | "Sign in" | "Sign in" |
| `sessions/new` prose | "Give us your email address and we will send you a link that signs you in." | gone |
| `sessions/new` field | no label, placeholder "Enter your email address" | label "Email", placeholder "you@example.com" |
| `sessions/new` button | "Email me a sign-in link" | "Email me a sign-in link" |
| `sessions/new` hint | — | "No passwords. The link in the mail signs you in on this device." |
| `sessions/new` cross-link | "No account yet? Start a group" | gone |
| `sign_ups/new` heading | "Start a group" | "Create a group" |
| `sign_ups/new` prose | "Name your group and give us your email address. We will send you a link that creates both." | gone |
| `sign_ups/new` field order | group name, then email | email, then group name |
| `sign_ups/new` labels | "Group name", "Email address" | "Your email", "Group name" |
| `sign_ups/new` placeholders | "Enter a name for your group", "Enter your email address" | "you@example.com", "Riverside Choir" |
| `sign_ups/new` hint | — | "You become its owner. Rename it later on Edit group." |
| `sign_ups/new` button | "Email me a link to start it" | "Send my confirmation link" |
| `sign_ups/new` cross-link | "Already have an account? Log in" | gone |
| `sign_ins/show` heading | "Finish signing in" | "Sign in as <email>" |
| `sign_ins/show` prose | two paragraphs naming the address and the one-use rule | "Not you? Just close this page" and "Opening the link did nothing yet. Only this button signs you in, and the link then stops working." |
| `sign_ins/show` button | "Sign in" | "Sign in" |
| `sign_up_confirmations/show` heading | "Finish starting your group" | "Sign in as <email> and create your group <name>" |
| `sign_up_confirmations/show` prose | two paragraphs naming both values and the one-use rule | "Not you? Just close this page" |
| `sign_up_confirmations/show` button | "Create the group" | "Sign in and create group" |

The two button labels that do not change are the two a spec clicks: `spec/system/sign_in_page_spec.rb` clicks "Email me a sign-in link" and `spec/support/system_authentication_helper.rb` clicks "Sign in". Both are pinned by the first and sixth acceptance criteria, so neither helper is touched.

## Which frame lines are copy and which are the designer explaining

Several frames carry a footer paragraph, and they are not all the same kind of thing. The acceptance criteria are the filter, and they pick out exactly the ones that are screen copy: 9a's "No passwords…", 9b's "You become its owner…", 10a's "Opening the link did nothing yet…", and the "Not you?" line on 10a and 10b.

Everything else in that position is the designer describing the mechanism to a reader of the canvas, and is not built: 9b's "Its type comes from the hostname you are on…", 10b's "One step: your account, the group and your owner seat…", 10c's repeat of it, 9d's "Also shown when the link was already used once.", 9e's "Same treatment on Start a group." None names a control or a string the reader needs, and two of them describe behaviour the reader cannot act on.

The `hint:` slot on `AppFormBuilder#field` is where 9b's line goes, under the Group name field, which is what frame 9b's reading order draws and what that slot exists for — #239 built it for exactly this. The first acceptance criterion lists the button before the line, but it lists content rather than order, and "You become its owner" is a fact about the group's name field rather than about the form.

## The states that are flashes rather than screens

Four of the ten frames draw a state the controllers produce as a redirect carrying a flash, and the issue's own technical notes settle each one. Nothing here builds a screen for any of them; what they need is that the entry layout renders `layouts/_flash`, which it does.

| Frame | What it draws | What the code does |
|-------|--------------------------------------|----------------------------------------------------------|
| 9c | "Check your inbox" as its own screen | `SessionsController::LINK_SENT` or `SignUpsController::LINK_SENT` as a notice on the form it redirects back to |
| 9d | the form under an alert | `SignInsController::INVALID_LINK` or `SignUpConfirmationsController::INVALID_LINK`, same shape |
| 9e | the form under "Try again later." | the four `rate_limit` handlers, all of which redirect with that alert |
| 10c | the confirm page under an alert | `SignUpConfirmationsController::UNFINISHED`, redirected back to `show` with the token |

So "styled as the Check your inbox state" in the second acceptance criterion is satisfied by `layouts/_flash`'s `alert alert-success` — the state is the notice, and the notice is the layout's. `layouts/_flash.html.erb` is not one of the files this issue owns and is rendered unchanged.

Two proposals the frames draw and this row does not build, because the issue's technical notes rule both out and the frames' own callouts say they are ahead of the backend: 9c's "Open mail app" and "Use a different email", and 9e's disabled primary and its named rate-limit windows. The fourth acceptance criterion states the reason for the second one directly — the redirect carries no window to disable the button for.

## The second layout, and the one file outside this issue's list

`layouts/entry.html.erb` is the whole of what the frames' signed-out shell is: the brand name, the tagline, the flash, and the content column. No header row, no group mark, no avatar, no dock, no switcher — which is the point of it being a second layout rather than a branch inside the first, and what `spec/requests/sessions_spec.rb`'s "carries none of the shell's chrome" example already asserts.

It is declared one line at a time, `layout "entry"` in each of the four controllers, matching how those same four each declare their own `allow_unauthenticated_access` and `before_action :refuse_authenticated` with no shared concern between them. `SessionsController#destroy` inherits it and never renders it: it terminates the session and redirects.

**The `<head>` is extracted to `layouts/_head.html.erb` and rendered by both layouts.** That is an edit to `layouts/application.html.erb`, which is #244's file and is not in this issue's ownership list, so it is a deliberate deviation:

- Duplicating it means two copies of the `<title>` fallback, the six meta tags, the three icon links, `csrf_meta_tags`, `csp_meta_tag`, `yield :head`, `stylesheet_link_tag` and `javascript_importmap_tags`. Every one of those is an application-wide fact, and a second copy drifts silently: the first person to add a meta tag adds it once.
- The edit to `application.html.erb` is the head block becoming one `render` call, which is the smallest shape an edit to that file can have.
- The ownership rule exists so no two open branches touch one file. Checked: there are no open pull requests on this repository at all, and the sibling epic's remaining rows are screens, which the epic's own ownership line keeps out of the layout.

The column is `max-w-[40rem] mx-auto`, the value `layouts/application.html.erb` already carries, with a comment in each saying the other holds it too. One application has one column width; taking a different one here because no acceptance criterion names one would be a decision nobody made, and a reader who signs in would watch the page width change. It is an arbitrary-value utility, which the beta rule bans when it is written to close a gap with a frame — this one closes a gap with the application, and Tailwind 4 has no named `max-w-*` at 40rem.

## The tagline

"Who's coming to rehearsal." is hardcoded in `layouts/entry.html.erb`, alongside `Current.brand.name`. It is not a `Brand#tagline`: one caller is an abstraction with nothing to abstract, and #223 is the row that gives the branded domains their own copy and will want the map, not a method with one entry.

Worth raising rather than burying: "rehearsal" is choir vocabulary, and the general brand is where a person starting a band lands. The issue's overview asks for that line by name, so it is what this row builds, and #223 is where it stops being wrong.

## The daisyUI components each piece is built from

Named here so the diff is judged against a decision rather than against whatever the markup became. The Blueprint server's component syntax expert settles the markup; this is which component.

| Piece | Component |
|--------------------------|--------------------------------------------------------|
| Brand and tagline | plain text, `text-hero` and `text-meta` from the ladder #244 added |
| Both forms' fields | `AppFormBuilder#field` — `label`, `input`, and the `label`-classed hint |
| Field stack | `fieldset`, no `fieldset-legend` |
| Primary buttons | `btn btn-primary` |
| Flash | `layouts/_flash`, unchanged |
| Error summary | `shared/_errors` through `with_error_summary`, unchanged |
| Heading on the link pages | plain text, `text-record` |
| "Not you?" line | plain text, `text-meta` — copy, not a control |

The sign-up form loses its `fieldset-legend`. The legend reads "Your group" today, which was true when the fieldset held only the group's name; with "Your email" first it would label the address as part of the group, and frame 9b draws no legend at all. A legend-less `fieldset` is clean under `spec/support/axe.rb`'s tag list — that rule is axe's `best-practice` tag and this suite runs `wcag2a`, `wcag2aa`, `wcag21a` and `wcag21aa`.

The "Not you? Just close this page" line is text, not a link. Frame 10a's annotation says so outright: closing the page leaves the link unspent until it expires, so there is nowhere for a link to go.

## What the controllers already do, and what this row therefore does not touch

Five of the ten acceptance criteria describe behaviour that is already in place, and each is a rendering claim once the views land rather than a controller change:

- The identical answer whether or not the address is known is `SessionsController#create` enqueueing for a found user and redirecting the same way regardless.
- The empty field after a dead link is `value: params[:email]` reading nothing off a redirect that carries no params. That prefill stays, because #208's invitation link opens `/session/new?email=…` and whichever of the two rows lands second keeps it working.
- The sign-in wall with no flash is `Authentication#request_authentication`, which redirects to `new_session_path` and sets nothing, and landing on the root afterwards is `SignInsController#create`'s `redirect_to root_url`.
- "You are already signed in." on the groups index is `Authentication#refuse_authenticated` redirecting to `root_path`, which routes to `groups#index`.
- The unfinished-confirmation alert above the same button is `SignUpConfirmationsController#create`'s `RecordInvalid` rescue redirecting back to `show` with the token, and `layouts/_flash` sitting above `main`.

So no controller gains or loses a line except `layout "entry"`.

## The specs

Per `.agents/testing.md`, extend the file that covers the view or flow and open a new one only for what nothing covers:

- **`spec/system/sign_in_page_spec.rb`** covers `sessions/new` and gains nothing new in kind — it already asserts the submit button paints, that the page is accessible, and that the notice paints after a submission. Its `fill_in "email"` and `click_button "Email me a sign-in link"` both survive the redesign.
- **`spec/system/authentication_spec.rb`** covers the sign-in link flow, and `sign_in_through_the_browser` passes through `sign_ins/show`. It gains the two assertions that screen has never had: that the button paints and that the page is accessible.
- **`spec/system/sign_up_spec.rb`** is new. Nothing under `spec/system` reaches `sign_ups/new` or `sign_up_confirmations/show` — checked across the directory — and the form and its confirmation are one flow, so they are one file. It asserts the form's button paints and the form is accessible; that submitting lands back on the form with the notice painting; and that the confirmation page, reached with a minted token, paints its button and is accessible.

The request layer gets the fifth and sixth criteria's shape, per the duplication rule: whether a link is present is a request-spec assertion, not a browser one.

- **`spec/requests/sessions_spec.rb`**'s "offers a route to sign-up" is inverted to assert the absence of `new_sign_up_path`. It was added by #244, which removed the navbar and left `/session/new` with no way to sign-up, and said in its own plan that #236's row owns the redesign of that file. This is that row, and the first acceptance criterion is what it owes.
- **`spec/requests/sign_ups_spec.rb`** gains the mirror: `new_session_path` absent from `/sign_up/new`.

Paint targets are classes this markup itself carries, so Tailwind is certain to have compiled them — `.btn-primary` and `#notice`, the way `spec/system/groups_index_spec.rb` and `spec/system/sign_in_page_spec.rb` already choose theirs. Never `body`: light `base-100` is `oklch(100% 0 0)` and composites to 1.0 against the matcher's surface, so a correctly painted body reads as painting nothing.

## Steps

- Load the `daisyui-blueprint-mcp` skill, then run the Blueprint MCP sequence with one workflow id for the whole issue: setup expert, rules enforcer, page architect for the entry shell, and component syntax expert for `fieldset`, `input`, `label`, `btn` and `alert`.
- Write `layouts/_head.html.erb`, and replace the head block in `layouts/application.html.erb` with a render of it, leaving that file otherwise untouched.
- Write `layouts/entry.html.erb`: the brand, the tagline, the flash, and the capped column, with the comment pairing its width to `layouts/application.html.erb`'s.
- Add `layout "entry"` to `SessionsController`, `SignInsController`, `SignUpsController` and `SignUpConfirmationsController`.
- Rewrite `sessions/new.html.erb`: `content_for :title`, the heading, the labelled email field keeping its `params[:email]` prefill, the button, the hint line, and no link to sign-up.
- Rewrite `sign_ups/new.html.erb`: `content_for :title`, the heading, email before group name, the group name's `hint:`, the new button label, no legend, and no link to sign-in.
- Rewrite `sign_ins/show.html.erb`: `content_for :title`, "Sign in as <email>", the button, the "Not you?" line and the "Opening the link did nothing yet" line.
- Rewrite `sign_up_confirmations/show.html.erb`: `content_for :title`, "Sign in as <email> and create your group <name>", the button, and the "Not you?" line.
- Invert `spec/requests/sessions_spec.rb`'s sign-up route example, and add its mirror to `spec/requests/sign_ups_spec.rb`.
- Watch both of those fail: run them against the pre-rewrite views, where the link is still present, and see each go red.
- Extend `spec/system/authentication_spec.rb` with the paint and accessibility assertions for `sign_ins/show`.
- Add `spec/system/sign_up_spec.rb`.
- Watch the new system examples fail: break the button's component class in each template in turn and see the paint assertion go red rather than the label assertion.
- Run the Blueprint quality inspector with `auditIntent: "fix_changes"` over the changed templates, and judge its findings against the `daisyui-blueprint-mcp` skill.
- Verify all four screens in headless Chromium per the `browser-verification` skill, in both themes and at both widths, reading the accessible name of every control off the accessibility tree.
- Run `bin/ci`.

## Verification

- `bin/ci`
- `bin/rspec spec/requests/sessions_spec.rb spec/requests/sign_ups_spec.rb spec/requests/sign_ins_spec.rb spec/requests/sign_up_confirmations_spec.rb` while iterating, since the browser suite is the slow half of the gate
- `bin/rspec spec/system/sign_in_page_spec.rb spec/system/authentication_spec.rb spec/system/sign_up_spec.rb` after `bin/rails tailwindcss:build`, which the suite refuses to run without

`bin/ci` is this repository's one gate, per `.agents/gh-solo.md`. Its `Style: ERB` step runs `herb-lint` over the templates this row writes, and its `Tests: System` step runs the browser suite the new file joins.

What the gate cannot see: whether these screens read like the frames. `bin/ci` proves the markup lints, the controls paint and axe is quiet, and none of that is a claim about copy, order or feel. The frames are read by eye, at both widths and in both themes, and the headless-Chromium pass named in the steps is the whole of that evidence — it reports nowhere, so its box is the record that it happened. Nor does any gate prove the tagline is the right words for a band.

## Open questions

- The first and eighth acceptance criteria contradict each other. The first says neither public page links to the other; the eighth says every existing authentication request spec stays green untouched. `spec/requests/sessions_spec.rb`'s "offers a route to sign-up" example asserts the link the first criterion removes, so one of the two has to give. This row takes the first, inverts that example rather than deleting it, and adds the mirror on the sign-up form — which is the request layer asserting the criterion instead of contradicting it. The eighth criterion therefore cannot be ticked truthfully and will hold the merge gate until the issue is edited to exempt that one example.

## Settled

None yet.
