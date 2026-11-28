> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: draw a concluded event with the archive box icon (#539)

## Approach

`IconsHelper::ICONS` maps `concluded:` to `"archive-box"` instead of `"shield-check"` (N1). Every place that draws an event's status reads that one entry: the events list row (`app/views/events/_row.html.erb`), the event screen (`app/views/events/_event.html.erb`) and the group home's hero card (`app/views/events/_next_up.html.erb`) through `status_icon` (AC1), and the event form's Status choice through `EventsHelper#event_statuses`, whose segment meaning is the status itself, so it changes too and no view is touched. The label and colour classes are passed by those views and stay as they are, so only the glyph changes (AC2). The solid, mini and micro `archive-box` files are already synced (N2), and `docs/design/icon-sizes-and-spacing.html` keeps its `shield-check` as the record of an earlier study (N3).

### A WHY on the line that leaves the legend

The hash is introduced as the wireframes' legend, and every entry that is not the legend's glyph carries a `WHY:` saying so. The `concluded:` line gets one too: the legend draws a shield, which reads as verified or protected, where an archive box says done and put away.

## Steps

- ::S1:: In `spec/helpers/icons_helper_spec.rb`, under `#status_icon`, add an example drawing a concluded event's status in the solid, mini and micro sizes from `archive-box` (AC1), headed `# WHY: GHI-539 AC1.`
- ::S2:: In `spec/requests/events_spec.rb`, under the active member's index context, add an example finding a concluded event's row status drawn as the solid `archive-box`, named `concluded` and in `text-icon-muted` (AC2), headed `# WHY: GHI-539 AC2.`
- ::S3:: In `app/helpers/icons_helper.rb`, map `concluded:` to `"archive-box"` and add the `WHY:` above it that *A WHY on the line that leaves the legend* describes

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-28_GHI-539_draw-a-concluded-event-with-the-archive-box-icon.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-28_GHI-539_draw-a-concluded-event-with-the-archive-box-icon.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/helpers/icons_helper_spec.rb` passes, and AC1's example is seen failing on the pre-fix `concluded: "shield-check"`
- ::V4:: `mise exec -- bin/rspec spec/requests/events_spec.rb` passes, and AC2's example is seen failing on the pre-fix `concluded: "shield-check"`, on `_row` dropping `label: event.status`, and on `_row` dropping `text-icon-muted`
- ::V5:: `mise exec -- bin/rubocop app/helpers/icons_helper.rb spec/helpers/icons_helper_spec.rb spec/requests/events_spec.rb` exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether the archive box reads as done and put away beside the other three statuses on a real list, which is the owner's to judge on screen.

## Open questions

None.

## Settled

None yet.
