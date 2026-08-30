> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: reference the action policy skill (#194)

## Approach

`.agents/rails-style.md` already records that this repository chose Action Policy, so an agent knows `app/policies/` is intended rather than a violation. What no file here names is a reference for the *mechanism*: how a rule, a pre-check, an alias, a scope and a policy spec are actually written. The `rails-style` skill an agent does load defaults to model predicate methods and names Pundit and CanCanCan as gems to skip, so on authorization work it is the one skill in the set that is actively pointing the wrong way, and nothing corrects it.

The deliverable is the wording that names the `action-policy` skill as that reference. The skill installs globally, as `rails-style` did in #162, so nothing moves into this repository and the diff is instruction files only.

Two questions the wording has to settle, because getting either wrong is worse than saying nothing. **Which document wins:** the skill covers mechanism and deliberately says nothing about capabilities, so `docs/AUTHORIZATION.md` decides what a rule should return and outranks it. That sentence is the whole reason this is not simply another bullet in the always-apply list. **Where the boundary between the two files sits:** `AGENTS.md` introduces the skill and states the precedence, and `.agents/rails-style.md` keeps the decision it already records and stops restating the mechanism, which is the skill's to describe. Its `ApplicationPolicy < ActionPolicy::Base` and `verify_authorized` sentences are a second copy of what the skill covers, and the copy is the one that goes stale.

## Deliberately out of scope

`.agents/rails-style.md` currently says unconverted controllers carry a `skip_verify_authorized` naming #172, the issue that writes their policies. #172 is closed and `UserPolicy` was never written, so that sentence promises a policy nobody is writing. It is a real defect and it is #195's, which audits exactly this class of stale claim across the policy layer. Touching it here would mix a mechanism-reference change with an audit finding, and #195 cannot then report on a file this branch already edited for it.

## Steps

- Add the `action-policy` skill to the always-apply list in `AGENTS.md`, naming it as the reference for how authorization is expressed and stating that `docs/AUTHORIZATION.md` decides what a rule returns and outranks it
- Trim the mechanism restatement from the Authorization section of `.agents/rails-style.md`, leaving the decision, its date, the superseded Pundit choice and the ADR link, and point the section at the skill for the mechanism
- Leave the `docs/AUTHORIZATION.md` bullet under PROJECT KNOWLEDGE as it stands, so the precedence is stated once rather than in two places that can disagree

## Verification

- `bin/ci` passes on this branch
- The suite's docs check passes over `AGENTS.md` and `.agents/`, run with `--root .` and `--ignore '~/Projects/examples/rails/'` for the one pre-existing unresolvable span in `AGENTS.md` that predates this branch
- `grep -n 'action-policy' AGENTS.md .agents/rails-style.md` shows the skill named in both files
- [owner] A fresh session asked to change an authorization rule loads the skill without being told to

The gates prove the prose is well-formed and that the string is present. What none of them can see is the only thing that matters: whether the skill actually fires. Triggering is a property of the skill's own description, which lives outside this repository, so a wording change here that reads perfectly can still leave the skill never loading. The last box is the owner's because it needs a session this one cannot start; `claude plugin eval` measures the same thing against the skill rather than against this diff, if a scored answer is wanted instead of a single observation.

## Open questions

None.

## Settled

- Should `AGENTS.md` summarise what the skill covers? No. A summary here is a second copy of the skill's own scope and would go stale silently, the same failure the second step removes from `.agents/rails-style.md`. The wording points at the skill and stops.
- Which file states that `docs/AUTHORIZATION.md` outranks the skill? `AGENTS.md`, where the skill is introduced, and only there. The PROJECT KNOWLEDGE bullet already links the document for its own reasons and gains nothing from repeating the precedence. Settled in the terminal, 2026-08-30.
