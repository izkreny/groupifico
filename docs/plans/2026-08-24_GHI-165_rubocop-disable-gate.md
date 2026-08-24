> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: gate inline rubocop disables (#165)

Make the inline-disable policy structural: a `rubocop:disable` anywhere in the tree becomes a lint offense that `bin/ci` and the `lint` job refuse, so a cop that bites forces a conversation instead of a silent disable. There is no allowlist. One cop enables the whole gate, and the two convention files that currently hand out an escape hatch lose it in the same change.

## Proposal: the `.rubocop.yml` change

Append to the existing config (omakase inherit plus the `rubocop-rspec` plugin; `NewCops: enable` does not cover this cop, which is disabled-by-default rather than pending, so the enable is explicit):

```yaml
# An inline `rubocop:disable` is itself an offense, with no exceptions:
# the cop's own `AllowedCops` default is already `[]`, so enabling it is
# the whole gate. A cop that is wrong for this repository is reconfigured
# here instead, once, with a comment saying why.
Style/DisableCopsWithinSourceCodeDirective:
  Enabled: true
```

## Proposal: the policy paragraph in `AGENTS.md`

A new `### LINTING` subsection under `## TECH STACK`, beside `### TESTING`, so every agent session loads it. The wording to land:

RuboCop's verdicts are not always right, and what happens next is governed. An inline `rubocop:disable` is never allowed: `Style/DisableCopsWithinSourceCodeDirective` makes the directive itself an offense, so a cop that bites means stop and ask the owner - never silently disable, and never contort code just to appease a cop. A cop that is wrong for this repository generally gets reconfigured once in `.rubocop.yml`, with a comment saying why; a one-off case that a generally-right cop judges wrongly is a conversation, not a config change.

## Proposal: the two convention sentences that stop being true

Both live in the `## Style` section of `.agents/testing.md` and both currently promise the escape hatch this gate removes, so this change is what makes them false and this change fixes them:

- The `RSpec/NestedGroups` bullet says a genuinely necessary fourth nesting level "carries an inline `rubocop:disable` with a one-line reason". It becomes: a fourth level is a conversation with the owner. The cop keeps its default `Max: 3` - a one-off fourth level is not evidence the cop is generally wrong here, so it is the stop-and-ask case rather than a reconfiguration.
- The `RSpec/MultipleExpectations` bullet says an example needing a fourth facet "either splits or carries a justified inline `rubocop:disable` through the #165 gate". It becomes: it splits, or the ceiling itself is a conversation. The same sentence names the future `Max:` that #149 lands, which is `4` rather than the `3` it currently names, so it is corrected here too.

## Steps

- Enable `Style/DisableCopsWithinSourceCodeDirective` in `.rubocop.yml`, commented as proposed above, with no `AllowedCops` key
- Add the `### LINTING` subsection to `AGENTS.md` with the policy paragraph (`CLAUDE.md` and `GEMINI.md` are symlinks, so one edit covers all three)
- Rewrite the two `.agents/testing.md` bullets named above, dropping both escape hatches and correcting the future `Max:` to `4`

## Verification

- The gate is watched to fail once: a scratch change carrying an inline disable (for example `# rubocop:disable Style/StringLiterals`) makes `bin/rubocop` report the directive as an offense, then the scratch change is removed - a check never seen to fail is not evidence
- The two formerly sanctioned cops are watched to fail the same way: a scratch `# rubocop:disable RSpec/NestedGroups` and a scratch `# rubocop:disable RSpec/MultipleExpectations` are each reported as offenses, proving there is no residual allowlist
- `bin/ci` passes on the final tree
- [owner] Read the `### LINTING` paragraph and the two rewritten `.agents/testing.md` bullets: this is the policy that decides when agents interrupt you, so its wording is judgement

What these gates cannot see: whether the stop-and-ask policy is calibrated right - too strict and every RuboCop hiccup becomes a question, too loose and the pressure moves from disables into contorted code. That shows up in use, not in CI.

## Open questions

None open.

## Settled

- Where should the policy paragraph live in `AGENTS.md`? A `### LINTING` subsection under `## TECH STACK`, beside `### TESTING` - same altitude as the testing pointer, loaded into every session. The alternative (inside `### TESTING`) would hide a repo-wide code rule in a spec-specific section. Settled by the owner in review: "subsection is fine."
- Which cops may an inline `rubocop:disable` still name? None. The plan first sanctioned `RSpec/NestedGroups` and `RSpec/MultipleExpectations` via `AllowedCops`, mirroring the two escape hatches in `.agents/testing.md`. Settled by the owner in review: "agent should NEVER use `rubocop:disable`" - an entry pre-authorises unlimited disables that nobody counts, so it never forces the conversation this gate exists to force. Consequences carried above: no `AllowedCops` key, both convention escape hatches rewritten, and the ceiling raised in config rather than waived per site.
- What is `RSpec/MultipleExpectations` raised to? `Max: 4`. The number moved twice: `3` was the original figure in #149, raised to `5` in review once the ceiling became the only relief available, then settled at `4` by the owner reconsidering - "I changed my mind and decided to go with 4". The value is set by #149, which owns that acceptance criterion and now reads `4`; this plan only corrects the number where `.agents/testing.md` names it in advance. The commit that carried the `5` is on the branch and keeps it, which is what this entry is for.
