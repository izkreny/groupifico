> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: distill a rails style skill (#162)

The session ran interactively with the owner, so this plan records the approach and the decisions it settled rather than proposing them; the repository-side diff on this branch is the small end of a deliverable that mostly lives outside it, in the owner's global agent space.

## Approach

The adopted 37signals skills from #151, plus two local predecessors, get distilled into one `rails-style` skill: a lean SKILL.md carrying the core style (defaults, modeling, naming, REST and routing, Ruby and view style, authorization, dependencies, review priorities and flags) and five reference files loaded only when the task touches them (Hotwire/realtime, jobs, migrations, security and multi-tenancy, webhooks). Testing philosophy stays out per the issue, and the source skills' Minitest-flavoured testing sections were dropped or reworded stack-neutrally.

The three candidate repos #151 named for evaluation were each read by a subagent and skipped: all encode the service/query/policy/ViewComponent layering the 37signals style rejects, and the settled rule resolves every conflict in 37signals' favour. A handful of genuinely compatible Hotwire and accessibility rules from one of them were folded in. Every framework-API claim in the distilled skill was verified read-only against the local reference clones before the skill was finalised; the full research record, including the skip verdicts and the verification nuances, lives in the owner's knowledge base.

The skill stays generic and shareable through a per-repository overrides file: the skill reads `.agents/rails-style.md` in the repository being worked on, and that file wins on any conflict, the same pattern the `github-*` suite uses with `.agents/github.md`.

## Steps

- Distill the source skills into the `rails-style` skill and have the owner review and install it globally, replacing the sources
- Reword the OOD bullet in `AGENTS.md` to defer to the skill as the house style and tiebreaker
- Add `.agents/rails-style.md` recording this repository's deliberate deviations

## Verification

- `bin/ci` passes on this branch
- The docs check on this plan file passes
- [owner] The installed skill's content is the owner's cut, reviewed before installation

A docs-only diff gives `bin/ci` little to catch. What these gates cannot see: whether the distilled style actually steers future Rails sessions well; only using the skill on real work answers that.

## Open questions

None.

## Settled

- Replace or supplement the source skills? Replace: one curated skill instead of eight overlapping ones, so nothing depends on outside definitions.
- The `dhh` review persona was folded for substance only; its voice calibration and the `/dhh` command are gone, with the owner's sign-off.
- The locally authored explicit-route-helpers workflow collapsed to one REST rule in the skill: explicit `*_path` helpers with full arguments over polymorphic targets.
- Testing conventions stay wholly in the repository testing conventions file that #164 introduces; nothing testing-related moves into the skill, avoiding a second copy that would drift.
- Authorization on Pundit is this repository's recorded deviation from the skill's no-Pundit default, living in `.agents/rails-style.md` rather than softening the skill itself.
- The Sandi Metz rule wording: she stays as secondary guidance (small single-purpose classes, depend on things that change less often, isolate what varies, duck types), and conflicts resolve in the skill's favour.
