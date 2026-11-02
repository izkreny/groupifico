> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: give canceled events their own list (#384)

## The change

`Event.current_and_upcoming` and `Event.past` both become `not_canceled.where(...)`, and the enum's own `canceled` scope is the third list. Each event is then on exactly one list: canceled first, and otherwise by its dates, so the comment above the scopes stays true once it says three.

`EventsController#index` replaces its `@past` flag with `@list`, which is `nil` for Upcoming and otherwise a value picked from literals by `presence_in`, so `params[:scope]` still never names a scope. A `case` picks the relation. The Canceled list orders like Past, newest first, and looks up no hero, because `@featured_event` hangs off `@list` being `nil`.

`app/views/events/_scope_menu.html.erb` takes `list:` in place of `past:`, and `app/views/styleguides/show.html.erb` passes it. A canceled row needs nothing: `open_to_answers?` already rules out the question and the answer icon already draws.

## The factory traits

`:from_the_past` and `:from_the_future` in `spec/factories/events.rb` each sample `:canceled` from their status list. A trait's name now promises a list that a canceled event is not on, so the examples in `spec/models/event_spec.rb` that use them bare would fail at random. Both traits stop drawing it, which is the root cause rather than a status pinned on each caller. `db/seeds/sample_groups.rb` uses the same traits and keeps a canceled rehearsal per group by its own explicit status, and `db/seeds/styleguide.rb` keeps "Open rehearsal", so the new list still has something on it in development.

## Commits

The rename is behaviour-preserving and lands alone, per `.agents/testing.md`: the factory first, then `@past` to `@list` with only `past` admitted, then the feature.

## Seen red

Each example below is watched failing. Those that pass on the pre-fix code name the mutation that turns them red, in a throwaway edit that is never committed.

- Model: `.current_and_upcoming` leaves out a canceled event that has not ended. Red before the fix.
- Model: `.past` leaves out a canceled event that has ended. Red before the fix.
- Model: the partition example, extended to three lists and given a canceled event each side of now. Red before the fix, where those two are counted twice.
- Model: an event moved off canceled returns to the list its dates name. Passes before the fix; `unconfirmed` in place of `not_canceled` in both scopes turns it red, since it moves one to `confirmed` and one to `concluded`.
- Request: the "called off" context, reversed so the row is gone and the screen says "Nothing coming up.". Red before the fix.
- Request: the list menu's links, extended with the third. Red before the fix.
- Request: the canceled list holds canceled events either side of now, newest first, with no hero, and the pill and `aria-current` name it. Red before the fix.
- Request: a canceled row shows the answer given and puts no question. Red before the fix, because its ended event is not on the upcoming list that `scope=canceled` reads there; `open_to_answers?` answering true for a canceled event also turns it red.
- Request: an empty canceled list reads "No canceled events.". Red before the fix.
- Request: an unknown `scope`, extended to read the pill. Passes before the fix; dropping `presence_in` turns it red, since the pill then names no list.
- System: landing on the canceled list from the menu, in `spec/system/events_list_spec.rb`. Red before the fix, with no link to click.

## Steps

- Stop the event traits drawing a canceled status
- Replace the `@past` flag with the open list's name, with no change in behaviour
- Add the canceled list: scopes, parameter, menu entry, empty text, comments and specs
- Run the examples and mutations in "Seen red"

## Verification

- `bin/rspec spec/models/event_spec.rb spec/requests/events_spec.rb`
- Every example in "Seen red" was seen red, by the condition it names
- `bin/rspec spec/system/events_list_spec.rb`
- `bin/rspec spec/styleguide`, which renders the menu through `app/views/styleguides/show.html.erb` and which `bin/ci` does not run
- `bin/ci`

No gate here can tell whether a member who said yes notices that an event has gone. Nothing mails them, and that notice is out of scope per the issue.
