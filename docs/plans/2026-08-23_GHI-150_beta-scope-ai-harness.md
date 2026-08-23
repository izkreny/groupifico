> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: define beta scope and AI harness (#150)

This is the deliverable of spike #150, drafted for inline review on the draft PR. Every proposal section below is a decision to approve, edit or reject; the `## Steps` section is what gets executed once the proposals are settled.

## Proposal: definition of beta

Beta is the smallest Groupifico one real group can run on: a person signs in through passwordless email login (#139), creates a group, members join it, events get created, members register for them and presence gets confirmed. It is deployed to the production VPS and the pilot group uses it for real.

Everything else is explicitly out of beta: every other sign-in method (#85, #125), notifications (#147), polls, songs, posts, treasury, i18n (#111), PWA (#120), dashboard (#116), ViewComponents (#121), and all address enrichment (#104, #105, #106, #133, #145).

## Proposal: beta milestone gates

A `beta` milestone is created and set on each gating issue directly (leaf issues, not only epics, since milestone filters read the issue's own milestone). The gates:

- #149 cover the existing code with specs, plus #79 restoring the system-test CI job
- #139 passwordless email login, replacing the temporary password login
- #83 and #138, the two known bugs
- #93 module based role system, with #96 as its first enforcement
- #91 and #102, the two uniqueness validations that protect data integrity
- #94 fill an event's creator automatically
- #76 deploy the application to a VPS with Kamal

## Proposal: epics

Epics group by domain, the milestone groups by ship date; one issue can carry both. Issues move from the #84 holding pen to a domain epic when the epic is created, since an issue has one parent. #84 stays what it is for everything not yet clustered. Every epic in the table above gets created while executing this plan, `addresses` included; creating an epic creates no leaf issues, and drafts keep being finished at pickup.

| Epic | Backlog issues |
|---|---|
| `authentication` | #85, #86, #125, #139, #140, #148 |
| `authorization` | #93, #96, and future policy enforcement issues |
| `membership` | #83, #87, #88, #90, #91, #92, #118, #126, #134, #136, #137, #138 |
| `events` | #89, #94, #95, #97, #98, #99, #100, #101, #128, #135, #141, #142, #143 |
| `registrations` | #102, #103, #144 |
| `addresses` | #104, #105, #106, #133, #145 |
| `quality & delivery` | #76, #79, #123, #149 |

Left unclustered until their turn comes: links/linktree (#107, #129, #130, #131), songs (#108, #127, #132), polls (#109), fees (#110), i18n (#111), comments/posts (#112, #113), seasons (#114), reports (#115), dashboard (#116), tasks (#117), spike #119, PWA (#120), ViewComponents (#121), native app (#122), notifications (#147). Clustering them now would mean inventing epics nothing ships from yet.

## Proposal: working 2 issues in parallel

- Two issues at a time for now; the layout extends to a third when the owner finds two comfortable.
- The existing checkout at /home/izkreny/Projects/groupifico/git/main stays the main worktree; the second stream works in a sibling worktree folder at /home/izkreny/Projects/groupifico/git/second, and a third would be /home/izkreny/Projects/groupifico/git/third.
- Each worktree folder hosts one issue's branch, or a `gh stack` of dependent branches, so the external reviewer/mentor can follow one stream per folder.
- Pick concurrent issues from different epics, or at least different layers, so the diffs do not overlap; two issues inside one epic usually share files and belong in sequence or in a stack instead.
- The first parallel pair: #149 (specs) and #76 (deploy, infra). #83 would collide with #149, since fixing member `full_name` touches the same specs #149 is writing.

## Proposal: reference repos under /home/izkreny/Projects/examples/rails/

Shallow-clone these and stop:

1. [basecamp/once-campfire](https://github.com/basecamp/once-campfire), real 37signals Rails app, Hotwire, no-build, closest to our stack
2. [basecamp/fizzy](https://github.com/basecamp/fizzy), newest 37signals open-source app, Rails 8 era conventions
3. [basecamp/writebook](https://github.com/basecamp/writebook), small and readable 37signals app
4. [hitobito/hitobito](https://github.com/hitobito/hitobito), group hierarchies with members and events, the same domain as Groupifico
5. [steveclarke/real-world-rails](https://github.com/steveclarke/real-world-rails), 200+ production open-source Rails apps in one repo, built for AI agents to search architectural patterns
6. [rails/rails](https://github.com/rails/rails) at its `main` branch, edge Rails, the next version: the authority on what the framework already ships or is about to

Ground rules for the folder:

- Clone folder names follow `{repo-owner}_{repo-name}`: basecamp_once-campfire, basecamp_fizzy, basecamp_writebook, hitobito_hitobito, steveclarke_real-world-rails, rails_rails.
- git-lfs is installed before any clone, through the package-management skill.
- Preference order: rails_rails outranks everything on framework capability questions, so what edge Rails already ships gets used, or locally backported, before anything is hand-built; when #139 is picked up, edge Rails is checked for built-in passwordless support first. On application patterns, the basecamp_* solutions get preference.
- Exploration inside the examples, above all inside steveclarke_real-world-rails, is always delegated to a cheap subagent (sonnet, or haiku for pure lookup), never done in the main session's context. This stands in until the rails-explorer skill the owner plans separately lands.

The corpus in row 5 is why lobsters/lobsters and we-promise/sure from the first candidate round are dropped: it covers the "idiomatic long-lived Rails" role on its own. The full survey of the owner's starred Rails list, including the larger apps deliberately skipped, is in the comments on #150.

## Proposal: 37signals skills and other harness helpers

Adopt [marckohlbrugge/37signals-skills](https://github.com/marckohlbrugge/37signals-skills) selectively: take the Rails/Hotwire/Turbo guidance, leave out its testing philosophy (fixtures, Minitest), which would contradict the RSpec+FactoryBot suite we keep. The adopted skills install globally, via the skills.sh installer. Distilling their material into one rails skill, or into the local AI files, happens in its own parallel session, outside this spike. Evaluate there, without installing blindly: [palkan/layered-rails-skills](https://github.com/palkan/layered-rails-skills), [obie/claude-on-rails](https://github.com/obie/claude-on-rails), [ThibautBaissac/rails_ai_agents](https://github.com/ThibautBaissac/rails_ai_agents).

## Proposal: AGENTS.md corrections

- Name DaisyUI alongside Tailwind CSS in the front-end stack; it is in the README and a DaisyUI MCP workflow is connected, yet `AGENTS.md` never mentions it.
- Name RSpec and FactoryBot in the stack, and `bin/ci` as the one local check command.
- Record the examples-folder rules: basecamp_* solutions get preference, and exploration of the examples is always delegated to a cheap subagent.
- Point at `.agents/github.md` for the repository's GitHub conventions, so a plain coding session sees they exist.
- Drop the TDD mandate, per the owner's decision.
- Reword the Sandi Metz OOD framing: keep everything of hers that does not conflict with the 37signals recommendations, and 37signals wins on conflict. The exact wording is folded into the parallel style-distillation session.
- Retire the ASK/PLAN/AGENT mode sections, which are Cursor-era terminology that only half maps onto Claude Code.

## Steps

- Settle every proposal section above through inline review on this PR
- Apply the `AGENTS.md` corrections on this branch
- Create the `beta` milestone and set it on each gating issue
- Create the epics from the proposal table and re-parent their backlog issues from #84
- Install git-lfs, then shallow-clone the reference repos into /home/izkreny/Projects/examples/rails/ under their `{repo-owner}_{repo-name}` names
- Install the adopted 37signals skills globally via skills.sh; their distillation into a rails skill moves to its own session
- Record the outcome on #150 and close it

## Verification

- `bin/ci` passes on this branch
- The docs check on this plan file passes
- [owner] The definition of beta reads right and the milestone gate list is the owner's cut
- [owner] The epic set and issue clustering are approved

What these gates cannot see: whether the beta cut is actually the smallest shippable product; only the pilot group using it can answer that.

## Open questions

None.

## Settled

- Sandi Metz stays as guidance wherever she does not conflict with the 37signals recommendations; conflicts resolve in 37signals' favour, and the exact `AGENTS.md` wording is folded into the parallel style-distillation session.
- rails/rails at its `main` branch (edge Rails) joins the reference clones, with top preference on framework capability questions.
- Passwordless email login (#139) is mandatory for beta; it joined the gates and the temporary password login left the definition.
- `addresses` gets created now, with the rest of the epic table; executing this plan creates no leaf issues and finishes no drafts.
- Dropping lobsters and we-promise/sure in favour of the real-world-rails corpus: agreed.
- The adopted 37signals skills install globally, via the skills.sh installer; their distillation into a rails skill happens in a parallel session, outside this spike.
- Parallel work is two streams for now: the main worktree plus a sibling `second` folder, each able to host a stack; `third` comes when two feel comfortable.
- Reference clones are named `{repo-owner}_{repo-name}`, basecamp_* solutions get preference, exploration of the examples is always a cheap subagent's job, and git-lfs is installed before cloning.
