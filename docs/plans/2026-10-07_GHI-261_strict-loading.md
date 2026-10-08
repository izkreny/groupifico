> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: raise on lazy loading in the test suite (#261)

## Approach

`config/environments/test.rb` sets `config.active_record.strict_loading_by_default = true` and `config.active_record.strict_loading_mode = :n_plus_one_only`, leaving `action_on_strict_loading_violation` at its `:raise` default; `config/environments/development.rb` sets the same two lines with `config.active_record.action_on_strict_loading_violation = :log`. Production is untouched.

`:n_plus_one_only` flags a lazy load on any record that arrived through a `has_many`, which includes `@group.events.find` and `@group.members.find`, so a single-record page still answers for its own `belongs_to` reads. A probe run with these settings failed 78 of 984 examples and 50 of 173 browser examples, all in the events, members and groups screens the issue names.

The sites the probe raised first, each fixed with a preload where the records are loaded: `EventsController#set_event` (`address`, `registrations`, `creator`, `manager`, `group`), `MembersController#set_member` (`roles`, `profile`, `user`), the event list partial's `address` and the registration row's `member`, and the `has_many :members, dependent: :destroy` cascades on `User` and `Group`, whose `Member#ensure_the_group_keeps_an_owner` callback reads `roles` on every member it destroys. Fixing one site uncovers the next, so the list closes when both suites run green, not before.

## Steps

- Turn strict loading on in `config/environments/test.rb` and `config/environments/development.rb` as above, and watch `bin/rspec` and `bin/rspec spec/system` go red on the probe's failures
- Preload in `EventsController` until `bin/rspec spec/requests/events_spec.rb spec/requests/events` and the event system specs pass
- Preload in `MembersController` and `GroupsController` until their request and system specs pass
- Preload the `members` cascade on `User` and `Group` until `spec/models/user_spec.rb`, `spec/models/member_spec.rb` and `spec/requests/user_spec.rb` pass, and rewrite any spec that lazily reads an association of a record it loaded through one to query instead
- Fix whatever the full runs still raise, by the same rule
- Add the rule to `.agents/testing.md`: lazy loading raises under test and logs in development, and the one opt-out is `strict_loading(false)` on a relation, with a `WHY:` comment at the call site
- Run `bin/ci`

## Verification

- `bin/rspec` passes with strict loading on, its failures having been seen red on the unchanged controllers
- `bin/rspec spec/system` passes with strict loading on, its failures having been seen red on the unchanged controllers
- `bin/ci` passes

What these gates cannot see: `:n_plus_one_only` by design ignores a lazy load on a record fetched straight off a model class, such as `Group.find`, and nothing raises in a view no spec renders.

## Open questions

None.

## Settled

- `strict_loading_mode = :n_plus_one_only` rather than the default `:all`, which the issue leaves open. Under `:all` the same probe failed 467 of 984, most of them `Session#user` and `Member#roles` read on one record the authentication concern or a spec loaded: no N+1, and a record a spec built itself has no controller or scope to preload from, so the issue's third criterion would leave only `strict_loading!(false)` or rewritten specs.
