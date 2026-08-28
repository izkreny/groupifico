> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Give members many roles

Implementation plan for [#93](https://github.com/izkreny/groupifico/issues/93). The acceptance criteria live on the issue; this file answers *how*.

## What is there today

Read from the code on `main` at `fbfe740`, not recalled.

`Member` carries `enum :role, %i[ owner member admin manager ], default: :member, validate: true` over a `NOT NULL` integer column created by `db/migrate/20260112155400_create_members.rb`. One column, one value, so a member who runs events and also runs songs cannot be described at all, and a member who runs events is forced to be `manager` and nothing else.

Nothing reads the role for an authorization decision yet. `ApplicationPolicy` asks two questions, both about belonging and status: `verify_membership!` denies with `:not_found` when there is no `Member` row, and `verify_active_membership!` denies write to a `paused` member. Its comment already names this issue as the one that gives write a role to consult. So the role column is currently written and displayed but never consulted, which is what makes replacing it a self-contained change.

The writers and readers are few and all of them are known: `GroupsController#create` builds the creator's membership with `role: :owner`, `MembersController` permits a scalar `:role` on both create and update, `app/views/members/_form.html.erb:11` renders a single-select over `Member.roles.keys` through `MembersHelper#member_roles`, `app/views/members/_member.html.erb:8` prints the one value, `db/seeds.rb:40` calls `owner!` on the first member of each group, and the README ERD documents the enum at `README.md:149`.

## Approach

**A `roles` table, one row per role a member holds, with the role's name as a string.** `roles` carries `member_id` and `name`, a unique index on `[ member_id, name ]` so a role cannot be granted twice, and the same `ON DELETE CASCADE ON UPDATE CASCADE` foreign key the other member-owned tables use. `Member has_many :roles, dependent: :destroy`. The reference codebases back the shape and the naming: hitobito gives a person `has_many :roles` off a plain `roles` table, and none of the Basecamp apps names such a table anything but a plain noun.

**The name is a string validated against a vocabulary constant, not an enum.** `Role::NAMES` holds `owner`, `administrator`, `events_administrator` and `songs_administrator`, and `name` is validated for inclusion in it. This is what makes the issue's fifth criterion cheap: a new module role is one entry in a frozen array, and a spec can prove it by extending the vocabulary with `stub_const` and asserting the predicate answers for a role the shipped code has never heard of. An integer enum on the join table would make that same spec a class-reopening exercise and would tie every role name to a positional value nobody may reorder.

**`member` is not in the vocabulary, so it cannot be stored.** Belonging is the `Member` row and its status, which #172 already made the base case in the policy layer.

**One predicate, and the implication lives in it.** `Member#can_manage?(area)` is the whole public surface, and it answers true when the member holds `owner`, `administrator`, or `"#{area}_administrator"`. So `owner` passes every check `administrator` passes without a second row ever being written, and an administrator-only question is `can_manage?(:members)`, an area with no module role of its own, which only `owner` and `administrator` can satisfy. That is the third and fourth criteria met by one method rather than by two APIs, and the reason a policy can never learn how the answer is stored.

**No policy consumes it on this branch.** `#173` and `#96` are the first consumers and they are separate issues. `WRITE_RULES`, `verify_active_membership!` and the `paused` comment in `app/policies/application_policy.rb` are untouched here, and no `SongPolicy` is written: `songs_administrator` exists in the vocabulary so the mechanism is proven with more than one module, and the model it would govern does not exist yet.

**The migration backfills before it drops, and it is irreversible by declaration.** `up` creates `roles`, writes one row for each member whose legacy value maps to a role, and only then removes `members.role`. The map is `owner` to `owner`, `admin` to `administrator`, `manager` to `events_administrator`, and `member` to no row at all. `down` raises `ActiveRecord::IrreversibleMigration`, because a member holding two roles has no representation in a single-value column and a reverse migration would have to pick one and lose the other silently. Saying so is better than a `down` that appears to work.

**The backfill is written in raw SQL and exposed as its own method on the migration**, so the parity spec runs the code that ships rather than a copy of it. The spec adds the `role` column back for the duration of one example, inserts a row per legacy value, calls the migration's backfill, and asserts each member's capabilities through `can_manage?`. Its control is the same run against a deliberately wrong map, so the example is known to catch a lost capability rather than to pass on a technicality.

**Roles are written through a `role_names` accessor on `Member`.** The controller permits `role_names: []` instead of a scalar `:role`, and the form renders a checkbox per vocabulary entry. Who may set which role is still nobody's decision to make: today anybody who may update a member may set its role, and this branch keeps that exposure exactly as it is rather than quietly tightening or loosening it, because that question is #96's and #173's.

## Steps

- Add the `roles` table in a migration that backfills from `members.role` before dropping the column, with the backfill as its own method and `down` raising `ActiveRecord::IrreversibleMigration`
- Add the `Role` model: `belongs_to :member`, the `NAMES` vocabulary, and validations for presence, inclusion and uniqueness scoped to the member
- Replace the `role` enum on `Member` with `has_many :roles, dependent: :destroy`, the `can_manage?(area)` predicate, and the `role_names` reader and writer the form and controller use
- Swap `MembersController`'s scalar `:role` for `role_names: []` on both create and update, verifying the `params.expect` array syntax against the Rails 8.1 API rather than assuming it matches `permit`
- Replace the single select in `app/views/members/_form.html.erb` with a checkbox group over the vocabulary, and update `MembersHelper#member_roles` to answer it
- Update `app/views/members/_member.html.erb` to render the roles a member holds, and nothing where it holds none
- Adapt `GroupsController#create` and `db/seeds.rb` to grant the `owner` role as a row instead of setting an enum value
- Regenerate the schema annotations with `annotaterb` rather than hand-editing the headers in `app/models/member.rb`, the new model, and the factories
- Rewrite the specs that assert the enum: `spec/models/member_spec.rb:16`, `spec/models/group_spec.rb:48`, the role blocks in `spec/requests/members_spec.rb`, and `spec/requests/groups_spec.rb:170`
- Replace the `build(:member, role: nil)` trick at `spec/models/event_spec.rb:41`, which stops describing an invalid member once no member needs a role
- Add the model specs the issue's criteria name: several roles at once, `owner` passing an administrator-only check with no `administrator` row, a vocabulary extended by `stub_const` needing no migration, and the backfill parity example
- Update the README: drop `role` from the `MEMBER` entity and realign the block, draw the new entity and its relationship per `docs/adr/2026-08-21_erd-notation-conventions_0002.md`, and correct the Member prose at `README.md:45`

## Verification

Gates with an exit code, which the implementing agent runs and ticks:

- Every new example is watched failing before the code that satisfies it exists, and the round records what each returned
- The backfill parity example is watched failing against a wrong map, so it is known to catch a member who loses a capability rather than to pass regardless
- The vocabulary-extension example is watched failing against a `can_manage?` that hardcodes the four names, so it proves the absence of a migration rather than the presence of a constant
- `bin/ci` is green
- The README's mermaid block rendered with `mmdc`, asserting the new entity and its edge appear, with a deliberate syntax error as the control
- The member form walked in headless Chromium over the DevTools Protocol, asserting a member can be given two roles at once and that both come back on reload

What these gates cannot see: whether the roles mean anything. Nothing in this branch authorizes or refuses an action on the strength of a role, so a green suite proves the vocabulary is storable and the predicate answers, not that any capability is actually gated. That arrives with #173 and #96. The gates also say nothing about production data, since the backfill is exercised against rows a spec inserts.

## Open questions

- **`Role` or `MemberRole`?** The plan says `Role`, on the strength of hitobito's `roles` table and the plain-noun table names across the reference apps, and because `member.roles` reads the way the domain talks. The cost is a generic name in a schema where a role only ever belongs to a member.
- **Should the role picker stay on the member form at all on this branch?** The plan keeps it, unchanged in who can reach it, so the branch does not smuggle in an access decision that belongs to #96. The alternative is removing it until a policy governs it, which would leave no way to grant a role through the UI in the meantime.

## Settled

None yet.
