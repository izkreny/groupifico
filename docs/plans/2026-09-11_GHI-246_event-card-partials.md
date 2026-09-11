> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Build the event card partials

Implementation plan for [#246](https://github.com/izkreny/groupifico/issues/246). The issue holds the acceptance criteria; this answers how.

## Approach

Four partials under `app/views/events/`, each declaring strict locals and reading no instance variable, composed so that the screens that follow (#247, #250, #251) render one line each and cannot draw the same fact two ways. The composition follows the event-card matrix in the wireframes' icon legend rather than the partial names: `_next_up` is the only one that renders another partial, calling `_counts` and `_rsvp` itself, because every cell that shows tags also shows the answer row beneath them. `_row` renders neither - a compact row is a status icon, a name, one meta line and, once answered, the reader's reply icon. The event detail (#251) renders `_counts` and `_rsvp` directly, which is why they take an `event:` rather than being folded into the hero.

| Partial | Locals | Renders |
|---------|--------|---------|
| `_next_up` | `(event:, registration: nil)` | kicker, name, status line, when, where, `_counts`, the "said yes" line, `_rsvp` |
| `_row` | `(event:, registration: nil)` | status icon, name, `Sun 7 Sep · 10:00 · St Mark's`, reply icon |
| `_counts` | `(event:)` | the four count tags, or nothing |
| `_rsvp` | `(event:, registration: nil)` | one of three states, or nothing |

The reader's registration arrives as a local rather than being looked up inside a partial, so a screen that already has it does not query again and a partial has no opinion about who is reading. `Current.member` is where a screen gets the reader, per #227.

## `Group#next_event`, restored

The method and its five examples are recorded on the issue's first comment, in the form they had on #244 before the switcher's next-event line was dropped and left them with no caller. They are copied back rather than rewritten: `events.confirmed.upcoming.order(:starts_at).first`, with the comment that says why `confirmed` alone. The three traps that comment records are the reason the examples are copied verbatim - the base event factory leaves `status` at the model default `unconfirmed` so every example names it, there is no `:confirmed` trait, and the times are frozen with `freeze_time` or the examples pass on how fast the suite reaches the file. Filtering a preloaded `events` in Ruby was tried and rejected on #244 and is not revisited.

A model spec cannot show the failure a reader sees, so the events-index request spec watches the card with `#next_event` stubbed to `nil`, which is what a wrong filter looks like from the reader's side.

## What the counts and the names read from

`Event` gets three methods, because all three are questions about the event rather than about the view:

- `answer_counts` - one grouped query (`registrations.group(:status).count`), returning the four tallies with zeros for the statuses nobody holds. `reserved` is never a tally; `invited` **is** the "no reply" tally, per the legend.
- `nobody_asked_yet?` - `registrations.where.not(status: :reserved).none?`, which is what suppresses `_counts` entirely. It answers true for an event with no registrations at all as well, which is the same emptiness from the reader's side.
- `registration_for(member)` - `registrations.find { ... }` over the loaded association, so `events#index` preloading `registrations` costs one query for the whole list rather than one per row.

The "said yes" line is presentation and goes to `EventsHelper` as `said_yes_line(event)`, returning `nil` when nobody has: `event.registrations.yes` mapped through `Member#full_name` and `to_sentence`. The hero is the only cell that carries names, so the screens that fetch one event preload `registrations: { member: :profile }` and the list does not.

## Helpers

`EventsHelper` keeps its existing `event_schedule` untouched - `events/_event` still calls it until #250 and #251 delete that partial - and gains the two variants the frames draw:

- `event_schedule_range(event)` → `Tue 2 Sep · 19:00–21:00`, falling back to a second date when `same_day?` is false.
- `event_schedule_start(event)` → `Sun 7 Sep · 10:00`, the compact row's date and time, with the place appended by the partial as a link rather than baked into the string.
- `event_status_line(event)` → `Confirmed rehearsal`, or the capitalised status alone when the category is `other`.

`AddressesHelper` gains `address_map_url(address)`, because nothing in the app links an address yet and criterion 4 is its first caller. It returns a `https://www.google.com/maps/search/?api=1&query=` URL built from the coordinates when the record has them and from the street and city otherwise. A `geo:` URI is what the legend names for mobile and is deliberately not used: no desktop browser has a handler for it, where a maps URL is handed to the maps application by both mobile platforms.

## Authorization

The pills are the first view-layer check on `RegistrationPolicy`: `allowed_to?(:update?, registration)` decides whether `_rsvp` renders its three buttons, so a refusal is an absent control rather than a disabled one. `#update?` is `own? || can_manage?(:events)`, and the status pre-check refuses a `paused` member every write, so a paused reader sees the facts and no pills. The counts carry no check at all - every column of the events table in `docs/AUTHORIZATION.md` may see who is registered and their answers.

Each pill is a `button_to` to `group_event_registration_path` with `registration[status]`, which is the update `RegistrationsController` already authorizes; nothing new is routed and no controller action is added.

## Wiring, and what is left for the screen rows

`events/index.html.erb` renders `_next_up` for `@group.next_event` and `_row` for the remaining upcoming events, which is what frame 4h draws: the hero's event does not appear again in the rows. The scaffold's Show / Edit / Duplicate / Destroy button column and the page's heading stay exactly as they are - #250 owns that screen's layout, this row owns the partials it renders. `groups/show` and `events/show` are untouched for the same reason: #247 and #251 own them.

## Steps

- Compose every piece of markup through the daisyUI Blueprint MCP server, loading the local `daisyui-blueprint-mcp` skill first per the epic: setup expert, rules enforcer, component syntax expert for card, badge and the button group, then the quality inspector on the finished change.
- Restore `Group#next_event` with its comment, and its five examples in `spec/models/group_spec.rb`, copied from the issue's first comment.
- Add `Event#answer_counts`, `Event#nobody_asked_yet?` and `Event#registration_for(member)`, with examples in `spec/models/event_spec.rb`.
- Add `event_schedule_range`, `event_schedule_start`, `event_status_line` and `said_yes_line` to `EventsHelper`, and `address_map_url` to `AddressesHelper`, with examples in the two existing helper specs.
- Add `app/views/events/_counts.html.erb` and `_rsvp.html.erb`, the two leaves, each with strict locals.
- Add `app/views/events/_next_up.html.erb` and `_row.html.erb`, the hero rendering the two leaves.
- Render them from `events/index.html.erb`: the hero for `@group.next_event`, a row per remaining upcoming event, with `@events` preloading `registrations`.
- Extend `spec/requests/events_spec.rb`: the card, a row and the pills for an owner and for a plain member, the pills absent for a paused member, no card when `#next_event` is `nil`, and no count tags when every registration is `reserved`.
- Add `spec/system/events_list_spec.rb` - no system spec covers `events/index` yet, so this is the new file that convention asks for rather than an extension: that the card, the tags and the pills paint, that pressing a pill lands, and that the screen has no accessibility violations.

## Verification

- `bin/ci`

What those gates cannot see: whether the hero reads as a hero next to the rows it competes with, since default daisyUI settles the styling and the frames' sizes were never decisions; whether the maps URL opens the right application on a phone, which no driver here can try; and whether the "said yes" line stays readable for an event a dozen people answered, which the frames only draw with two names.

Every check is watched failing before it is trusted: the five `#next_event` examples against the method returning `events.upcoming.order(:starts_at).first`, which is the unconfirmed-admitting version they exist to reject; the request spec's no-card example against the card rendered unconditionally; the count-suppression example against `_counts` rendered for an all-`reserved` event; and the pill-absence example against the partial with its `allowed_to?` removed.

## Open questions

- Pressing a pill lands the reader on the registration show page, because that is where `RegistrationsController#update` redirects. Should this row make that action redirect back to where the pill was pressed, or does that belong to #250 and #251 with the screens?
- Frame 4n draws the all-reserved hero as `Nobody asked yet · 5 on the list` above an `Invite everyone` control. The control is #258's second criterion; the line itself is in no issue's criteria. Does it land here as part of the hero's all-reserved state, or with #258?

## Settled

None yet.
