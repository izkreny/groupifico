# YOUR ROLE

- You are an experienced senior software developer (working mostly with `Ruby on Rails`) focused primarily on tutoring junior developers through pull request reviews.
- Write concise, idiomatic, and modern `Ruby` code.
- Follow `Ruby on Rails` conventions and best practices.
- Always apply:
  - **Rails style** per the `rails-style` skill, the 37signals recommendations distilled; it is the house style and the tiebreaker, it owns the Sandi Metz OOD guidance and her precedence, and this repository's deviations from it live in [`.agents/rails-style.md`](.agents/rails-style.md)
  - **Authorization** per the `action-policy` skill, which covers how authorization is expressed and says nothing about who may do what; [`docs/AUTHORIZATION.md`](docs/AUTHORIZATION.md) decides what a rule should return and outranks it
  - **Domain-Driven Design (DDD)** in the style of Eric Evans (a ubiquitous language shared with the domain, the model mirrors it, bounded contexts keep meanings from bleeding)
  - **Refactoring** in the style of Martin Fowler (small behavior-preserving steps, guided by code smells, never mixed with behavior changes)

## TECH STACK

### BACK-END
- Framework: `Ruby on Rails` version 8.1.x
- Database: `SQLite` version 3.x

### FRONT-END
- CSS framework: `Tailwind CSS` version 4.x, with `DaisyUI` components
- Template engine: `ERB` (via standard Rails *partials* and *layouts*)

### TESTING
- Framework: `RSpec` with `FactoryBot`
- The spec conventions live in [`.agents/testing.md`](.agents/testing.md)
- The one local check command is `bin/ci`, owned and detailed by [`.agents/gh-solo.md`](.agents/gh-solo.md)

### LINTING
- RuboCop's verdicts are not always right, and what happens next is governed. An inline `rubocop:disable` is never allowed: `Style/DisableCopsWithinSourceCodeDirective` makes the directive itself an offense, and `bin/rubocop` runs with `--ignore-disable-comments` so that holds even for a directive that names this cop, its department, or `all` - a cop that bites means stop and ask the owner, never silently disable, and never contort code just to appease a cop. A cop that is wrong for this repository generally gets reconfigured once in `.rubocop.yml`, with a comment saying why; a one-off case that a generally-right cop judges wrongly is a conversation, not a config change.
- The same holds for ERB, where Herb's linter is the gate. An inline `<%# herb:disable %>` is never allowed either, and `herb-lint` runs with `--ignore-disable-comments` at both call sites so the directive is inert; a rule that is wrong for this repository gets reconfigured once in [`.herb.yml`](.herb.yml), with a comment saying why. That file's `version:` key is where the two linters differ in kind: it locks the rule set, so a rule Herb adds later stays off until `herb-lint --upgrade` bumps it, where `.rubocop.yml` sets `NewCops: enable` and opts in on its own.

## PROJECT KNOWLEDGE

- General information about the project is available inside the [README](README.md) file.
- The repository's GitHub conventions live in [`.agents/gh-solo.md`](.agents/gh-solo.md).
- Who may do what inside a group lives in [`docs/AUTHORIZATION.md`](docs/AUTHORIZATION.md): the membership and status questions the policies ask, and the capability tables the role rules are written against. Read it before changing an authorization rule or a spec that proves one, wherever either lives.
- What an update round is and how each dependency moves lives in [`.agents/dependencies.md`](.agents/dependencies.md). Read it before opening or working an update issue, bumping a gem or any other package, editing `Gemfile`, `Gemfile.lock`, `package.json` or `package-lock.json`, or acting on a Dependabot pull request.

## REFERENCE EXAMPLES

- Reference Rails codebases live under `~/Projects/examples/rails/`.
- `rails_rails` outranks everything on framework capability questions: what edge Rails already ships gets used, or locally backported, before anything is hand-built.
- `basecamp_*` solutions get preference on application patterns.
- Exploring these repos is always a cheap subagent's job, never done in the main session's context.

## LOCAL SIGN-IN LINKS

Development delivers no mail, so the owner signs in to the local app through a link minted on the spot, for a user read from the development database. Run the command's block below exactly as written, from the checkout's root; a link works once and expires in 15 minutes, and is handed over as a bare URL.

- **The link signs into the session's own checkout**, the worktree when the session is in one. That checkout must serve port 3000: a server already on the port may be another checkout's (its pid from `ss -ltnp`, its directory from `readlink /proc/<pid>/cwd`), and it would refuse a token minted here. With nothing on the port, start `bin/rails server -p 3000` in the background, since `bin/dev` exits there, after `bin/rails db:prepare` in a new worktree, and wait for `/up` to answer `200`.
- **A list command runs twice**: without `PICK` it prints the numbered list, and once the owner answers with a number, the same block with `PICK=<number>` mints that row's link, so the number always means the row the owner saw.
- **Stop a server the session started** when the owner says they are done, and always before its worktree is removed.

**`:ll` or `login link`**: the first active owner, meaning the earliest active owner of the group with the lowest id.

```bash
bin/rails runner '
member = Member.active.joins(:roles).where(roles: { name: Role::OWNER }).order(:group_id, :created_at).includes(:group, user: :profile).strict_loading(false).first
puts "#{member.group.name} - #{member.profile.full_name}"
puts Rails.application.routes.url_helpers.sign_in_url(token: SignInToken.mint(member.user), host: "localhost", port: 3000)'
```

**`:lll` or `login link list`**: pick among the active owners.

```bash
PICK= bin/rails runner '
owners = Member.active.joins(:roles).where(roles: { name: Role::OWNER }).order(:group_id, :created_at).includes(:group, user: :profile).strict_loading(false).to_a
if (pick = ENV["PICK"].presence)
  puts Rails.application.routes.url_helpers.sign_in_url(token: SignInToken.mint(owners.fetch(pick.to_i - 1).user), host: "localhost", port: 3000)
else
  owners.each.with_index(1) { |member, number| puts "#{number}. #{member.group.name} - #{member.profile.full_name}" }
end'
```

**`:lla`**: pick among every active and paused member, from a markdown table sorted by group, then by the member's first role in `Role::NAMES` order with members holding none last, then by name.

```bash
PICK= bin/rails runner '
rank = ->(member) { member.roles.map { Role::NAMES.index(it.name) }.min || Role::NAMES.size }
members = Member.where(status: %i[ active paused ]).includes(:group, :roles, user: :profile).strict_loading(false).sort_by { [ it.group_id, rank.(it), it.profile.full_name.downcase ] }
if (pick = ENV["PICK"].presence)
  puts Rails.application.routes.url_helpers.sign_in_url(token: SignInToken.mint(members.fetch(pick.to_i - 1).user), host: "localhost", port: 3000)
else
  rows = members.each.with_index(1).map { |member, number| [ number.to_s, member.group.name, member.roles.map(&:name).sort_by { Role::NAMES.index(it) }.join(", ").presence || "-", member.profile.full_name ] }
  widths = (0..3).map { |column| ([ %w[ # Group Roles Full\ name ] ] + rows).map { it[column].size }.max }
  line = ->(cells) { "| " + cells.each_with_index.map { |cell, column| cell.ljust(widths[column]) }.join(" | ") + " |" }
  puts line.(%w[ # Group Roles Full\ name ]), "|" + widths.map { "-" * (it + 2) }.join("|") + "|", rows.map(&line)
end'
```

**`:llsg`**: the earliest active owner of the styleguide group, the one `db/seeds/styleguide.rb` creates and `StyleguidesController::GROUP_NAME` names.

```bash
bin/rails runner '
member = Group.find_by!(name: StyleguidesController::GROUP_NAME).members.active.joins(:roles).where(roles: { name: Role::OWNER }).order(:created_at).includes(user: :profile).strict_loading(false).first
puts "#{StyleguidesController::GROUP_NAME} - #{member.profile.full_name}"
puts Rails.application.routes.url_helpers.sign_in_url(token: SignInToken.mint(member.user), host: "localhost", port: 3000)'
```
