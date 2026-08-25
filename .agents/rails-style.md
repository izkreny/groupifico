# Rails style overrides for this repository

Per-repo facts for the `rails-style` skill: where this repository deliberately deviates from the skill's defaults. This file wins on any conflict with the skill; anything not listed here follows the skill.

## Authorization: Action Policy, landed

Decided 2026-08-25, superseding the earlier 2026-08-24 decision to use Pundit: authorization goes through [Action Policy](https://github.com/palkan/action_policy) policy objects, not the skill's model-predicate default and not Pundit. `app/policies/` is intended, not a violation. `ApplicationPolicy < ActionPolicy::Base` is the superclass every policy inherits, and `ApplicationController` enables `verify_authorized`, so an action that authorizes nothing raises rather than silently permitting. Controllers not yet converted carry an explicit `skip_verify_authorized` naming #172, the issue that writes their policies; `SessionsController` and `PasswordsController` skip permanently, being unauthenticated by design. The reasoning, the alternatives weighed, and why Pundit was the more reversible choice not taken are in `docs/adr/2026-08-25_authorization-with-action-policy_0003.md`.

## Committed stack

The TECH STACK section of [AGENTS.md](../AGENTS.md) is the committed stack; treat everything it names as settled, never as candidates for the skill's gem skepticism.
