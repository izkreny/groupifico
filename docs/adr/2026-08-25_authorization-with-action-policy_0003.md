> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0003. Authorization with Action Policy

## Status

Accepted, 2026-08-25. Supersedes nothing formally recorded, but reverses the 2026-08-24 choice of Pundit that had been noted in `.agents/rails-style.md` and never reached the Gemfile.

## Context

Today the application has no authorization layer at all. Five controllers root their lookup at an unscoped, params-driven `find` - `groups`, `events`, `members`, `registrations` and `addresses` - so any authenticated user can read, edit or destroy any group, any group's events, members and registrations, and any address, by putting the id in the URL. `UsersController` and `UserProfilesController` are the exceptions, both resolving from `Current.user` and ignoring the params entirely. Issue #170 delivers the mechanism and the fail-closed default; the per-resource rules that close the five holes are #172's, and the module-based role system that will sit on top of the mechanism is #93's.

**The house default is no gem at all.** The `rails-style` skill's Authorization section reads "No Pundit/CanCanCan: simple predicate methods on models (`card.editable_by?(user)`, `user.can_administer_board?(board)`)", with controllers checking the predicate and models defining what it means. That is the 37signals position this repository otherwise follows, and it is deliberately not what this issue does. The reason is the second half of what #170 asks for, not the first: a predicate method answers "is this allowed" but gives no mechanism for "did every action check something", and that second property is the one this issue exists to add. A model predicate the controller forgets to call fails exactly as silently as the five controllers fail today; nothing about the pattern itself would have caught the omission that created the hole in the first place. So the survey below is not "which gem beats hand-rolled predicates in general", it is "which gem gives a controller-wide guard that raises on a forgotten check", because that is the property the house default cannot express and the property this issue is measured against.

## Decision

### Action Policy over Pundit and CanCanCan

Three candidates were measured against each other on 2026-08-25, each fact taken from the gem's own repository or RubyGems page rather than recalled:

| | Pundit | CanCanCan | Action Policy |
|---|---|---|---|
| Latest version | 2.5.2 | 3.6.1 | 0.7.6 |
| Released | 2025-09-24 | 2024-05-28 | 2026-01-13 |
| GitHub stars | 8,522 | 5,686 | 1,560 |
| Open issues | 15 | 93 | 6 |
| Last push | 2026-08-02 | 2026-08-09 | 2026-07-25 |

**CanCanCan is ruled out first, on shape rather than on the numbers.** Its `Ability` class centralizes every rule for every model behind one `can`/`cannot` DSL, which is the opposite of the one-policy-per-resource split this epic wants: five controllers each get their own policy under #172, and a single `Ability` god-object would put all five back in one file, undoing the separation the whole epic is organized around. Its own guard story is also weaker: `can?` returns `false` for a query nobody defined, the same silent-pass failure mode the model-predicate default already has, with no equivalent to a controller-wide "nothing was checked" raise. Its numbers agree with that assessment being overdue for revisiting rather than settling it: 93 open issues against Pundit's 15 and Action Policy's 6, and its current release is over two years old against the other two both shipping within the last seven months.

**Pundit is the closer call, and the one the reversibility trade-off below is about.** `Pundit::Authorization#authorize` is a single explicit method call with no metaprogramming behind it, and `verify_authorized` exists there too - but as a plain instance method you wire up yourself with `after_action :verify_authorized`, not something the gem enables for you. Read from `varvet/pundit`'s own source: a Pundit policy has no fallback rule at all, so a predicate nobody defined is a bare Ruby `NoMethodError`, not a caught, structured failure - denial and "forgot to write this" are not the same outcome the way Action Policy makes them. Action Policy's base class runs `default_rule :manage?`, defined to return `false`, so an empty policy already denies everything and `verify_authorized` is a registered `after_action` the gem ships, turned on with one line rather than assembled from parts. The mechanism this issue exists to deliver - deny by default, and a raised exception when nothing was checked - is closer to out-of-the-box in Action Policy than in Pundit, which is the deciding fact given what #170 is for.

### The reversibility asymmetry accepted

**Pundit would have been the more reversible choice, and it was not taken.** Its whole surface is instance methods called explicitly - `authorize(record)`, `policy(record)` - greppable and swappable one call at a time, with no controller-level DSL and no framework hook run at boot. Action Policy's integration is a railtie that, left at its defaults, includes a module into every controller and wires `current_user` before the application ever gets a say; this branch already had to override that default (`authorize :user, through: -> { Current.user }`) because the application has no `current_user`. `authorize :user, through: ...`, `verify_authorized`, and `rescue_from ActionPolicy::Unauthorized` are class-level declarations that configure behavior implicitly at load time, not calls a future reader can trace by following a method name. Unwinding Action Policy later - should the role system in #93 outgrow it, or should a simpler answer turn out to have been enough - costs more than unwinding Pundit would have, because more of the apparatus is framework-shaped rather than plain Ruby.

That cost is accepted because the property being bought is the one Pundit does not give for free: a controller that authorizes nothing fails the request rather than passing it through, the moment the controller is written, not the moment someone remembers to add the `after_action`. Given the five holes this issue exists to close were created by exactly that kind of omission, the stronger, harder-to-reverse guarantee is worth more here than the cheaper exit would have been.

### `404` over `403` for a non-member

Added by amendment; see `## Amendments`. It is not part of the 2026-08-25 decision above, and it is recorded here because this is the record three other places already cite for it.

**A user with no `Member` row for a group gets `404`, never `403`.** A `403` says the thing exists and is withheld, which hands somebody guessing at ids exactly the fact they were fishing for. A scoped lookup means the record genuinely does not exist for that user, so `404` is the honest answer as well as the concealing one. `ApplicationPolicy#verify_membership!` sets `details[:not_found]` and denies; `ApplicationController#deny_access` reads that detail and raises what a genuinely absent record raises, so a refusal and a missing id travel the same code path rather than one imitating the other.

**A member who belongs but lacks the role gets `403`.** Concealment from somebody who can already see the group in the interface is noise rather than security. Where that refusal is written is #173's and #96's question, not this record's.

The decision's own account is #172's acceptance criteria, which state both halves in plain words. This section is the copy the citations point at, and #172 wins on any disagreement between them.

## Consequences

**`app/policies/` is now the intended location for authorization logic**, overriding the house model-predicate default recorded in the `rails-style` skill; `.agents/rails-style.md` carries the override so neither this repository's own conventions nor a future agent session reads a policy class as a violation.

**Every controller that authorizes nothing yet carries a `skip_verify_authorized`**, rather than the guard being deferred until #172 lands. Two of those skips are permanent, on `SessionsController` and `PasswordsController`, which are unauthenticated by design; every other one names #172 and comes off as that controller gains a policy. `grep -rl skip_verify_authorized app/controllers/` is the measure of how much of the sweep remains, and the sweep is done when only the permanent two are left. A gate that stays green with that list unchanged is not evidence the sweep happened; only a diff review across #172 catches that.

The count is deliberately not written down here. A number beside a list is a copy of the list, and the person who adds the next controller edits the list and never thinks to edit an ADR.

**The Rails 8.1 initialization-order issue in `palkan/action_policy#312`** affects only an application that sets `config.action_policy.auto_inject_into_controller = false` from `config/initializers/`. This application takes the default injection, so the issue does not reach it; noted here so a future reader upgrading Rails does not rediscover the same search.

**Reversing this decision costs more than reversing a Pundit adoption would have**, per the trade-off above. Anyone revisiting this ADR to argue for a different gem should read that section first: the case against Pundit was never "Action Policy is unconditionally better", it was that the fail-loud guarantee this issue was opened for is closer to Action Policy's default behavior than to Pundit's.

## Amendments

**2026-08-29, #188.** Added `### 404 over 403 for a non-member` under `## Decision`.

That choice was made in #172 on 2026-08-26, the day after this record was accepted, and three places already cited this record as holding it: #172's own body, calling it "the Basecamp idiom recorded in ADR 0003"; the comment at `app/controllers/application_controller.rb:46`, calling it "the existence oracle ADR 0003 chose 404 over 403 to close"; and #188's acceptance criteria, asking for "a pointer to ADR 0003 rather than a second copy of its reasoning". The citation was false in all three, and nobody had followed it until a review round on #192 did.

Amending was chosen over editing the three pointers, because a citation three independent places arrived at is the one a reader will keep making, and over a new ADR recording what this one lacks, which would be a record about a record with the same reader still landing here first.
