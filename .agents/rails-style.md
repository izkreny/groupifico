# Rails style overrides for this repository

Per-repo facts for the `rails-style` skill: where this repository deliberately deviates from the skill's defaults. This file wins on any conflict with the skill; anything not listed here follows the skill.

## Authorization: Action Policy

Decided 2026-08-25: authorization goes through [Action Policy](https://github.com/palkan/action_policy) policy objects, not the `rails-style` model-predicate default. `app/policies/` is intended, not a violation. How a rule, a pre-check, an alias, a scope or a policy spec is written is the `action-policy` skill's to say and is not restated here; what this repository adds to it is that `ApplicationPolicy` is the superclass every policy inherits and `ApplicationController` enables `verify_authorized`. Every `skip_verify_authorized` in this repository is permanent and names its own actions: `SessionsController` and `PasswordsController` because they are unauthenticated by design, `UsersController` because four of its actions act on `Current.user` alone and the other two raise a product question rather than an authorization one. Each skip's own comment carries the reasoning; there are no temporary skips, and a new one is a conversation rather than a TODO. The reasoning and the alternatives weighed are in `docs/adr/2026-08-25_authorization-with-action-policy_0003.md`.

## Committed stack

The TECH STACK section of [AGENTS.md](../AGENTS.md) is the committed stack; treat everything it names as settled, never as candidates for the skill's gem skepticism.
