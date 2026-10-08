> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0007. Strict loading

## Status

Accepted, 2026-10-08.

Records the decisions #261 builds, so that #261 and the issues that follow from it cite this file rather than each carrying the reasoning. The rule a spec author follows lives in `.agents/testing.md`, under *Lazy loading*; this record is why the rule is what it is. #343 and #345 pick up the two costs it leaves open.

## Context

The redesign's cards and rosters, #246 first, read registrations, members and profiles per row, which is where a view quietly starts loading one record at a time. #261 asked for a lazy load to raise in the spec that renders it, so that a query's shape is a decision made where the records are loaded rather than an accident found in production logs, and it asked for production to stay off, because a violation there would be a 500 for a page that used to render.

The database is SQLite, which runs inside the application's own process, so a query is a function call rather than a network round trip and an N+1 costs far less here than on a client-server database. The point of this work is the discipline, not speed.

Rails 8.1 ships everything used here: `strict_loading_by_default`, `strict_loading_mode` with its two values `:all` and `:n_plus_one_only`, relation-level `.strict_loading`, and `action_on_strict_loading_violation` with `:raise` and `:log`. Edge Rails adds no third mode. Nothing here needs a gem.

## Decision

### `:n_plus_one_only`, not the default `:all`

Under `:all` the suite failed 467 of 984 examples, most of them one record reading its own association - the signed-in session reading its user, a member reading its roles inside a policy - which is one query, never one per row. Many of those records were built by a spec's factory, with no controller or scope to preload from, so the only fixes left would have been `strict_loading!(false)` on the record, which #261 forbids, or rewriting the specs. Under `:n_plus_one_only` the same suite failed 78, every one a real site: event and member pages, the invite-all read, and the destroy cascades.

`:n_plus_one_only` marks the records a `has_many` loads lazily and nothing else. That includes a single record fetched through one, such as `@group.events.find`, so a show page answers for its own reads, and it excludes rows fetched straight off a model class and records a preload brought in. The measured table of what raises is in `.agents/testing.md`.

### Raise in test and development, log in production

Test raises, which is the gate. Development raises too, because a page clicked through while working is the one place a view no spec renders still runs; #261 first asked for `:log` there and the owner changed it on PR #339. Production leaves strict loading off by default, and sets the violation action to `:log` because the next decision marks list rows in every environment.

`:log` reports through `strict_loading_violation.active_record`, which Rails' log subscriber writes at debug level only, so at production's `info` level a missed read costs a query and leaves no trace. #345 owns making it visible.

### The list each index scopes is strict, through `authorized_scope`

The two kinds of record `:n_plus_one_only` leaves unmarked are exactly where a list's N+1 hides. Relation-level `.strict_loading` marks every row a relation returns and every record its preloads bring in, and it was confirmed to raise on both. `verify_authorized_scoped` already refuses an index action that skips `authorized_scope`, so `ApplicationController#authorized_scope` appends `.strict_loading` once and no list query has to remember it. Mutating a list view with a per-row lazy read failed 7 and 6 examples with the override and none without it.

Rows from a strict relation run in `:all` mode whatever the class default is, which is why production needs the `:log` action and why setting a mode for production would change nothing.

### Each model's preloads live in its `preloaded` scope

`Event.preloaded`, `Member.preloaded` and `Registration.preloaded` hold what each model's screens read, and every display load in the controllers, the helpers, the layout and the models' own methods goes through them; the specs that read an association use the same scopes. This is the named-scope shape the 37signals applications use (`Card.preloaded` in Fizzy), applied to every load rather than to lists only. Fizzy loads a single record with a plain `find` and reads it lazily, which works there because it runs no strict loading; here the record would raise, so the scope is what lets the page load, at the same cost of one query per association. Each scope is the union of what its screens read, so a site can fetch an association it does not draw - measured at one or two queries a page and under a millisecond.

### A destroy cascade preloads before it runs

`dependent: :destroy` loads its children through the association, so each child is strict and its own dependents raise. Rails offers nothing on the cascade's side, so `User`, `Group` and `Member` each preload what their cascade reads in a prepended `before_destroy`, which the cascade then reuses. Preloading the same rows down two cascade paths deletes them twice, 12 DELETEs for 6 registrations when tried, so `Group` leaves its events' registrations to the members cascade and accepts one empty query per event instead.

### One opt-out

`strict_loading(false)` on a relation, with a `WHY:` comment at the call site, for a query that answers one record per screen. `Group#featured_event` is the one use. Never `strict_loading!(false)` on a record.

## Alternatives considered

**Hand-written `.strict_loading` on each list query** is what rubygems, discourse and hcb do. It worked here first, and it left a rule that nothing enforces, which the `authorized_scope` override replaced.

**A custom RuboCop cop** to enforce the per-query call. None exists to start from, in rubocop-rails 2.38 or among the custom cops of the surveyed applications, and the override made the call site disappear rather than need checking.

**An N+1 detector gem**, `bullet` being the common one and `prosopite` the one that would also see the gaps below. Either duplicates most of what strict loading already does, needs an install, and is left as the next step if the gaps bite.

**No strict loading, as the 37signals applications do**, preloading by hand through named scopes. That is the house style's default, and the reason to depart from it is #261's own: the lists #246 brings are where a missing preload creeps in, and a spec that fails the first time one does is cheap here.

Across the 196 applications surveyed, 8 use strict loading at all, one of them with this mode as its default; none enables it in a test environment, and none enforces the per-query call.

## Consequences

**The gate covers what specs render and nothing else.** A record fetched straight off a model class outside a list, a second list an index builds outside `authorized_scope` (`groups#index`'s `@memberships`), a list a show action builds (`members#show`'s managed events, `addresses#show`'s events), rows chained off a record that itself came through a `has_many`, and any view no spec renders all pass silently. `.agents/testing.md` names them, so a green suite is read as strong evidence rather than proof.

**Strict loading complains about a missing preload, never an unused one.** The scopes are unions, and before they were, `set_member` preloaded every registration a member ever had for a page that read none. #343's follow-up trims each scope to what its screens read once lists are paginated.

**Production is silent about violations**, because `:log` writes at debug level. #345 decides how they reach anyone.

**A new screen that reads an association adds it to the model's `preloaded` scope**, and a new list goes through `authorized_scope`, or it carries `.strict_loading` itself where it cannot.
