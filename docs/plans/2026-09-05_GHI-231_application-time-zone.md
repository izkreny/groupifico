> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: set the application's default time zone (#231)

## Approach

`config/application.rb` still carries Rails' generated `config.time_zone` line commented out, so `Time.zone` is UTC. Uncommenting it with the IANA name Europe/Zagreb is the whole change.

The two settings that look alike do different jobs, and only one of them moves. `ActiveRecord.default_timezone` governs storage and stays `:utc`, which is why nothing about the column or its stored values changes. `config.time_zone` sets `Time.zone`, which is what a time-zone-aware attribute converts to on read, what `form.datetime_field` renders into the input, and what the submitted `"2026-09-05T20:00"` string is parsed in. Both ends of the round trip move together, so a time typed as 20:00 is stored as 18:00Z in summer and read back as 20:00. Verified on this tree before planning: `bin/rails runner` reports `:utc` and `"UTC"` for the two respectively.

This defers the multi-zone question rather than answering it. Every member is in one zone today, so a single application default is the honest model; #135 (a zone on the group, the profile or the event) and #89 (reading the browser's zone) are the answer for the day a member is somewhere else, and both stay open. The `TODO: add event's time_zone context` in `app/models/event.rb` stays for the same reason.

The one behaviour that actually changes is `Event#same_day?`, which compares `starts_at.to_date` against `ends_at.to_date`. Those dates move from UTC midnight to local midnight, so an event that runs from 00:30 to 02:00 local on a summer night - two UTC dates, one local date - answers false today and true afterwards. That is the discriminating case and the example worth writing first.

## Steps

- Watch it fail first: add a `#same_day?` example built from absolute UTC instants that fall on one local date but two UTC dates, and see it red on the unmodified tree
- Uncomment `config.time_zone` in `config/application.rb`, set it to the IANA name Europe/Zagreb, and replace the generated example comment with why one application-wide zone is right today
- Run `bin/ci` and read whatever moves with the zone rather than assuming nothing does

## Verification

- `bin/ci` passes
- `bin/rails runner 'exit(Time.zone.name == "Europe/Zagreb" && ActiveRecord.default_timezone == :utc ? 0 : 1)'` exits 0, which is the round trip's two halves asserted together
- The new `#same_day?` example has been seen red before `config/application.rb` changed

The runner check reads the development environment, and the setting lives in `config/application.rb` rather than in any file under `config/environments/`, so every environment inherits it - but no gate here boots production to prove that. Nor can any gate here see the one thing a reader will: whether Europe/Zagreb is the zone the members are actually in, which is the owner's assertion and not a testable fact. The production database holds no events, so no stored value needs shifting and there is nothing for a data migration to get wrong.

## Open questions

None.

## Settled

- Which zone, and where does it live? The IANA name Europe/Zagreb, in `config/application.rb` so every environment inherits it. The IANA name rather than a Rails alias, because the alias table is a Rails detail and the IANA name is the thing everything else agrees on.
- Why not do #135 instead? Because every member is in one zone today, and a per-group or per-event zone is only worth its schema once that stops being true. #135 and #89 stay open as the multi-zone answer.
