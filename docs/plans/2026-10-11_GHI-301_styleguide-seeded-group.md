> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Draw the styleguide from the seeded group

## Where the page reads from

`StyleguidesController::GROUP_ID` becomes the key's one home, and `db/seeds/styleguide.rb` creates the group under it instead of under its own `STYLEGUIDE_GROUP_ID`, the move #300 settled for the moment the page became the key's second reader. `StyleguidesController#show` finds the group by it, and `app/views/styleguides/show.html.erb` loads `@group.events.preloaded` and picks each record by status rather than by name: the hero is the confirmed event still ahead, the rows are one event per status with the ongoing one standing for confirmed, and each registration the page draws comes from its event's loaded `registrations`, `invited` for the question and `yes` for the answer. Nobody acts on the page, so no pick goes through a member. The two forms keep their in-memory events, since a form draws a record not yet saved, now built on the seeded group. The negative ids go, and so does the comment explaining them.

## Permissions

The `allowed_to?` override stays: the page draws every control for whoever opens it, and signing in as the seeded owner would make it depend on the visitor holding that membership. Its comment and the `skip_verify_authorized` comment both describe samples that belong to nobody, so both are rewritten. "Invite everyone" on the hero card and "Invite the rest" on the roster draw neither before nor after, because their conditions read the event's registrations rather than a permission, so their absence is no regression against the second criterion.

## Without the group

`Group.find_by` answers nil on a database seeded before #300 or never seeded, and the action renders `app/views/styleguides/missing.html.erb` (new) instead, naming `bin/rails db:seed:replant` and saying it replaces every record in that database. That is the command `db/seeds.rb` names for a database that already holds records, which is the likely case, since a plain `bin/rails db:seed` refuses one.

## How the specs get the group

The test database is empty when the suite runs, because `bin/ci` resets it after its seed step, so every example that needs the group plants it through `spec/support/styleguide_helper.rb` (new): the group under `StyleguidesController::GROUP_ID`, an active owner as every event's creator and manager, one event per status plus an ongoing one, and on the hero event an `invited` and a `yes` registration from two more members. Without the plant the label check in `spec/requests/styleguides_spec.rb` would pass on a page holding no form. It goes through factories rather than `db/seeds.rb`, because whether committed specs read the seeds is #346's open question, and a second `load` of that file in one process reassigns its constants and seeds nothing once the database holds a record.

## Seen red

- The missing-page request example fails on the unchanged page, which renders samples whatever the database holds.
- A request example finding a planted member's name in the roster, the said-yes line and the credits fails on the unchanged page, whose negative ids read nothing.
- A request example finding the roster's per-row controls fails on the unchanged page, whose roster has no rows to draw them on.
- The paint examples in `spec/styleguide/styleguide_spec.rb` pass before and after, so their red comes from the step order: the view change lands before the plant, and the missing page has no `.card` to paint.

## Steps

- Reset the test database with `bin/rails db:test:prepare`.
- Write the request examples for the missing page, the drawn records and the per-row controls, and watch all three fail against the unchanged page.
- Move the key into `StyleguidesController::GROUP_ID` and point `db/seeds/styleguide.rb` at it.
- Read the group in `StyleguidesController#show`, render `app/views/styleguides/missing.html.erb` (new) without it, pick the page's records from it in `app/views/styleguides/show.html.erb`, and rewrite the two controller comments.
- Run `bin/rspec spec/styleguide` without the plant and watch the paint examples fail.
- Add `spec/support/styleguide_helper.rb` (new), plant in every example that needs the group, and watch the request and styleguide specs pass.
- Run `bin/ci`.

## Verification

- `bin/rspec spec/requests/styleguides_spec.rb` passes, its missing-page, drawn-records and per-row-control examples having failed on the unchanged page
- `bin/rspec spec/styleguide` passes on a database just reset by `bin/rails db:test:prepare`, its paint examples having failed with the view changed and the plant not yet added
- `bin/ci` is green

No gate renders the seeded group itself, only the smaller planted one, so how 44 roster rows and a long said-yes line look under both themes is the owner's to judge by opening `/styleguide` on a seeded development database.
