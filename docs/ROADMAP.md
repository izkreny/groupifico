# Groupifico development roadmap

## Core Domain Models

### Group
- `username` column: unique, with an additional validation check at application level. Never built
- `time_zone` column. Maybe
- Move `description` into a separate `group_profiles` table?
- Default `group_type` from the hostname

### User
- Login via Google Account and/or Passkey
- Passwordless login: magic link or one-time code sent to email. The README described this as already built until #81, when it turned out the schema has had `password_digest` and a `sessions` table since March
- Add verification workflow when user enter mobile phone
- Login with code sent to mobile phone via SMS
- Add more fields via (Groups?) Profile(s)
  - [Get](https://stackoverflow.com/a/37512371/21188433) Time Zone from [browser](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat/resolvedOptions)
- Soft delete (anonymize)

### User Profile
- `username` column: unique, automatically generated random UID. Documented in the DBML file deleted by #81, never built
- `time_zone` column: resolved via the browser, or its own entity rather than a column. Never built; see the Time Zone item under User
- Add phone normalization and validation gem: [phonelib](https://github.com/daddyz/phonelib) or [PhonyRails](https://github.com/joost/phony_rails) (via [phony](https://github.com/floere/phony))

### Member aka _Group membership_
- Add uniquness custom validation
- Start / end date of membership
- Membership history
- Multiple roles aka role system based on modules

### Event
- `uid` column: unique within the Group. Never built
- `time_zone` column. Maybe
- Event categories as their own entity, maybe derived from `group_type`, and maybe optional
- Automatically fill `creator_id` before validation or save?
- Automatically fill end with 2.hours from start also before validate AR callback
- Only (event) admin can create events
- Deadline for RSVP (status)
- Duplicate event
- Reccuring events
- Attachments or links to other entities e.g. Songs, File uploads?
- Belong to season (either whole year or some specifit date range)
- iCalendar one-way sync
- Status workflow (rules)

### Registration
- Add [locking](https://guides.rubyonrails.org/active_record_querying.html#locking-records-for-update) to avoid rewriting of RSVP data?! Maybe it will be unnecessary with Hotwire...but again.
- Add uniquness custom validation
- Track RSVP (status) changes...

## Other Domain Models

### Address
- Use Geocoding JavaScript frontend library or [geocoder gem](https://github.com/alexreisner/geocoder) (via Hotwire?) to automatically parse address in free-form and fill **ALL** possible ISO 20022 fields.
- Provide as well visual map
- Incorporate Country info via https://github.com/countries/countries
- Add [counter_cache](https://guides.rubyonrails.org/association_basics.html#counter-cache) ?
- Derive `latitude` and `longitude` from geocoding instead of accepting them from the user. The deleted DBML file claimed the user cannot edit them, which was never true: both are permitted in `AddressesController` and rendered as form fields

### Links
- For group menu/linktree page
- For social links for group and user profiles
- Fields:
  - Name
  - URL
  - `url_type` (for icons) - maybe allow user to select custom icon? Or just make it easy to place emoji or icon inside te name field?! Or make separate feature depending it is linktree or social links, maybe based on `link_type` enum?
  - color (only for linktree feature?!) e.g. primary, secondary, info, warning...
- Implement statistics

### Song

- Song should have following basic fields:
  - Title
  - Lyrics
  - Notes
- Extra fields:
  - Duration
  - Key
  - Author
  - Arrangement
- Attachments

### Polls
- Upcoming events (when more dates are considered)
- All other kinds of stuff

### Treasury
- Membership fees

## GENERAL TODO

- Translations aka il8n
- Comments / Notes
- Other Documents (e.g. Articles / Posts)
- Seasons
- Reports
  - For ZAMP!!!
- Files / Attachments
  - Re-enable Active Storage variants. `config.active_storage.variant_processor` is `:disabled` in `config/application.rb`, because nothing needs a variant yet and the Rails 8.1 default of `:vips` makes libvips a boot dependency of every environment, CI included. To turn them on: set it back to `:vips`, add `gem "ruby-vips"`, and install libvips in the CI jobs that boot the application. The `Dockerfile` already installs it, so production needs no change. While it stays `:disabled` a transform returns the original image instead of raising, so this is a silent no-op rather than an error.
- Dashboard
- Later:
  - Tasks
- Integrated PM or Chat?!?
- Include `TEAM` as group_type: _Football, poker, or a chess **TEAM**_

## Web framework

- Snappy Rails PWA with push notifications via Hotwire
- ViewComponents
- Hotwire Native mobile app
