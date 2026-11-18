> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: link the hero card to its event (#473)

## Approach

`app/views/events/_next_up.html.erb` becomes a stretched link per N1: the card takes `relative`, the event name's `link_to` takes `after:absolute after:inset-0`, so its pseudo-element covers the card while the name stays the one element a screen reader meets as the event's link. Every control drawn inside the card is lifted above that overlay with `relative z-1`: the Duplicate and Edit group, the address's map link, the Request responses button, the roster line, and the answer buttons' group in `app/views/events/_response.html.erb`, which gets it on that group alone so its question stays under the overlay and opens the event; on the event screen the class changes nothing, since nothing there is stretched. Hovering anywhere on the card hovers the name's link, so its existing `link-hover` underline is the card's hover feedback with no new class.

In `app/views/events/_counts.html.erb`, under the existing `roster_link:` local per N2, the line's `<p>` stays and its whole content moves into one roster `link_to`, its full-width child carrying the line's flex classes around the people icon, the words and the tags, its words underlined on hover through `group-hover:underline`; keeping the `<p>` keeps daisyUI's card-body paragraph rules and the card's measured row spacing. Without `roster_link` the line stays the `<p>` it is today, so the event screen's row (drawn `inline:`) and the styleguide's counts sample keep their markup, which is AC5.

## Steps

- ::S1:: Make the roster link the whole Who's coming line in `app/views/events/_counts.html.erb` under `roster_link:`, lifted with `relative z-1`. In `spec/requests/groups_spec.rb`, rewrite "links the card's responses to the event with its roster open" to assert the one roster link on the card carries the yes tag inside it, named for AC2 and AC4; add an example in `spec/requests/events_spec.rb` that the event screen's Who's coming row carries no link to `responses: "show"`, and one in `spec/requests/styleguides_spec.rb` that the counts sample's line carries no link, both named for AC5. In `spec/system/group_home_spec.rb`, add an example that presses the card's yes tag and lands with the roster unfolded, named for AC2, and repoint "spaces the card's Who’s coming? link and its tags 12px apart" at the words inside the link, since the link, not the `<p>`, is now the tags' parent (AC2, AC4, AC5)
- ::S2:: Stretch the name's link over the card in `app/views/events/_next_up.html.erb` per N1, lifting each control with `relative z-1`, and the answer buttons' group in `app/views/events/_response.html.erb`. In `spec/requests/groups_spec.rb`, add an example that the card holds exactly one link to the event's own path, whose text is the event's name, and that the card itself is no link, named for AC4. In `spec/system/group_home_spec.rb`, add an example that presses the card's status line and lands on the event's screen, named for AC1; one that presses Duplicate and Edit and lands on each one's form, and one that reads `document.elementFromPoint` at the centre of every control on the card and finds that control, the map link included, both named for AC3; and name the existing answer and Request responses examples for AC3 (AC1, AC3, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-16_GHI-473_link-hero-card-to-event.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-16_GHI-473_link-hero-card-to-event.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/groups_spec.rb spec/requests/events_spec.rb spec/requests/styleguides_spec.rb` passes; the AC2 and AC4 roster example and the AC4 event link example are seen failing against the partials as they are on `main`, and the two AC5 examples, which pass there, against `_counts.html.erb` with `roster_link:` defaulting to `true`
- ::V4:: `mise exec -- bin/rspec spec/system/group_home_spec.rb` passes; the AC1 and AC2 examples are seen failing against the partials as they are on `main`, and the AC3 examples, which pass there, against the branch's partials with the overlay kept and every `relative z-1` lift removed, in `_next_up.html.erb`, `_counts.html.erb` and `_response.html.erb` alike
- ::V5:: `mise exec -- bin/rspec spec/system/event_detail_spec.rb spec/styleguide` passes
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove where each press lands and what a screen reader meets, not that the card's hover reads as one target or that text on it can no longer be selected by dragging, which the overlay trades away: both are the owner's to judge on the local app.

## Open questions

None.

## Settled

None yet.
