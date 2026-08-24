# Rails style overrides for this repository

Per-repo facts for the `rails-style` skill: where this repository deliberately deviates from the skill's defaults. This file wins on any conflict with the skill; anything not listed here follows the skill.

## Authorization: Pundit, decided but not yet landed

Decided 2026-08-24: authorization goes through Pundit policy objects, not the skill's model-predicate default. The gem is not in the Gemfile yet; this entry exists so the choice survives until the first authorization work lands, and so policy objects are not flagged as violations when they arrive.

## Committed stack

The TECH STACK section of [AGENTS.md](../AGENTS.md) is the committed stack; treat everything it names as settled, never as candidates for the skill's gem skepticism.
