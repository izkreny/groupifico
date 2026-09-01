> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: adopt :unprocessable_content for 422 (#212)

## Approach

A flat rename of `:unprocessable_entity` to `:unprocessable_content` across the 13 occurrences in `app/controllers` and the 15 in `spec/requests`. 422 is unchanged on the wire and nothing outside those two trees names the symbol, so no response body, header or client contract moves.

Two of the issue's premises turned out to be wrong, and the plan is written against what the code actually does instead. Both were checked against the `actionpack (8.1.3.1)` and `rack (3.2.7)` this repository locks.

**The controller occurrences are not at risk, and are not the source of the warning.** `ActionDispatch::Response.rack_status_code` translates `:unprocessable_entity` to `:unprocessable_content` before Rack sees it whenever the bundled Rack is 3.1 or newer, so `render status:` and `head` never reach the deprecation shim:

```
ActionDispatch::Response#status = :unprocessable_entity  ->  422, 0 warnings
Rack::Utils.status_code(:unprocessable_entity)           ->  422, 1 warning
```

The version switch is `ActionDispatch::Constants::UNPROCESSABLE_CONTENT` and the translation is `ActionDispatch::Response.rack_status_code`, both inside the actionpack gem. So the 13 `app/` occurrences keep resolving after Rack drops the alias, and renaming them is consistency with what Rails' own `UNPROCESSABLE_CONTENT` already resolves to here, not breakage prevention.

**The spec assertions are both the risk and the whole warning.** `have_http_status` resolves the symbol through `Rack::Utils` directly, with no Rails translation in front of it. That is what breaks when the alias goes, and it accounts for every warning line: `spec/requests/user_profiles_spec.rb` has one symbol assertion and prints one warning, `spec/requests/groups_spec.rb` has two and prints two. Fourteen symbol assertions, fourteen lines, which is the count the issue names.

The fifteenth `spec/` occurrence is prose rather than a symbol: `spec/requests/groups_spec.rb:216` names `:unprocessable_entity` in an example description. The acceptance criterion is written against occurrences of the token, so it is renamed with the rest.

The issue also proposes watching a spec go red by renaming a controller's symbol without its spec's. That cannot fail, for the reason above compounded by `Rack::Utils.status_code` mapping both symbols to 422. What does falsify the regression test is changing the status itself.

## Steps

- Prove the request specs gate the status: make one controller answer `:ok` where it answers 422, run that file's request spec, watch it fail, revert
- Rename the 13 `app/controllers` occurrences across addresses, events, groups, members, registrations, user_profiles and users, including the one `head :unprocessable_entity` in `app/controllers/members_controller.rb`
- Rename the 14 assertions and the one example description in the seven `spec/requests` files
- Confirm the token is gone from the whole tree, not only `app/` and `spec/`

## Verification

- `bin/ci` passes
- `grep -rn unprocessable_entity app/ spec/` finds nothing
- `bin/rspec` prints no `Status code :unprocessable_entity is deprecated` warning

The warning gate has been seen to fail before the fix: the two spec files above printed one and two lines respectively on the unmodified tree.

The gates prove the app still answers 422 on every path a request spec already covers, and that the shim is no longer reached from this tree. They cannot prove a gem in the dependency tree stops reaching it, so the remaining warning count is the honest measure rather than zero being a guarantee about Rack itself.

## Open questions

None.

## Settled

- Is the issue's "watch one go red first" note usable? No. Both symbols resolve to 422 and Rails translates the old one before Rack sees it, so a controller renamed alone cannot make its spec fail. The plan falsifies by changing the status instead, and the issue body has been corrected.
