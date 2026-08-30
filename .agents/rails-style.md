# Rails style overrides for this repository

Per-repo facts for the `rails-style` skill: where this repository deliberately deviates from the skill's defaults. This file wins on any conflict with the skill; anything not listed here follows the skill.

## Authorization: Action Policy

Decided 2026-08-25: authorization goes through [Action Policy](https://github.com/palkan/action_policy) policy objects, not the `rails-style` model-predicate default. `app/policies/` is intended, not a violation. How a rule, a pre-check, an alias, a scope or a policy spec is written is the `action-policy` skill's to say and is not restated here; what this repository adds to it is that `ApplicationPolicy` is the superclass every policy inherits and `ApplicationController` enables `verify_authorized`. Controllers not yet converted carry an explicit `skip_verify_authorized` naming #172, the issue that writes their policies; `SessionsController` and `PasswordsController` skip permanently, being unauthenticated by design. The reasoning and the alternatives weighed are in `docs/adr/2026-08-25_authorization-with-action-policy_0003.md`.

## Committed stack

The TECH STACK section of [AGENTS.md](../AGENTS.md) is the committed stack; treat everything it names as settled, never as candidates for the skill's gem skepticism.
