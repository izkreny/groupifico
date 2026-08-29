> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Document the authorization model and decide the role capabilities

Closes #188.

## Approach

The document is already written and the table is already marked. Both were drafted and approved before this branch had a plan, so this issue is not a writing exercise: the prose lands close to verbatim, and the plan exists for the three things around it.

**Two of the issue's criteria are not met by the approved draft.** It explains `404` over `403` without pointing at ADR 0003, and it never says plainly which parts are decided and which are not. Both are one paragraph each, and both are the criteria most easily lost in a document that otherwise reads finished.

**The table's columns need one vocabulary entry.** `members_administrator` is a column and is not in `Role::NAMES`, which the document itself names as the authority on the columns. A column that names a role the code has never heard of is exactly the "looks authoritative and is wrong" failure the issue was opened to avoid, so the name lands here and the rules that consult it stay in #173.

**One comment and one spec description say something that stops being true.** `Member#can_manage?`'s comment calls `:members` a module with no role of its own, and a `member_spec` example repeats the phrase in its description. The example's expectation is unaffected: an owner still answers `can_manage?(:members)`.

Nothing in this branch enforces a single cell. That is the point of the split, and it is why `## Verification` below is shorter than the work looks.

## Steps

- Write `docs/AUTHORIZATION.md` from the approved draft, dropping its `Not part of the document` section, which exists only for the review round that produced it.
- Add the ADR 0003 pointer where the document explains why a non-member gets `404` rather than `403`. The ADR keeps the reasoning; the document keeps a link to it, per the issue's criterion that a second copy is worse than a pointer.
- State plainly what is decided and what is not: the status filter is decided and enforced today, every mark in the tables is decided and enforced by nothing until #96 and #173 land, and the document says which is which rather than leaving a reader to infer it from tense.
- Add `members_administrator` to `Role::NAMES`, after `events_administrator`, keeping the array's shape of `owner`, `administrator`, then module roles.
- Correct the comment above `Member#can_manage?` and the description of the `member_spec` example that repeats it, so neither still calls `:members` a module with no role of its own.
- Add one `member_spec` example proving a `members_administrator` answers `can_manage?(:members)` and does not answer `can_manage?(:events)`, watched failing before `Role::NAMES` changes.
- Run `bin/ci`.
- Tick the issue's acceptance criteria as each verifiably lands.

## Verification

Gates, each with an exit code:

- **The new `members_administrator` example is watched failing before the vocabulary changes.** It fails on the `inclusion` validation, which is the precise reason the name has to be in the array, so the failure is the check doing its job rather than an incidental red.
- `bin/ci` passes. It is the one local gate for this repository, a superset of `lint`, `scan_js`, `scan_ruby` and `test`.
- The plugin's `scripts/docs-check.py` over the plan and the new document: every backticked path resolves and every code fence closes. `docs/AUTHORIZATION.md` does not exist while the plan is being checked, so that one path is ignored on the first run and checked for real once the file lands.
- `grep -rn songs_administrator` over the files this branch touches returns nothing.

What these gates cannot see:

- **They cannot test a single cell of the table.** A green `bin/ci` proves the document parses and the vocabulary validates; it proves nothing about whether any policy honours a mark, because no policy consults one yet. The table becomes testable in #96 and #173, and until then its only reader is a person.
- They cannot tell a wrong mark from a right one. The marks are the owner's decision, and the document records them rather than deriving them.
- They cannot catch the document drifting from the code later. Nothing links the two until each marked cell has the spec that mirrors it.

## Settled

**The issue's criterion says two comments call `:members` an administrator-only question; only one does.** The phrase appears once in application code, above `Member#can_manage?` at `app/models/member.rb`, and once more in the description of an example in `spec/models/member_spec.rb`. `Role::NAMES`'s own comment does not say it. The criterion is satisfied by correcting the comment and the spec description, and the issue body is corrected to name those two rather than a comment that does not exist.

**The issue says the member form grows a `members_administrator` checkbox the moment the name lands. It does not, because the form has no role checkboxes at all.** `app/views/members/_form.html.erb` renders a status select and nothing else, so no role of any name is grantable through the interface today, and `MembersController`'s own comment about "the form, whose checkboxes are rendered from that list" describes a form that was never built. Adding the name therefore changes no UI, which makes this branch smaller rather than larger. The gap predates this issue and is not about the new role, so it stays out; see `## Open questions`.

## Open questions

**Should the member form get its role checkboxes, and where?** Not in this branch, on the argument above: no role is grantable through the UI, which is a gap in #93's delivery rather than something the new name introduces, and who may grant a role is #173's decision, so a form built before it would be built against no rule. The candidates are a new issue blocked by #173, or folding it into #173 itself, which already owns the create-time roles criterion. Recommending the second.

**Does `MembersController`'s stale comment get corrected here?** It sits one line from `Role::NAMES` and is wrong on a different axis than the comments this branch fixes. Correcting it is one line and the alternative is leaving a comment that describes a form nobody wrote. Recommending it lands with whichever change builds the form, so the comment and the thing it describes are true in the same commit.
