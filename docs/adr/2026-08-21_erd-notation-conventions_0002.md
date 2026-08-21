> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0002. ERD notation conventions

## Status

Accepted, 2026-08-21. Supersedes nothing.

## Context

This repository documented its schema twice. `docs/schema.dbml` held a DBML description of it, and `README.md` held a mermaid ERD, and by August 2026 both disagreed with `db/schema.rb`: they named an `Attendee` model that a February migration had renamed to `Registration`, they listed `username`, `time_zone` and `uid` columns that were never built, and neither knew that a `sessions` table and a `password_digest` column existed. Two documents describing one schema is one document too many, and the second one is where the rot starts, because nothing forces either to agree with the code or with the other.

Issue #81 deleted the DBML file and made the README ERD the only schema document. That is only an improvement if the ERD can carry what the DBML file carried, and the DBML file carried a great deal that `db/schema.rb` cannot express: enum value names, since Rails stores bare integers and the names live in the models; foreign key delete and update rules; the notes recording that `state_code` is ISO 3166-2, `country_code` is ISO 3166-1 alpha-2 and the whole address follows ISO 20022; and the reasoning behind the composite unique indexes.

So the notation had to absorb detail without becoming unreadable, which is the tension every decision below resolves. The record exists because those decisions are invisible in the result: a reader of the diagram sees a convention and cannot tell which alternatives were considered, which were tried, or which are load-bearing.

Three properties of mermaid constrain all of it, and each was checked against mermaid's own source or documentation rather than assumed.

- The official attribute syntax is `type name key "comment"`, with keys limited to `PK`, `FK` and `UK`, multiples comma-separated, and the comment last in double quotes.
- `%%` is stripped by a preprocessing pass whose regex is `/^\s*%%(?!{)[^\n]+\n?/gm`, anchored to the line start. The ER grammar has no `%%` rule of its own. So a `%%` after content on the same line is never removed, reaches the ER lexer as raw text, and breaks the parse.
- A relationship statement names entities on both sides and nothing else. There is no attribute-level anchor, so an edge cannot say which column it belongs to.

## Decision

### The rendered diagram carries the shape, the source carries the detail

Every attribute's rendered comment holds its keys and its nullability, and nothing else. Everything further, the column limit, the enum's options, the default, and any field note, sits on a `%%` line immediately above that attribute inside the entity block, where the preprocessor deletes it before the parser runs.

This is the decision the rest follow from. The alternative considered first was packing that detail into the quoted comment, which is the only per-attribute field mermaid renders. It fails on width: an entity box is as wide as its widest row, so one row carrying enum options plus a limit plus a note stretches every row in that entity, and the diagram becomes less readable in exact proportion to how well documented it is.

Placing the detail in a `%%` line on the same row as the attribute was tried and does not work, per the preprocessing regex above. The line immediately above is the closest position that does, and it keeps the detail adjacent to what it describes.

**Verified rather than reasoned:** a probe diagram with `%%` lines above an entity and above individual attributes inside its block was rendered with `mmdc`, and the resulting SVG contains no occurrence of any comment text while the attributes themselves render.

**Each `%%` line names the field and the concern it describes**, so that it still reads correctly if the attribute below it is ever moved or removed.

### Attributes read `type name "key, comment"`, with keys in the comment

Type first and name second, which is mermaid's own order. The previous diagram had them reversed, and additionally wrote the key inside the comment string, which meant mermaid never rendered it as a key.

The order is now correct and the key placement is a deliberate deviation, recorded in the diagram's own frontmatter. Using mermaid's native `key` field would give every entity box a third column for four short tokens, and the two-column box is what keeps the diagram compact. The cost is that mermaid does not know these are keys and cannot style them; the benefit is a narrower diagram, and this diagram exists to be read rather than to be machine-parsed.

### Rails types, not SQL types

`STRING`, `TEXT`, `INTEGER`, `DATETIME`, `FLOAT`, matching how the schema is written and read in this project, rather than `VARCHAR(250)` and friends as the DBML file used. A type may legally carry parentheses in mermaid, so `VARCHAR(250)` was available and was rejected.

Two facts decided it. A Rails `limit` is a number of characters for a `string` column and a number of bytes for `text`, `binary`, `blob` and `integer`, per Active Record's own `add_column` documentation, so a single number in a SQL type would silently mean different things on different rows. And SQLite does not enforce a declared length at all: a `VARCHAR(5)` column accepts a 21-character string, `typeof` reports `text`, and only the declared type string survives in the schema. Writing SQL types would therefore state a constraint the database does not apply.

The limits are still documented, in the `%%` comments, because they are what the model validations are set from and what a move to another database engine would need. `events.description` is the clearest case: 100,000 bytes at the column against a 25,000-character validation in the model, which is a deliberate four-bytes-per-character projection for worst-case multi-byte text, not two numbers that happen to disagree.

### Nullability is rendered, on every attribute, as `NN` or `NULL`

Both states are marked rather than marking one and letting the blank mean the other. Among the 28 columns this diagram renders, 13 are `NOT NULL` and 15 are nullable, so neither is a default: a blank comment would mean "nullable" and "nobody has filled this in yet" at the same time, and at a 13 to 15 split there is no safe reading of an absence.

`NN` is not a new token; it was already in use in the default-attributes block. The accepted cost is that every attribute now carries a comment where many carried none, so every entity box widens by roughly the width of `NULL`, uniformly rather than one row at a time.

### Foreign key columns are omitted, with two named exceptions

A foreign key attribute is omitted where a relationship line already shows the link, which is what keeps `MEMBER` down to two rows rather than four. `EVENT.creator_id` and `EVENT.manager_id` are shown instead, and the asymmetry is the point: `group_id` and `member_id` can be omitted because their names say where they point, by a convention every reader of a Rails schema already has, while `creator_id` and `manager_id` both point at `MEMBER` and their names do not say so.

Drawing them as relationships was considered and rejected. Mermaid's `optionally to` would give a dashed, non-identifying line, which would honestly reflect that neither column has an `add_foreign_key` behind it. But it would add two more edges between a pair of entities that already have one, and since a relationship cannot be anchored to an attribute, neither edge could say which column it represented. Two extra edges to convey less than the two attribute rows already do.

### Authentication is not in this diagram

The `sessions` table gets no entity and the prose gets no `Session` section, because passwordless login is still ahead and the auth model will be drawn separately rather than crowding this one. `users.password_digest` is shown, because `users` is in the diagram and a rendered entity that hides one of its columns is the failure this whole exercise is correcting.

**The omission is declared in the diagram rather than left silent.** An ERD that quietly lacks a table that exists is exactly what made the DBML file untrustworthy, and a reader who cannot tell "documented elsewhere" from "stale" has to distrust the whole diagram.

### The legend lives outside the fenced block

Beside the diagram, as a markdown table, not inside it. Inside the fence a legend is either a `%%` comment, which never renders, or a fake entity box, which puts documentation into the picture it documents.

The legend and this ADR are deliberately two documents for two audiences. The legend says what the notation means, which a reader needs in order to read the diagram at all. This file says why the notation is that and not something else, which only somebody proposing to change it needs. Keeping them apart is what stops the argument about Rails limit units and SQLite type affinity from landing next to the diagram and burying it.

## Consequences

**The source of `README.md` is now part of the documentation, not just its rendering.** Anyone reading the rendered README on GitHub sees a compact diagram and a legend; anyone who needs enum options or cascade rules has to open the file. That is a deliberate trade and it is the only reason the diagram can stay compact while carrying everything the DBML file did.

**`db/schema.rb` remains the authority and the diagram remains a description.** Nothing regenerates one from the other, so a migration that changes a column leaves the diagram wrong until somebody updates it. The verification in issue #81's plan checks the diagram against `db/schema.rb` mechanically, and repeating that check is the cheapest way to catch drift; making it a CI job would be cheaper still and is not done.

**A notation change now costs an edit in three places:** the diagram, the legend, and this record. That is the intended friction. The previous arrangement, where the notation was described in a two-line frontmatter comment that had drifted out of agreement with the diagram it described, cost nothing to change and was wrong.

**Enum values are documented in two places**, here in the diagram's comments and in the models where they are defined. The models are authoritative. This is accepted because the alternative, a diagram that names an integer column and says nothing about what its integers mean, is what `db/schema.rb` already offers and is the gap the DBML file existed to fill.
