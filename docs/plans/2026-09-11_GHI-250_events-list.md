> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Redesign the events list

Implementation plan for [#250](https://github.com/izkreny/groupifico/issues/250). The issue holds the acceptance criteria; this answers how.

## Approach

One screen, no new route and no new policy rule. `events/index` loses its scaffold heading and gains the frame's three pieces: the "Upcoming events" select in a surface pill that doubles as the page title, a "New" button for a reader `EventPolicy#create?` admits, and the reader's own answer row moved out of the hero card to below the row list. The controller gains the filter its own TODO has been asking for, so the select has something to choose between.

Two of row 6's partials are touched deliberately, the way [#247](https://github.com/izkreny/groupifico/issues/247) touched #248's edit screen: `events/_counts` gains the nobody-asked line, and `events/_next_up` gains one local so this screen can draw the answer row itself. `events/_row` is left exactly as it is.

## The filter

`EventsController#index` reads one whitelisted parameter and branches:

```ruby
@scope  = (params[:scope] == "past" ? "past" : "upcoming")
@events = authorized_scope(@group.events).includes(:address, :registrations)
@events = @scope == "past" ? @events.past.order(starts_at: :desc) : @events.upcoming.order(:starts_at)
@next_event = @group.next_event if @scope == "upcoming"
```

The comparison is a literal rather than a lookup: `params[:scope]` is reader input, and anything reaching `public_send` or a scope name built from it is a door onto every scope the model has. Anything that is not `"past"` reads as upcoming, so a typed URL degrades to the default rather than to an error.

Ordering arrives with the filter because the list had none: the rows were whatever SQLite returned, and the issue asks for date order one way and newest first the other.

`@next_event` stays `Group#next_event`, unasked on the past list. The filter is the list's, and which event is next is still the group's.

## The select, and the button beside it

`app/views/events/index.html.erb` opens with a `form_with url: group_events_path(@group), method: :get` holding a `select_tag :scope` with the two options, and the "New" button to its right for `allowed_to?(:create?, @group.events.new)`, which is how `groups/show` already asks the same question.

The select submits on change through a new one-action Stimulus controller, `app/javascript/controllers/form_controller.js`, whose `submit()` calls `this.element.requestSubmit()`; the select carries `data-action="change->form#submit"` and the form `data-controller="form"`. Turbo Drive takes the GET from there. It is generic rather than named after this screen because it holds no knowledge of one.

The select replaces the `h1`, so it carries its own accessible name through `aria-label`: nothing else on the screen names it, and `be_accessible` is the gate that says so.

Markup goes through the daisyUI Blueprint MCP server with the `daisyui-blueprint-mcp` skill loaded first, per the epic, and the surface is #246's `bg-base-200`. Nothing else of the frame's pill styling is reproduced: sizes, weights and radii are the component's.

An empty list keeps a line of copy, one per scope, because a screen holding a select and nothing else reads as one that failed to load.

## Nobody asked yet

`events/_counts` gains the branch the issue asks for: where every registration is still `reserved` the tallies all come back zero, and instead of drawing nothing the partial draws "Nobody asked yet · N on the list", N being `event.registrations.size` off the already-loaded association. An event with no registrations at all keeps drawing nothing, because "0 on the list" is not a sentence worth printing.

The names line needs no guard. `EventsHelper#said_yes_line` answers nil when nobody has said yes, and nobody has, so it is already absent.

`events/_counts` is rendered only from `events/_next_up`, so the line reaches the group home's hero card too. That is the same card stating the same fact, and it is wanted there.

Frame 4n draws its next-up card on an *unconfirmed* event. `Group#next_event` is `confirmed.upcoming` by #246's decision, and `spec/requests/events_spec.rb` asserts that an unconfirmed-only group draws no card at all. That rule is not reopened here; the nobody-asked example uses a confirmed event whose registrations are all `reserved`.

## The answer row below the list

The fifth criterion puts the reader's RSVP pills below the list rather than inside the hero. `events/_next_up` takes a new strict local, `answer_row: true`, and renders `events/rsvp` only when it is true. `groups/show` passes nothing and keeps the answer row inside its hero, which is the legend's matrix as #246 wrote it; `events/index` passes `false` and renders `events/rsvp` itself after the `<ul>`.

The partial's own comment argues that a card which can forget to draw all three pieces is a card that will, so the comment is rewritten in the same edit to say which screen opts out and why. A local nothing explains is worse than no local.

## What is deliberately not done

Frame 4h draws a pencil on every compact row for an owner. `events/_row` omits it by #246's decision, and the third criterion asserts only that a plain member sees no edit control, which an unchanged `_row` satisfies for every reader. Adding pencils would be reopening row 6's call inside a screen that did not ask.

Frame 4n's "Invite everyone" button is row 14's by the issue's own technical notes.

## The hero, when something is already running

Added after the round, on the owner's decision in RF6's thread. The list now carries an event between its start and its end, and the hero went on advertising the next one, so the screen's largest element named a later event than the one the reader was at.

`Group#featured_event` is `events.confirmed.unfinished.order(:starts_at).first`: `next_event` with `unfinished` in place of `upcoming`. It needs no fallback branch, because an event already running has a `starts_at` in the past and so sorts ahead of every upcoming one. Both hero sites read it, `events#index` and `groups#show`, because leaving the group home on `next_event` would recreate the same disagreement one screen over.

`Group#next_event` stays as it is. The groups index card reads it through `GroupsHelper#next_event_line`, whose copy is "next: Tue 2 Sep", and a running event is not a date to look forward to.

The card's kicker becomes `EventsHelper#event_kicker`, over a new `Event#ongoing?` mirroring the scope: "Next up · in 2 days" as before, or "Happening now · ends in about 2 hours" while it runs. The old line counted with `time_ago_in_words(starts_at)`, which for a started event counts the wrong way.

## Steps

- Load the `daisyui-blueprint-mcp` skill, then run the Blueprint MCP sequence under one workflow id for the whole issue: setup expert, rules enforcer, and component syntax expert for `select`, `btn`, `card`, `list` and `badge`.
- Add the scope filter, the ordering and the conditional `@next_event` to `EventsController#index`, replacing its TODO.
- Add `app/javascript/controllers/form_controller.js` with its single `submit()` action.
- Rewrite `app/views/events/index.html.erb`: the select pill, the "New" button behind `create?`, the hero, the rows, the answer row below them, and an empty-state line per scope.
- Add the nobody-asked branch to `app/views/events/_counts.html.erb`.
- Add the `answer_row:` local to `app/views/events/_next_up.html.erb` and rewrite its comment.
- Extend `spec/requests/events_spec.rb`: the New button for an owner and its absence for a plain member, the past list newest first with no hero, the select's own markup, and the positive half of the nobody-asked example that today only asserts the absence of tags.
- Watch the nobody-asked and past-list examples fail: run them against the pre-change partial and controller and see each go red.
- Extend `spec/system/events_list_spec.rb`: the select paints, and choosing "Past events" lands on the past list.
- Watch the new system examples fail: break the select's component class and see the paint assertion redden rather than the copy assertion.
- Run the Blueprint quality inspector with `auditIntent: "fix_changes"` over the changed templates, and judge its findings against the `daisyui-blueprint-mcp` skill.
- Verify the screen in headless Chromium per the `browser-verification` skill, in both themes and at both widths, reading the select's accessible name off the accessibility tree.
- Add `Event#ongoing?`, `Group#featured_event` and `EventsHelper#event_kicker`, and point `events#index`, `groups#show` and `events/_next_up` at them.
- Extend `spec/models/group_spec.rb` for `#featured_event`, `spec/models/event_spec.rb` for `#ongoing?` and `spec/helpers/events_helper_spec.rb` for the kicker's two readings.
- Rewrite the running-event request example, which inverts once a running event becomes the hero, and add the one that proves the hero defers to it.
- Run `bin/ci`.

## Verification

- [ ] `bin/ci` is green, which covers `lint`, `scan_ruby`, `scan_js`, the request specs and the browser suite.
- [ ] `bin/rspec spec/system/events_list_spec.rb` passes on its own, since `bin/ci` is the only run that reaches `spec/system`.
- [ ] The nobody-asked assertion and the past-list assertion are each watched failing before their code lands.

What these gates cannot see: whether the select is usable with JavaScript off, which it is not, since `requestSubmit` is what navigates and there is no submit button beside it. Nor whether the pill reads as a page title rather than as a control, which is the judgement the frames were drawn to settle and only a person looking at the screen can make.

## Open questions

- Frames 4h, 4n and 4i put the "Are you coming?" block inside the invited *row* it belongs to, not below the list for the next event, and under the literal criterion frame 4n's nobody-asked state draws no pills at all; implemented as the criterion words it, so say if the frame was the intent.

## Settled

- An event that has started and not yet ended was in neither `Event.upcoming` nor `Event.past`, so it disappeared from both lists. Decided in RF1's thread: the upcoming list carries it, through `Event.unfinished`, which is the exact complement of `past`.
- The hero then advertised a later event than the running one directly beneath it. Decided in RF6's thread: the hero shows the running event, with its own kicker, and both hero sites follow the same rule.
