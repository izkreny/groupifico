> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Add an authentication ERD to the README

Implementation plan for [#148](https://github.com/izkreny/groupifico/issues/148). The acceptance criteria live on the issue; this file answers how.

## Context

`README.md` holds one mermaid ERD, and it deliberately draws none of the authentication tables. [ADR 0002](../adr/2026-08-21_erd-notation-conventions_0002.md) settled that omission and required it be declared rather than left silent, because an ERD that quietly lacks a table that exists is what made the deleted DBML file untrustworthy. The declaration is the `[!IMPORTANT]` block above the diagram, and it promises a diagram of its own.

Three tables are now waiting on that promise. `sessions` and `sign_in_tokens` arrived with #139, `sign_ups` with #207, and [ADR 0004](../adr/2026-08-31_passwordless-email-sign-in_0004.md) is the record of what they are for. The declaration itself has fallen behind: it names two of the three, so `sign_ups` is currently both undrawn and undeclared, which is the exact failure ADR 0002 exists to prevent.

Nothing about the notation is open. This plan reuses ADR 0002's conventions and the token legend already beside the domain diagram, and adds a second diagram rather than a second convention.

## What the schema actually says

From `db/schema.rb` at `2026_09_02_140000`, which stays the authority both diagrams describe.

| Table            | Columns beyond `id`, `created_at`, `updated_at`                  | Unique index   | Foreign key                                    |
|------------------|------------------------------------------------------------------|----------------|------------------------------------------------|
| `sessions`       | `ip_address`, `user_agent`, `user_id`                            | none           | `user_id`, no options, so `NO ACTION`          |
| `sign_in_tokens` | `token_digest`, `expires_at`, `consumed_at`, `user_id`           | `token_digest` | `user_id`, `ON DELETE` and `ON UPDATE CASCADE` |
| `sign_ups`       | `email`, `group_name`, `token_digest`, `expires_at`, `consumed_at` | `token_digest` | none at all                                    |

Two facts shape the diagram more than the columns do.

`sessions` has no cascade behind it. `User has_many :sessions, dependent: :destroy` is the whole of the cleanup, so the guarantee is Active Record's rather than the database's, and a row deleted outside Rails leaves sessions behind. The domain diagram already records this in a `%%` line above `USER`, and that line moves here rather than being written twice.

`sign_ups` has no `user_id` and no foreign key, because the row exists before the account does. It reaches `users` by email value only, resolved at redemption through `User.find_or_create_by!`, and mermaid has no attribute-level anchor to hang that on. How it sits in the diagram is the open question below.

## Decisions

**The second diagram is a sibling subsection, not a replacement.** `### Authentication Entity Relationship Diagram` follows the domain diagram's fence, with a short prose intro. The domain diagram keeps its heading, its prose and its legend untouched except for the one stale bullet.

**One legend, shared.** The legend table sits above the domain diagram and is written as a notation reference rather than a diagram-specific key, so the second diagram points at it instead of carrying a copy. A token the new diagram needs and the legend lacks is a new row there, not a second table.

**One default-attributes block, shared.** The `"Default attributes for each ENTITY"` pseudo-entity stays in the domain diagram only. Repeating it would put a second copy of one fact in the file, and the prose introducing the second diagram says it applies to both.

**`USER` is the anchor and appears in both.** It is the only entity that does, and the second diagram exists to show what hangs off it. How much of it renders is the open question below.

**The `%%` detail lines are copied where they already exist.** `USER`'s two foreign-key lines in the domain diagram describe `sessions` and `sign_in_tokens`, and belong with the tables they describe once those tables are drawn. Moving them keeps ADR 0002's rule that each `%%` line names the field and the concern it describes.

## Out of scope

- **The domain diagram's own content.** Only its `[!IMPORTANT]` omission bullet changes, and only because that bullet is the promise this issue keeps.
- **Prose sections for the auth models.** The `### Core Domain Models` list describes the domain, and ADR 0002 already decided authentication gets no `Session` section there. A diagram plus its `[!IMPORTANT]` block is the whole deliverable.
- **A CI job that checks either diagram against `db/schema.rb`.** ADR 0002 names it as cheaper than the manual check and deliberately not done. This branch does not change that; the check runs here as a throwaway script, as it did on #81.
- **Anything in `db/schema.rb`, the models or the migrations.** This is a documentation change with no code behind it.

## Steps

- Add the `### Authentication Entity Relationship Diagram` subsection to `README.md`, after the domain diagram's fence, with a prose intro naming the three tables it draws and pointing at the shared legend and the shared default-attributes block.
- Draw the diagram: `USER` as the anchor, plus `SESSION`, `SIGN_IN_TOKEN` and `SIGN_UP`, with relationship lines in the domain diagram's `↓ … ↑` label style.
- Write every attribute as `type name "key, comment"` with Rails types and `NN` or `NULL` on each, and put every further fact on a `%%` line directly above the attribute it describes: the column limits, and that `token_digest` holds an HMAC-SHA256 digest rather than the token.
- Put the per-entity facts on `%%` lines above each entity block: the foreign key rules for `SESSION` and `SIGN_IN_TOKEN`, moved from `USER` in the domain diagram, and the absence of one for `SIGN_UP`.
- Give the new diagram its own `[!IMPORTANT]` block above the fence, carrying what the picture cannot say: the fifteen-minute expiry that `Redeemable::EXPIRES_IN` sets, that a spend is a conditional `UPDATE` rather than a delete, and how `SIGN_UP` reaches `users` without a foreign key.
- Rewrite the domain diagram's `[!IMPORTANT]` omission bullet so it points at the new diagram instead of promising one, and so it names no table that is still undrawn.
- Check every notation token both diagrams use against the legend, taken from the diagrams rather than from intent, and add a row for anything missing.
- Run the verification gates below and record what the throwaway cross-check reported in both directions.

## Verification

Gates, each with an exit code:

- `bin/ci` exits zero. It is this repository's only check command, per its own agent config, and a docs-only branch is expected to leave it green rather than be exempt from it.
- The `pr-flow` skill's `scripts/docs-check.py`, run with `--root .` and `--ignore 'scripts/*'` over `README.md` and this plan file, exits zero: every backticked path resolves and every fence is closed. Scoped to the two files this branch touches, because older plan files already fail the check on paths belonging to installed gems rather than to this tree. The ignore covers this plan's own reference to the script, which lives in the skill's tree rather than in this one.
- `PUPPETEER_EXECUTABLE_PATH=$(command -v chromium) mmdc -i README.md -o <scratchpad>/readme-erd.svg` exits zero, which renders both embedded diagrams through the same mermaid version a browser would use and so proves both parse. The environment variable is not optional: `mmdc` installs without a browser and fails until pointed at one, and using the one already present avoids downloading a third. The repository gains no mermaid dependency; there is no Node manifest here and this adds none.
- Neither rendered SVG contains any `%%` text, and every attribute the source declares appears in the output. This is what makes the two-layer convention real rather than hoped for, and it is the same check ADR 0002 recorded as verified rather than reasoned.
- Every column of `sessions`, `sign_in_tokens` and `sign_ups` in `db/schema.rb` is either drawn in the new diagram or covered by an omission rule the diagram states, and every attribute the new diagram draws is a column that exists. Checked by a throwaway script in the scratchpad, not committed, reported in both directions, with the omitted foreign key columns listed rather than silently allowed.
- Every distinct key string inside the rendered comments of both diagrams appears in the README legend. Taken from the diagrams rather than from intent, so a notation invented while writing cannot ship undocumented.
- `grep -n 'sessions' README.md` shows the domain diagram's omission bullet naming no table that goes undrawn, and pointing at the new diagram.

Judgement, which no exit code covers:

Whether both diagrams are still readable at a glance. That is the entire reason for the two-column convention, and it is the one thing a longer comment column quietly destroys. No renderer can answer it. The same goes for whether the relationship labels read correctly in the new diagram's direction, and whether an `[!IMPORTANT]` block that has grown a fourth bullet is still read rather than skipped.

## Open questions

- **How much of `USER` renders in the second diagram?** A bare anchor box carries no columns and duplicates nothing, but ADR 0002 calls a rendered entity that hides one of its columns the failure the exercise is correcting. Rendering `email` alone breaches that reading; rendering nothing may sidestep it, since an entity with no block is not claiming to show its columns. My preference is the bare box plus a `%%` line saying `USER` is drawn in full in the domain diagram above.
- **How does `SIGN_UP` sit with no foreign key?** Either an isolated entity with a `%%` line explaining the email-value link, or a dashed `optionally to` edge to `USER` labelled with what redemption does. ADR 0002 rejected `optionally to` for `creator_id` and `manager_id` on the grounds that an unanchored edge conveys less than an attribute row, and the same argument applies here. My preference is the isolated entity.

## Settled

None yet.
