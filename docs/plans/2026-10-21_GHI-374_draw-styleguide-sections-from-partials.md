> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: draw styleguide sections from partials (#374)

## The partials

Each takes over its section's block verbatim, its records as strict locals, so the page renders byte for byte what it renders now. The sample records and `manages` / `oversees` stay built at the top of `app/views/styleguides/show.html.erb`, which passes them in.

- `app/views/styleguides/_fields.html.erb` (new), `(event:, theme:)`: the `form_with` over the invalid event, namespaced by `theme` as now, with its error summary and two fields.
- `app/views/styleguides/_event_rows.html.erb` (new), `(rows:)`: the `ul.list` drawing `events/row` once per `[event, registration]` pair.
- `app/views/styleguides/_rsvps.html.erb` (new), `(event:, question:, answer:)`: the column drawing `events/rsvp` for the question, then the answer.
- `app/views/styleguides/_group_cards.html.erb` (new), `(group:, owner:, paused:)`: the column drawing `groups/group` for each membership.
- `app/views/styleguides/_member_rows.html.erb` (new), `(owner:, paused:, manages:, oversees:)`: the `ul.list` drawing `members/member` for each.

Every other section already renders exactly one partial, the header and the dock included since #365.

## The template example

The example in `spec/requests/styleguides_spec.rb` that holds the page to every partial reads `app/views/styleguides/show.html.erb` and the component partials. Once `events/row`, `events/rsvp`, `groups/group`, `members/member` and the error summary move out of the template, it goes red, so its glob widens to every partial under `app/views/styleguides/`, as #365 widened it to the components. The issue's "pass unchanged" is read as every example's expectation staying as it is; this example's read set is the one line that moves, and its comment says why.

## Seen red

No example is added: this is a behaviour-preserving refactor, and the request and system specs over the page prove it draws the same. The template example is the gate on the moves, seen red after the first section moves and before its glob widens.

## Steps

- Move "Fields, with a hint and with an error" into `app/views/styleguides/_fields.html.erb` (new) and watch the template example go red on `shared/errors`.
- Widen the template example's glob to every partial under `app/views/styleguides/`, and see it green.
- Move the other four sections into `app/views/styleguides/_event_rows.html.erb` (new), `app/views/styleguides/_rsvps.html.erb` (new), `app/views/styleguides/_group_cards.html.erb` (new) and `app/views/styleguides/_member_rows.html.erb` (new).
- Run the styleguide request and system specs, then `bin/ci` on the final head.

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-10-21_GHI-374_draw-styleguide-sections-from-partials.md`
- `bin/rspec spec/requests/styleguides_spec.rb` passes, its template example having been seen red as `## Seen red` says
- `bin/rspec spec/styleguide` passes, its accessibility audit included
- `bin/ci` is green

No gate compares the page's markup before and after, so whether `/styleguide` looks as it did is the owner's to judge by opening it.

## Open questions

None.
