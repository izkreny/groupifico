> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Consolidate the schema docs into the README ERD

Plan for #81.

## Context

The repository documents its schema twice, in `docs/schema.dbml` and in the mermaid ERD inside `README.md`, and both drifted away from `db/schema.rb` months ago. #81 holds the full discrepancy table; the short version is that they name `Attendee`, they list `username`, `time_zone` and `uid` columns that were never built, and neither knows the `sessions` table or `password_digest` exist.

Two documents that disagree with the code are worse than one, so the ERD becomes the only schema document and the DBML file goes. What makes that a migration rather than a deletion is the detail the DBML file holds and `db/schema.rb` cannot express: enum value names, since Rails stores bare integers and the values live in the models; foreign key delete and update rules; the ISO field notes; and the uniqueness notes that explain what the composite indexes are for.

Three facts about mermaid were checked against its own documentation rather than recalled, because the whole rewrite rests on them.

- The official attribute syntax is `type name key "comment"`, keys limited to `PK`, `FK` and `UK`. This diagram deliberately deviates to `type name "key, comment"`, keeping every entity box two columns wide at the cost of mermaid rendering the keys as keys. That is a readability decision, and the `IMPORTANT!` note in the diagram's frontmatter exists to record it.
- The cardinality alias table includes `1` for exactly one and `1+` for one or more, and the documentation's own example combines an alias with a label after a colon. **The existing relationship lines are valid and are not part of this change.**
- A `type` may contain digits, parentheses and square brackets, so `VARCHAR(250)` is a legal type name. Column limits can travel in the type rather than in the comment.

A `%%` comment must not contain `{}`, which the renderer reads as directive syntax. That constrains the table-level notes, which are the natural thing to put in one.

The salvage source is the abandoned `docs-update` branch, whose February README and ERD pass still checks out against today's schema: it commented out exactly the columns that do not exist. Its three useful commits are `3d8400c`, `b491b3f` and `0b63d51`, and the branch stays on the remote until this lands.

## Approach

Rewrite the ERD in place rather than starting from the DBML file. The diagram already has the shape, the relationship lines and the section comments; what it needs is correct entity contents, the DBML detail folded into the comment column, and the attribute order untwisted.

**Everything that is intent rather than schema moves to `docs/ROADMAP.md`.** The unbuilt columns and the DBML file's `// TODO` annotations are design notes that were living in a schema document, which is why the schema document kept looking wrong. The ERD ends up describing only what exists, and the roadmap holds what does not.

## Steps

- Delete `docs/schema.dbml`, and drop the DBML link from the ERD preamble in `README.md` while keeping the `db/schema.rb` link.
- Rewrite the ERD entity blocks in the `type name "key, comment"` order, one entity per table in `db/schema.rb`, `SESSION` included and `REGISTRATION` in place of `ATTENDEE`, with no column that does not exist.
- Fold the DBML detail into the diagram: enum values with their defaults, foreign key delete and update rules, the ISO field notes, and the uniqueness notes for `members` and `registrations`.
- Correct the second line of the `IMPORTANT!` note in the diagram's frontmatter so it states the convention actually in use.
- Rewrite the README domain-model prose: `Registration` in place of `Attendee`, and password-and-session login in place of the magic link.
- Move intent into `docs/ROADMAP.md`: the unbuilt `username`, `time_zone` and `uid` columns, the DBML file's `// TODO` notes, the magic-link login idea, an RSVP locking note and a `counter_cache` note, and rename the section `### Registration`.

## Verification

Gates, each with an exit code:

- `bin/ci` exits zero. This is the repository's only check command, per its own agent config, and a docs-only branch is expected to leave it untouched rather than exempt from it.
- `/home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py`, run with `--root .` and `--ignore 'docs/schema.dbml'` over `README.md`, `docs/ROADMAP.md` and this plan file, exits zero: every backticked path still resolves once the DBML file is gone, and every fence is closed. The ignore covers this plan's own references to the file being deleted, and the file list is scoped to what this branch touches, because two older plan files already fail the check on paths that belong to installed gems rather than to this tree.
- Every `create_table` name in `db/schema.rb` appears as an entity in the ERD, and every attribute in the ERD is a column that exists in `db/schema.rb`. Checked by a throwaway script in the scratchpad, not committed, reported both directions, with the deliberately omitted foreign key columns listed rather than silently allowed.
- `grep -ric attendee README.md docs/ROADMAP.md` reports zero in both files. Scoped to those two on purpose: `docs/plans/` legitimately says the word.
- Each migrated DBML fact is present in `README.md`: `cascade`, `restrict`, ISO 3166-2, ISO 3166-1, ISO 20022, both uniqueness notes, and every enum value list from the models.

Judgement, which no exit code covers:

- **[owner]** The diagram renders on GitHub. The repository has no mermaid tooling of any kind: no Node package manifest at all, nothing matching mermaid in `Gemfile` or `Gemfile.lock`, and nothing in the workflows. So nothing local can parse the diagram, and the PR's own preview of `README.md` is the only renderer available.
- **[owner]** The diagram is still readable at a glance. That is the entire reason for the two-column convention, and it is the one thing a longer comment column can quietly destroy.

What these gates cannot see: whether a roadmap entry preserves the intent of the `// TODO` it replaced or merely its words; whether an ISO note ended up attached to the column it describes; and whether the relationship labels still read correctly now that `ATTENDEE` is `REGISTRATION`.

## Open questions

- Does `SESSION` belong in the README's domain-model prose as well as in the ERD, or is it authentication plumbing that only the diagram needs?
- `EVENT.creator_id` and `EVENT.manager_id` are the only foreign keys shown as attributes, because they are the only relationships the diagram does not draw. The `[!IMPORTANT]` note says foreign key attributes are omitted where a relationship is visible, so either two more relationship lines to `MEMBER` appear, or the note gets a stated exception. Which?
- Types: keep the generic `STRING`, `TEXT` and `DATETIME`, or use `VARCHAR(250)`, `TEXT(100000)` and `DATETIME(6)` as the DBML file did, carrying the column limits for free?
