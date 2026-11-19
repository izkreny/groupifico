> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: show a refused response request as information (#452)

## Approach

The flash gains a third type, `info`, declared once with Rails' own `add_flash_types :info` in `ApplicationController`, so a redirect takes `info:` the way it takes `notice:` and `alert:`, and views read it through an `info` helper. `layouts/_flash.html.erb` draws it between the two it already draws, through `shared/alert` with `kind: :info`, `id: "info"` and `dismissible: true` like its siblings, and `role: "status"` as `events/_duplicate_notice` already does, since a state fact is not an interruption.

`Registrations::ResponseRequestsController#create` moves its three refusals, the answered member, the paused or inactive member and the event that is no longer open to answers, from `alert:` to `info:`. `alert` stays the red of a real failure everywhere else; nothing outside this controller moves, so no other screen changes colour.

The styleguide's flash section draws every flash type the layout knows, so `StyleguidesController#show` sets an `info` sample alongside its `notice` and `alert` ones, and the section is retitled to name all three; the icon legend's `info` line names the flash info as its `success` and `error` lines name theirs.

## Steps

- ::S1:: In `app/controllers/application_controller.rb`, add `add_flash_types :info`; in `app/views/layouts/_flash.html.erb`, draw `info` between `notice` and `alert` through `shared/alert` with `kind: :info, id: "info", role: "status", dismissible: true, classes: "mb-5"`; in `app/controllers/styleguides_controller.rb`, set a `flash.now[:info]` sample and retitle the section in `app/views/styleguides/show.html.erb` "Flash, notice, info and alert"; and in `app/helpers/styleguides_helper.rb`, name the flash info in the `info` icon's legend line, as the `success` and `error` lines name theirs
- ::S2:: In `app/controllers/registrations/response_requests_controller.rb`, send the three refusals as `info:` instead of `alert:`. In `spec/requests/registrations/response_requests_spec.rb`, point the answered example at `flash[:info]`, named for AC1, and the paused and concluded examples at `flash[:info]`, named for AC2, and add an inactive member and a canceled event example the same way, since AC2 names both and neither is covered (AC1, AC2)
- ::S3:: In `spec/system/event_detail_spec.rb`, add an example that opens the roster, lets Ben answer behind the page's back, presses his paper plane, and finds `#info` painting in the info colour rather than the error or success one, with no accessibility violations, named for AC1; and one that presses the banner's Dismiss and finds `#info` gone, named for AC3 (AC1, AC3)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-19_GHI-452_refused-request-as-info.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-19_GHI-452_refused-request-as-info.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/registrations/response_requests_spec.rb` passes; the AC1 and AC2 examples are seen failing against the controller as it is on `main`
- ::V4:: `mise exec -- bin/rspec spec/system/event_detail_spec.rb` passes; the AC1 example is seen failing against `main`'s controller, and the AC3 example against the branch's `_flash.html.erb` with the info banner's `dismissible: true` removed
- ::V5:: `mise exec -- bin/rspec spec/requests/styleguides_spec.rb spec/styleguide` passes, since the styleguide draws the flash partial
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The specs prove which flash type each refusal sets, that the banner paints in the info colour and that it dismisses; whether the blue info banner reads as neutral enough beside the green and red ones is the owner's to judge from the screenshots the round posts.

## Open questions

None.

## Settled

- None yet.
