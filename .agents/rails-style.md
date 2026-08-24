# Rails style overrides for this repository

Per-repo facts for the `rails-style` skill: the places this repository deliberately deviates from the skill's 37signals defaults. This file wins on any conflict with the skill. Anything not listed here follows the skill's own standards.

## Authorization uses Pundit

The skill's default is predicate methods on models and no Pundit/CanCanCan. This repository deviates deliberately: authorization is planned on Pundit, so what a permission means lives in policy objects rather than model predicates. The skill's boundary rules still hold unchanged: controllers check at the boundary, and access that cannot be proven fails closed.

## Committed stack

The stack is recorded in the TECH STACK section of [AGENTS.md](../AGENTS.md). The skill's gem skepticism applies to the next gem, never to what that section already commits to.
