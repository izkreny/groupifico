> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: keep the duplicate screen on failure (#331)

## Approach

The duplicate form posts the original's id back to `create` as a top-level `original_id` parameter, beside `event[...]` rather than inside it, so `EventsController#event_params` never sees it. `events/_form` gains an `original: nil` local, the same shape as its `namespace: nil`, and draws a `hidden_field_tag :original_id` only when one is given; `events/duplicate.html.erb` passes `@original`, while `new` and `edit` pass nothing and render exactly as they do today.

On a refused save, `create` looks the original up with `@group.events.find_by(id: params[:original_id])` and renders `:duplicate` when it finds one, `:new` otherwise. Looking it up within `@group` is what keeps a forged id from drawing another group's event onto the screen, and `find_by` rather than `find` means an id that resolves to nothing degrades to the new-event screen instead of throwing away what was typed. A successful save never reads the parameter, so what lands is unchanged, and `create` keeps authorizing `create?` on the new event: the original is only read to draw the screen, so no new policy question arises.

## Steps

- Add the request examples to the `POST /groups/:group_id/events` block of `spec/requests/events_spec.rb`: a refused save carrying the original's id re-renders the duplicate screen, with its title, the "Copied from" note, the "Create copy" button, a Cancel to the original, the typed name kept, the error under the field and the summary alert; a refused save without it re-renders the new-event screen's title, button and Cancel to the events list; a refused save carrying another group's event id re-renders the new-event screen and never shows that event's date
- Add an assertion to the existing duplicate-screen example in the `GET /groups/:group_id/events/:id/duplicate` block that the form carries the original's id
- Run those examples against the unchanged code and watch the duplicate-screen ones fail
- Add the `original:` local and its hidden field to `app/views/events/_form.html.erb`, pass `@original` from `app/views/events/duplicate.html.erb`, and teach `EventsController#create` to render `:duplicate` when the original is found
- Run the examples again and watch them pass, then run `bin/ci`

## Verification

- `bin/ci` passes
- `bin/rspec spec/requests/events_spec.rb` passes, its duplicate-screen examples having been seen red on the unchanged `create`

What these gates cannot see: whether the re-rendered screen's Cancel lands on the original in a browser, which the request examples prove only as the link's address; `spec/system/event_form_spec.rb` carries no Cancel example for the duplicate screen today, and this branch adds none.

## Open questions

None.

## Settled

- The original travels as a hidden `original_id` field posted to `create`, per the issue's technical note. An `Events::DuplicatesController` with `new` and `create`, which the house style's "no custom member actions" points at, would need no carried id, but it moves the route, every `duplicate_group_event_path` caller and the view, which is a refactor this fix does not require.
- An `original_id` that does not resolve within the group re-renders the new-event screen rather than answering 404, so a forged id learns nothing and a reader whose original was deleted in the meantime keeps what they typed.
