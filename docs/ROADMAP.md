# Groupifico development roadmap

## Core Domain Models

### Group

### User
- Login via Google Account and/or Passkey
- Add verification workflow when user enter mobile phone
- Login with code sent to mobile phone via SMS
- Add more fields via (Groups?) Profile(s)
  - [Get](https://stackoverflow.com/a/37512371/21188433) Time Zone from [browser](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat/resolvedOptions)
- Soft delete (anonymize)

### User Profile
- Add phone normalization and validation gem: [phonelib](https://github.com/daddyz/phonelib) or [PhonyRails](https://github.com/joost/phony_rails) (via [phony](https://github.com/floere/phony))

### Member aka _Group membership_
- Add uniquness custom validation
- Start / end date of membership
- Membership history
- Multiple roles aka role system based on modules

### Event
- Change `start` and `end` fields to the `starts_at` and `ends_at`
- Automatically fill `creator_id` before validation or save?
- Automatically fill end with 2.hours from start also before validate AR callback
- Consider changing `event_type` to `category` or just `event_tag` (because type is more for for example Reccuring or one-off)
- Only (event) admin can create events
- Deadline for RSVP (status)
- Duplicate event
- Reccuring events
- Attachments or links to other entities e.g. Songs, File uploads?
- Belong to season (either whole year or some specifit date range)
- iCalendar one-way sync
- Status workflow (rules)

### Attendee
- Add uniquness custom validation
- Track RSVP (status) changes...

## Other Domain Models

### Address
- Use Geocoding JavaScript frontend library or [geocoder gem](https://github.com/alexreisner/geocoder) (via Hotwire?) to automatically parse address in free-form and fill **ALL** possible ISO 20022 fields.
- Provide as well visual map
- Incorporate Country info via https://github.com/countries/countries

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
- Dashboard
- Later:
  - Tasks
- Integrated PM or Chat?!?
- Include `TEAM` as group_type: _Football, poker, or a chess **TEAM**_

## Web framework

- Snappy Rails PWA with push notifications via Hotwire
- ViewComponents
- Hotwire Native mobile app
