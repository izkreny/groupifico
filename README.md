# What is Groupifico?

Groupifico is an online place where you can manage essential chores of your group. 😊

Your group being:
1) **CHOIR**
---
2) **BAND**
3) Football, poker, or a chess **TEAM**
4) Or any other **GROUP*- of people doing something together

## What chores?

Groupifico is strictly focused on fundamental parts of your group:

- Members
- Events
---
- Notifications
- Documents (e.g. Songbook)
- Polls (quick and easy feedback)
- Membership fees (Treasury)

_MAYBE?_

- Comments / Notes
- Files / Attachments
- Other Documents (e.g. Articles / Posts)

## Architecture

### Web framework

- Plain and simple Ruby on Rails web app with mobile first interface
  - ERB + partials + layout
  - DaisyUI

_MAYBE?_
- Snappy Rails PWA with push notifications via Hotwire
---
- ViewComponents
- Hotwire Native mobile app
- Integrated PM or Chat?!?

### Core Domain Models

#### Group
- Multi-tenancy is achieved via Groups

#### User
- Global application identity via unique email and mobile phone
- User can login to the app via magic link/code sent to email
- User can become a Member of one or more Groups

_MAYBE?_
- Login via Google Account and/or Passkey
- Login with code sent to mobile phone via SMS
- Add more fields via (Groups?) Profile(s)
- Soft delete (anonymize)

#### Member --> Group membership
- Members belong to the Group and have status and roles
- They can create/interact with Events, Polls, etc.

_MAYBE?_
- Start / end date of membership
- Membership history
- Multiple roles aka role system based on modules

#### Event
- Main organizational group entity
- Only (event) admin can create events

_MAYBE?_
- Deadline for RSVP (status)
- Duplicate event
---
- Reccuring events
- Attachments or links to other entities e.g. Songs, File uploads?
- Belong to season (either whole year or some specifit date range)
- iCalendar one-way sync
- Status workflow (rules)

#### ATTENDEE
- Member can attend an Event
- Member can be invited and respond
- Attendance can be reserved and presence later confirmed
---
- Track RSVP (status) changes...

### Other Domain Models

#### Songbook

- Song should have following basic fields:
  - Title
  - Lyrics
  - Notes

_MAYBE?_
- Extra fields:
  - Duration
  - Key
  - Author
  - Arrangement
- Attachments

#### Polls
- Upcoming events (when more dates are considered)
- All other kinds of stuff

#### Treasury
- Membership fees

### MAYBE?
- Translations aka il8n
- Comments
- Seasons
- Reports
  - For ZAMP!!!
- Attachments
- Dashboard
---
- Tasks

### Entity Relationship Diagram

```mermaid
---
title: Groupifico ERD
config:
  layout: elk
---

erDiagram
    USER   1  to 0+ MEMBER   : "become / belong"
    MEMBER 0+ to 1  GROUP    : "belong / has"
    GROUP  1  to 0+ EVENT    : "has    / belong"
    EVENT  1  to 0+ ATTENDEE : "has    / belong"
    MEMBER 1  to 0+ ATTENDEE : "become / belong"
    GROUP  0+ to 1  ADDRESS  : "has    / belong"
    EVENT  0+ to 1  ADDRESS  : "has    / belong"

    USER {
        integer id           PK "NOT NULL"
        string  uid          UK "NOT NULL"
        string  first_name      "NOT NULL"
        string  last_name       "NOT NULL"
        string  email        UK "NOT NULL"
        string  mobile_phone UK "NOT NULL"
    }

    GROUP {
        integer id          PK "NOT NULL"
        string  uid         UK "NOT NULL"
        enum    type           "NOT NULL, values: [group, choir, band], default: _via_domain_name_"
        string  name           "NOT NULL"
        text    description    "NULL"
        integer address_id  FK "NOT NULL"
    }

    MEMBER {
        integer id       PK "NOT NULL"
        integer user_id  FK "NOT NULL"
        integer group_id FK "NOT NULL"
        enum    status      "NOT NULL, values: [pending, active, paused, inactive], default: pending"
        enum    role        "NOT NULL, values: [owner, admin, moderator, member], default: member"
    }

    EVENT {
        integer  id          PK "NOT NULL"
        integer  group_id    FK "NOT NULL"
        string   uid            "NOT NULL"
        integer  creator_id  FK "NOT NULL, source: member_id"
        integer  manager_id  FK "NULL, source: member_id"
        string   name           "NOT NULL"
        text     description    "NULL"
        enum     status         "NOT NULL, values: [unconfirmed, confirmed, concluded, canceled, declined], default: unconfirmed"
        enum     type           "NOT NULL, values: [rehearsal, gig], default: rehearsal"
        datetime start          "NOT NULL"
        datetime end            "NOT NULL"
        integer  address_id  FK "NOT NULL"
    }

    ATTENDEE {
        integer id        PK "NOT NULL"
        integer event_id  FK "NOT NULL"
        integer member_id FK "NOT NULL"
        enum    status       "NOT NULL, values: [reserved, invited, yes, maybe, no], default: reserved"
    }

    ADDRESS {
        integer id PK "NOT NULL"
        string name "NOT NULL"
        %% Add other details as city, country, street, etc.
        %% Implement later geo coordinates aka location
    }
```
