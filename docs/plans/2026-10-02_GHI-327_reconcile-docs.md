> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: reconcile the docs with the code (#327)

## Approach

Every document the issue names is read claim by claim, and each claim is checked against the code on `main` by the method its kind allows: an identifier is grepped, a route is read from `bin/rails routes`, a path is resolved, a version is read from the lockfile, and a stated behaviour is checked by reading the code that implements it. The one drift already known lands first, in `docs/AUTHORIZATION.md`: the `User` guard beside `Member`'s and `Role`'s under *No capability can leave a group without an active owner*, and under *Records that have no group at all* the fact that `UsersController#destroy` runs under `skip_verify_authorized` on `Current.user`, with no policy deciding it. `CLAUDE.md` is a symlink to `AGENTS.md`, so one audit covers both.

Fixes stay prose-only. Where the capability tables and a policy disagree, the table wins per *Specification, or record?* and the disagreement becomes a `bug` issue; where a record sentence and the code disagree, the sentence is rewritten. Creating an issue needs the owner's confirmation and this branch is worked without them in the room, so a bug or a drift that needs a code change is drafted in the implementation handoff, flagged so the chain stops there, and never created silently. Each document's drift, or the absence of one, is listed in the pull request body under `## Drift found`, one line per document, since the issue asks for that record and the body's capped sections cannot hold it.

## Steps

- Fix the known drift in `docs/AUTHORIZATION.md`: name `User`'s `before_destroy` guard beside `Member`'s and `Role`'s, and say that deleting an account is `UsersController#destroy` acting on `Current.user` under `skip_verify_authorized`, with `UserProfilePolicy` deciding the profile alone
- Audit the record half of `docs/AUTHORIZATION.md`: the two questions, the status filter, `WRITE_RULES`, every class, method and constant its prose names, against `app/policies/`, `app/models/` and `app/controllers/`; for each table row, read the rule it names and note any cell the rule contradicts
- Audit `README.md`: the domain-model prose against `app/models/`, and both `mermaid` diagrams against `db/schema.rb`, entity by entity and attribute by attribute
- Audit `AGENTS.md`: the versions against `Gemfile.lock` and `package.json`, the linter claims against `bin/rubocop`, `.rubocop.yml`, `.herb.yml` and `config/ci.rb`, and each linked path
- Audit `.agents/testing.md`, `.agents/dependencies.md`, `.agents/rails-style.md` and `.agents/gh-solo.md` the same way, with `.agents/gh-solo.md`'s CI claims read against `.github/workflows/ci.yml` and the branch protection `gh api` reports, and `.agents/rails-style.md`'s list of `skip_verify_authorized` callers against `app/controllers/`
- Check every pointer: each `docs/` or `.agents/` path a code comment names resolves, and each italicised section heading one document cites in another exists under that name; list both sets in the pull request body
- Write `## Drift found` into the pull request body, one line per document naming the fix or that none was found; a table-versus-policy disagreement or a drift that needs code is drafted as an issue in the handoff rather than fixed here
- Run `bin/ci` in this worktree

## Verification

- ``grep -q 'before_destroy.*`User`' docs/AUTHORIZATION.md`` exits 0, having been seen to exit 1 on `main`
- `grep -q 'skip_verify_authorized' docs/AUTHORIZATION.md` exits 0, having been seen to exit 1 on `main`
- `grep -rhoE '(docs|\.agents)/[A-Za-z0-9_./-]+\.md' app config lib spec | sort -u | xargs ls` exits 0
- Each `mermaid` block of `README.md`, extracted to its own file, renders through `mmdc -p <puppeteer-config> -i <file> -o <file>.svg` with exit 0, the config pointing `executablePath` at the system Chromium; seen to exit 1 on a block with an unterminated attribute comment
- `bin/ci` is green
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans --ignore '~/*' README.md AGENTS.md .agents docs/AUTHORIZATION.md docs/plans/2026-10-02_GHI-327_reconcile-docs.md` exits 0

Whether a sentence's claim about behaviour matches the code is a reading, not a command, so the gates prove that the two named fixes landed, that every pointer resolves and that the diagrams still parse, never that every claim was checked. The `## Drift found` list in the pull request body is the record of that reading, and the review round is what checks it. Rendering a diagram proves its syntax, not that its entities match `db/schema.rb`; that comparison is a step, recorded the same way.

## Open questions

None.

## Settled

None yet.
