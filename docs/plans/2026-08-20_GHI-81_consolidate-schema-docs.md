> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Consolidate the schema docs into the README ERD

Plan for #81.

## Context

The repository documents its schema twice, in `docs/schema.dbml` and in the mermaid ERD inside `README.md`, and both drifted away from `db/schema.rb` months ago. #81 holds the full discrepancy table; the short version is that they name `Attendee`, they list `username`, `time_zone` and `uid` columns that were never built, and neither knows the `sessions` table or `password_digest` exist.

Two documents that disagree with the code are worse than one, so the ERD becomes the only schema document and the DBML file goes. What makes that a migration rather than a deletion is the detail the DBML file holds and `db/schema.rb` cannot express: enum value names, since Rails stores bare integers and the values live in the models; foreign key delete and update rules; the ISO field notes; and the uniqueness notes that explain what the composite indexes are for.

Three facts about mermaid were checked against its own documentation rather than recalled, because the whole rewrite rests on them.

- The official attribute syntax is `type name key "comment"`, keys limited to `PK`, `FK` and `UK`. This diagram deliberately deviates to `type name "key, comment"`, keeping every entity box two columns wide at the cost of mermaid rendering the keys as keys. That is a readability decision, and the `IMPORTANT!` note in the diagram's frontmatter exists to record it.
- The cardinality alias table includes `1` for exactly one and `1+` for one or more, and the documentation's own example combines an alias with a label after a colon. **The existing relationship lines are valid and are not part of this change.**
- A `type` may contain digits, parentheses and square brackets, so `VARCHAR(250)` would be a legal type name. Rejected on the PR in favour of Rails types with the limit in the comment, for the reason below.
- **`%%` is a whole-line comment and nothing else.** The ER grammar has no `%%` rule of its own; mermaid strips those comments in a preprocessing pass whose regex is `/^\s*%%(?!{)[^\n]+\n?/gm`, anchored to the line start. A `%%` placed after content on the same line is therefore never stripped, reaches the ER lexer as raw text, and breaks the parse. Per-attribute detail has to travel in mermaid's own quoted comment field, which the ER grammar tokenises as `COMMENT` inside an entity block. `%%` still works for the section headings and for table-level notes on their own lines, and must not contain `{}`, which the renderer reads as directive syntax.

Two facts about column limits, both checked rather than recalled, because the ERD is about to state them as documentation.

- **A Rails `limit` is characters for `string` and bytes for `text`**, per Active Record's own `add_column` documentation, in activerecord 8.1.3.1, abstract/schema_statements.rb lines 590 to 591. Deliberately not written as a backticked path: it lives inside an installed gem, and a path only valid on one machine's Ruby install is the reason two older plan files now fail the docs check. So `description` at `limit: 100000` is 100,000 bytes, while the model validates it at 25,000 characters: different units and different numbers, and the ERD must not merge them.
- **SQLite does not enforce a declared length.** A test table with a `VARCHAR(5)` column accepted a 21-character string and reported `typeof` as `text`, while `pragma_table_info` still reported the declared type as `VARCHAR(5)`. A limit in this schema is a Rails-level fact, so the ERD states it as one rather than implying a database constraint.

The salvage source is the abandoned `docs-update` branch, whose February README and ERD pass still checks out against today's schema: it commented out exactly the columns that do not exist. Its three useful commits are `3d8400c`, `b491b3f` and `0b63d51`, and the branch stays on the remote until this lands.

## Approach

Rewrite the ERD in place rather than starting from the DBML file. The diagram already has the shape, the relationship lines and the section comments; what it needs is correct entity contents, the DBML detail folded into the comment column, and the attribute order untwisted.

### The ERD conventions, settled in the PR discussion

Readability wins over completeness wherever the two pull apart, because a diagram nobody can scan is worth less than the DBML file it replaces.

- The `"DEFAULT attributes for each ENTITY"` pseudo-entity stays.
- **Rails types, not SQL types**: `STRING`, `TEXT`, `INTEGER`, `DATETIME`, `FLOAT`, matching how the schema is actually written and read here.
- **Attribute order is mermaid's own: `type name "key, comment"`.** Type uppercase, name lowercase, keys uppercase, comment capitalised.
- **Keys stay in the rendered comment**, using only the key vocabulary the diagram already uses, with nothing new invented. `ENUM` stays `ENUM`.
- **The detail does not render.** Everything beyond the key goes on a `%%` line immediately above its own attribute, inside the entity block: the column limit with its unit named, the enum's options, the default, and any field note. The preprocessor deletes those lines before the parser ever sees them, so they cost the rendered diagram nothing and cost a reader of `README.md` one glance. This is the whole design: **a rendered diagram anyone can scan, and a source that carries everything the DBML file did.**
- Table-level facts that belong to no single column, the uniqueness notes and the foreign key delete and update rules, go the same way, on `%%` lines above the entity.
- **Authentication stays out of this diagram.** `sessions` gets no entity and the prose gets no `Session` section, because passwordless login is still coming and the auth model will be drawn separately rather than crowding this one. The omission is declared in a `%%` line rather than left silent, since an undeclared missing table is the exact failure that made the DBML file untrustworthy.

**Everything that is intent rather than schema moves to `docs/ROADMAP.md`.** The unbuilt columns and the DBML file's `// TODO` annotations are design notes that were living in a schema document, which is why the schema document kept looking wrong. The ERD ends up describing only what exists, and the roadmap holds what does not.

## Steps

- Delete `docs/schema.dbml`, and drop the DBML link from the ERD preamble in `README.md` while keeping the `db/schema.rb` link.
- Rewrite the ERD entity blocks to the conventions above, one entity per table in `db/schema.rb` apart from the authentication tables, with `REGISTRATION` in place of `ATTENDEE` and no column that does not exist.
- Fold the DBML detail into the diagram: enum values with their defaults, foreign key delete and update rules, the ISO field notes, and the uniqueness notes for `members` and `registrations`.
- Correct the second line of the `IMPORTANT!` note in the diagram's frontmatter so it states the convention actually in use.
- Rewrite the README domain-model prose: `Registration` in place of `Attendee`, and password-and-session login in place of the magic link.
- Move intent into `docs/ROADMAP.md`: the unbuilt `username`, `time_zone` and `uid` columns, the DBML file's `// TODO` notes, the magic-link login idea, an RSVP locking note and a `counter_cache` note, and rename the section `### Registration`.

## Verification

Gates, each with an exit code:

- `bin/ci` exits zero. This is the repository's only check command, per its own agent config, and a docs-only branch is expected to leave it untouched rather than exempt from it.
- `/home/izkreny/.claude/skills/github-pr-flow/scripts/docs-check.py`, run with `--root .` and `--ignore 'docs/schema.dbml'` over `README.md`, `docs/ROADMAP.md` and this plan file, exits zero: every backticked path still resolves once the DBML file is gone, and every fence is closed. The ignore covers this plan's own references to the file being deleted, and the file list is scoped to what this branch touches, because two older plan files already fail the check on paths that belong to installed gems rather than to this tree.
- Every `create_table` name in `db/schema.rb` except the authentication tables appears as an entity in the ERD, and every attribute in the ERD is a column that exists in `db/schema.rb`. Checked by a throwaway script in the scratchpad, not committed, reported both directions, with the deliberately omitted foreign key columns and the omitted authentication tables listed rather than silently allowed.
- `grep -ric attendee README.md docs/ROADMAP.md` reports zero in both files. Scoped to those two on purpose: `docs/plans/` legitimately says the word.
- Each migrated DBML fact is present in `README.md`: `cascade`, `restrict`, ISO 3166-2, ISO 3166-1, ISO 20022, both uniqueness notes, and every enum value list from the models.

- `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium mmdc -i README.md -o <scratchpad>/readme-erd.svg` exits zero, which renders the embedded diagram through the same mermaid version a browser would use and so proves it parses. The environment variable is not optional: `mmdc` 11.16.0 installs without a browser and fails with "Could not find chrome-headless-shell" until pointed at one, and this machine already has `chromium` and `google-chrome-stable` from zypper, so downloading a third browser would be waste. The repository itself gains no mermaid dependency: there is no Node package manifest here and this adds none.
- The rendered SVG contains none of the `%%` text and all of the attributes. **Verified, not assumed:** a probe diagram with `%%` lines above an entity and above individual attributes inside its block rendered with zero occurrences of that text in the output, while `INTEGER status "ENUM"` and `TEXT description` both appeared. That is what makes the two-layer convention above real rather than hoped for.

Judgement, which no exit code covers:

- **[owner]** The diagram is still readable at a glance. That is the entire reason for the two-column convention, and it is the one thing a longer comment column can quietly destroy. No renderer can answer it, which is why it stays the owner's box even with the CLI installed.

What these gates cannot see: whether a roadmap entry preserves the intent of the `// TODO` it replaced or merely its words; whether an ISO note ended up attached to the column it describes; and whether the relationship labels still read correctly now that `ATTENDEE` is `REGISTRATION`.

## Settled in the PR discussion

- **Types.** Rails types with the limit in the comment, not `VARCHAR(n)`. Both halves of the reason were checked: a Rails `limit` is characters for `string` and bytes for `text`, and SQLite enforces no declared length at all, so a SQL type in this diagram would state a constraint the database does not have.
- **Attribute order is `type name "key, comment"`**, type uppercase and name lowercase, matching mermaid's own convention rather than the twisted order in place today.
- **The rendered comment stays short and the detail goes in `%%` lines above each attribute.** A trailing `%%` on the same row would break the parse, and a comment long enough to hold the detail would wreck the diagram it documents, so the detail leaves the rendered layer entirely.
- **The limits are documentation, not enforcement.** SQLite ignores them, so their value is as the reference the model validations are set from, and as the numbers a future migration to another engine would need. `description` at 100,000 bytes against a 25,000-character validation is a deliberate four-bytes-per-character projection, worst case for multi-byte characters, and the ERD records it as such rather than as two unrelated numbers.
- **Authentication is out of scope for this diagram**, and the ERD declares the omission.
- **Rendering becomes a real gate** once the owner installs the mermaid CLI, and the readability check stays an `[owner]` box because no renderer can answer it.

- **`EVENT.creator_id` and `EVENT.manager_id` stay as attributes.** Not drawn as relationships. The reason is an asymmetry the diagram already encodes: `group_id` and `member_id` can be omitted because their names say where they point, by a convention every reader knows, while `creator_id` and `manager_id` do not, since both point at `MEMBER`. The two that need saying are said, the rest are silent, and the `[!IMPORTANT]` note states that rule. Two more edges, dashed or not, cost the drawing more than they add. Mermaid also has no way to attach an edge to a single attribute, so a relationship line could not express which column it belongs to anyway.

## Open questions

None. Every question this plan opened was settled in the PR discussion.
