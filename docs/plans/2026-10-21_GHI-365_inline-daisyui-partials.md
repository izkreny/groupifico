> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: extract inline daisyUI markup into partials (#365)

## The partials

Each one takes over its markup verbatim from the screen that writes it inline, so every screen renders byte for byte what it renders now, and the styleguide renders the same partial with sample locals instead of its hand-kept copy.

- `app/views/events/_scope_select.html.erb` (new), `(group:, past:, id: "scope")`: the whole `form_with` and its `select_tag` from `app/views/events/index.html.erb`. The default `id` is what `select_tag :scope` mints today; the styleguide passes `select_scope_#{theme}`, as its copy does, so the twins' ids stay unique. The app's `aria-label` wins over the copy's shorter one.
- `app/views/events/_roster_toggle.html.erb` (new), `(event:, roster_id:)`: the `details.collapse.collapse-arrow.peer` and its `summary` from `app/views/events/show.html.erb`, which passes `dom_id(@event, :roster)`. The roster's own `peer-open:block` div stays on the screen, since `events/rsvp` sits between them.
- `app/views/shared/_block_button.html.erb` (new), `(url: nil, data: {})`, yielding its content: a `link_to url` when given one, as on `app/views/groups/index.html.erb`, and otherwise a `button_tag type: "submit"`, as on `app/views/registrations/new.html.erb`, which passes its `invite_target` data. Called as `render "shared/block_button", ... do`, which hands the partial the block.
- `app/views/events/_duplicate_notice.html.erb` (new), `(original:)`: the `role="status"` alert from `app/views/events/duplicate.html.erb`, its copy included, so the styleguide draws the real sentence. Its `mb-4` is placement rather than component, so `app/views/events/duplicate.html.erb`'s wrapper becomes `flex flex-col gap-4`, which spaces its two children the same.
- `app/views/layouts/_dock.html.erb` (new), `(group:, section:, static: false)`: the `nav.dock` around `layouts/group_tabs`, classed `sm:hidden` on a screen and `static` when the styleguide asks, the `static` WHY comment moving in with it. The layout's `max-sm:pb-20` comment keeps its place and names `layouts/dock` as what it keeps off the content.
- `app/views/layouts/_header_with_switcher.html.erb` (new), `(memberships: nil, **header)`: the `group-switcher` controller `div`, `layouts/header` rendered with `header`, and `layouts/group_switcher` when `header[:switcher_id]` is set, exactly as the layout does today. The controller's WHY comment moves with it. Strict locals take a `**` splat, per Action View's own template tests, so the header's own locals stay its one list.

## The styleguide

`app/views/styleguides/components/_select.html.erb`, `_collapse.html.erb`, `_button.html.erb` and `_alert.html.erb` each render their app partial under "As the app uses it" in place of the copy, gaining `group:`, `theme:` and `original:` locals where the partial needs them; their "Not used yet" variants stay hand-written. The collapse sample draws its own hidden `peer-open:block` target with a per-theme id, so its `aria-controls` points at an element on the page, and its card body takes the app's `gap-3`. `app/views/styleguides/show.html.erb` renders `layouts/header_with_switcher` (new) and `layouts/dock` (new) in its two layout sections. Every other section is #374's and stays as it is.

## The template example

The example in `spec/requests/styleguides_spec.rb` that holds the page to every partial reads `app/views/styleguides/show.html.erb` alone, and the four component partials now render app partials from inside `app/views/styleguides/components/`. It reads those files with the template, so `render "events/scope_select"` is found where it is written rather than through a `rendered_by` entry that would only prove the component is drawn. `layouts/header`, `layouts/group_switcher` and `layouts/group_tabs` leave the template's text, so each gains a `rendered_by` entry naming the wrapper that draws it, as `addresses/form_fields` names `events/form`.

## Seen red

No example is added: this is a behaviour-preserving refactor, and the existing request and system specs over the five screens and the shell are what prove each still renders the same. The template example is the gate held to each new partial, seen red for each one between creating it and the styleguide rendering it, and red for the component partials' renders until it reads `app/views/styleguides/components/`.

## Steps

- Widen the template example to read the component partials, still green on the unchanged page.
- Extract `app/views/events/_scope_select.html.erb` (new), watch the template example go red, render it from `app/views/styleguides/components/_select.html.erb`, and run the events and styleguide specs.
- Do the same for `app/views/events/_roster_toggle.html.erb` (new) with the collapse component, `app/views/shared/_block_button.html.erb` (new) with the button component, and `app/views/events/_duplicate_notice.html.erb` (new) with the alert component.
- Extract `app/views/layouts/_dock.html.erb` (new) and `app/views/layouts/_header_with_switcher.html.erb` (new), watching the template example go red, then render both from `app/views/styleguides/show.html.erb` and add the three `rendered_by` entries.
- Run `bin/ci` on the final head.

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-21_GHI-365_inline-daisyui-partials.md`
- `bin/rspec spec/requests/styleguides_spec.rb spec/requests/events_spec.rb spec/requests/groups_spec.rb spec/requests/registrations_spec.rb` passes, its template example having been seen red for each new partial as `## Seen red` lists
- `bin/rspec spec/styleguide` passes, its accessibility audit included
- `bin/rspec spec/system/events_list_spec.rb spec/system/event_detail_spec.rb spec/system/groups_index_spec.rb spec/system/add_someone_spec.rb spec/system/event_form_spec.rb spec/system/group_shell_spec.rb` passes
- `bin/ci` is green

No gate compares a screen's markup before and after, so whether each extracted site looks as it did, and whether the styleguide's `static` dock twin still reads as the phone's dock, is the owner's to judge by opening the five screens and `/styleguide`.

## Open questions

None.
