> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: gate inline rubocop disables (#165)

Make the inline-disable policy structural: an unsanctioned `rubocop:disable` becomes a lint offense that `bin/ci` and the `lint` job refuse, so a cop that bites forces a conversation instead of a silent disable. One cop enables the whole gate, and the sanctioned list stays owned by the convention files.

## Proposal: the `.rubocop.yml` change

Append to the existing config (omakase inherit plus the `rubocop-rspec` plugin; `NewCops: enable` does not cover this cop, which is disabled-by-default rather than pending, so the enable is explicit):

```yaml
# An inline `rubocop:disable` is itself an offense unless the cop is
# sanctioned by a convention file. The list's owner is the convention,
# never this file; each entry points home.
Style/DisableCopsWithinSourceCodeDirective:
  Enabled: true
  AllowedCops:
    - RSpec/NestedGroups          # fourth nesting level, per .agents/testing.md (Style)
    - RSpec/MultipleExpectations  # genuine fourth facet, per .agents/testing.md (Style)
```

## Proposal: the policy paragraph in `AGENTS.md`

A new `### LINTING` subsection under `## TECH STACK`, beside `### TESTING`, so every agent session loads it. The wording to land:

RuboCop's verdicts are not always right, and what happens next is governed. An inline `rubocop:disable` is allowed only for a case a convention file sanctions (the `AllowedCops` list in `.rubocop.yml` mirrors them); anything else means stop and ask the owner - never silently disable, and never contort code just to appease a cop. A cop that is wrong for this repository generally gets reconfigured once in `.rubocop.yml`, with a comment saying why.

## Steps

- Enable `Style/DisableCopsWithinSourceCodeDirective` in `.rubocop.yml` with the two sanctioned cops in `AllowedCops`, commented as proposed above
- Add the `### LINTING` subsection to `AGENTS.md` with the policy paragraph (`CLAUDE.md` and `GEMINI.md` are symlinks, so one edit covers all three)

## Verification

- The gate is watched to fail once: a scratch change carrying an unsanctioned inline disable (for example `# rubocop:disable Style/StringLiterals`) makes `bin/rubocop` report the directive as an offense, then the scratch change is removed - a check never seen to fail is not evidence
- A sanctioned disable (`# rubocop:disable RSpec/NestedGroups`) passes the same run, proving the allowlist actually allows
- `bin/ci` passes on the final tree
- [owner] Read the `### LINTING` paragraph and the `AllowedCops` comments: this is the policy that decides when agents interrupt you, so its wording is judgement

What these gates cannot see: whether the stop-and-ask policy is calibrated right - too strict and every RuboCop hiccup becomes a question, too loose and disables creep back. That shows up in use, not in CI.

## Open questions

- Where should the policy paragraph live in `AGENTS.md`? Recommendation, applied in the proposal: a `### LINTING` subsection under `## TECH STACK`, beside `### TESTING` - same altitude as the testing pointer, loaded into every session. The alternative (inside `### TESTING`) would hide a repo-wide code rule in a spec-specific section.
