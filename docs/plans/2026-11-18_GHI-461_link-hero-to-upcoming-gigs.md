> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: link the hero to the upcoming gigs (#461)

## Approach

The issue was written against one hero card; #459 has since given the home two, the rehearsal card first and the gig card second, and dropped the "See all events" link that sat under the old one, so AC1's removal half already holds on `main` and needs no code. "The hero card" in AC1 is therefore the gig card, and the link goes only there.

In `app/views/events/_next_up.html.erb` the card ends, after the answer row, with a "See all upcoming gigs" link to `group_events_path(event.group, category: [ "gig" ])` per N1, drawn only when `event.gig?`. The partial also draws the rehearsal card and the styleguide's hero, which is the seed's confirmed rehearsal, so the category check keeps both unchanged, where N2's "only the group home renders it" no longer holds. The link reuses the markup `7c4b005` removed from under the old card, `link link-hover inline-flex items-center gap-1 text-card-fact` with the `:go_to` icon after the label, plus `self-start` and the `relative z-1` lift every control on the card carries, since the event name's stretched link would otherwise swallow the press and open the event.

In `app/views/groups/show.html.erb` each empty slot's `card-body` becomes a `<div>` holding its line as a `<p>`, so the gig slot can carry a second row: a plain "See all events" link to `group_events_path(@group)`, unfiltered, with the same markup, for AC4. The rehearsal slot keeps its single line. Inside the card, under the message, is where Garmin Connect's and Meetup's home empty states put their action on Mobbin.

## Steps

- ::S1:: In `app/views/groups/show.html.erb`, make each empty slot's `card-body` a `<div>` around its `<p>` line, and give the gig slot a "See all events" link to `group_events_path(@group)` under it. In `spec/requests/groups_spec.rb`, add an example that `#no_gig` holds one link, "See all events", to the unfiltered events list, named for AC4, and point #459's "says no gig is coming up" example at `#no_gig p`, since the slot's text now includes the link's (AC4)
- ::S2:: In `app/views/events/_next_up.html.erb`, end a gig's card with the "See all upcoming gigs" link per N1, lifted with `relative z-1`. In `spec/requests/groups_spec.rb`, add an example that the gig card's last element is that link to `group_events_path(group, category: [ "gig" ])` and that the rehearsal card carries no link to the events list, named for AC1; in `spec/requests/events_spec.rb`, add an example that reads the link's `href` off the group home, follows it, and finds Upcoming the current list with the "Remove Gig" chip, named for AC2. In `spec/system/group_home_spec.rb`, add an example that presses the link on the gig card, with no accessibility violations before the press, and lands on the events list with the "Remove Gig" chip, named for AC1 and AC2 (AC1, AC2)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-18_GHI-461_link-hero-to-upcoming-gigs.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-18_GHI-461_link-hero-to-upcoming-gigs.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/groups_spec.rb spec/requests/events_spec.rb` passes; the AC1, AC2 and AC4 examples are seen failing against the views as they are on `main`
- ::V4:: `mise exec -- bin/rspec spec/system/group_home_spec.rb` passes; the AC1 and AC2 press example is seen failing against the branch's `_next_up.html.erb` with the link's `relative z-1` removed
- ::V5:: `mise exec -- bin/rspec spec/requests/styleguides_spec.rb spec/styleguide` passes, since the styleguide draws `_next_up` too
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove where each link points, which card carries it and that a press reaches it through the card's overlay; whether the link reads well as the card's last row, and the empty gig slot with a second row, is the owner's to judge from the screenshots the round posts.

## Open questions

- ::Q1:: AC4 says the "No gig coming up" slot *keeps* a plain link to the events list, but #459 shipped that slot without one and dropped the link under the cards because the shell's Events tab already leads to the list (#459 N7). Which should the empty gig slot do? 1. Carry a "See all events" link to the unfiltered list, as this plan builds. 2. Carry no link, with AC4 struck from the issue like AC3.

## Settled

- **Q1, the empty gig slot's link.** Should the empty gig slot carry a link to the events list? Settled by the owner in the session, 2026-11-18: no. The "No gig coming up" slot stays as #459 shipped it, and AC4 is struck from the issue.
- **The link's shape.** The owner picked option C from the design proposal, 2026-11-18: a full-width 44px footer row under a hairline, in the kicker's type and the plain text colour, labelled "All upcoming gigs".
- **The link's count.** The owner asked for the row to carry the number of gigs its list holds, written as #486 writes its tab counts, "All upcoming gigs (4)", and for the row to show whatever the number.
- **Unconfirmed gigs ahead of no confirmed one.** The owner's rule: the gig slot says "No confirmed gig coming up" and carries the same counted row; with no gig ahead at all it keeps "No gig coming up" and no row, as Q1 settled.
- **Counts past 99.** The owner's rule for every count the app shows: 100 or more is written "99+", through one helper the other counts can share.
