> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Record the address scoping decision

Issue #187. Acceptance criteria live there.

## Why this issue exists at all

Three comments in the tree name #187 as an open question, and the question is answered. `config/routes.rb` promises a reuse flow the event form only "gestures at"; `spec/requests/addresses_spec.rb` leaves "whether a reusable venue catalogue should exist" to #187; `app/policies/address_policy.rb` says that if two groups pointing at one address "ever becomes reachable, this is the line to revisit". A reader who follows any of the three finds an issue, not an answer, and concludes the model is unsettled. It is settled: an address belongs to one group, reuse happens inside that group, and there is no cross-group catalogue.

So the deliverable is prose, in the three places the code already looks. There is no migration and no controller change; the review round added one policy fix, which `## Settled` below records.

## What the record is written from

- **The two doors that could break the convention, each checked rather than recalled.** `GroupsController#group_params` permits `address_attributes: [ :id, ... ]`, so a submitted `id` is the obvious way to point one group at another group's address; Rails' one-to-one nested attributes refuses it with `ActiveRecord::RecordNotFound` in all three shapes - a group that already has an address, a group that has none, and a group being created. `EventsController#foreign_address?` shuts the other, and `spec/requests/events_spec.rb` covers it with "ignores an `address_id` belonging to another group".
- **The insert order that priced the alternative out.** Giving `addresses` a `group_id` would replace four derivations of one fact with a column and let `AddressPolicy` answer `group_for`. `Group belongs_to :address` with nested attributes inserts the address before the group, so the column cannot be `NOT NULL` while the group holds the pointer - watched in the log, `Address Create` then `Group Create`. Satisfying it means dropping `groups.address_id`, flipping the group to `has_one`, inventing a marker for the home address and backfilling the rest. #187's technical notes carry both, which is why the comments cite the issue rather than restating the argument.

## What each comment becomes

The pattern is the one `config/routes.rb` and `spec/requests/addresses_spec.rb` already use for the question #172 answered: **"Settled on #172"**, a citation that reads as closed. Each of the three gains the same form for this question, so the issue number stays and only its tense changes.

- **`app/policies/address_policy.rb`**, in the `owners` comment: say why nothing can point two groups at one address - the nested-attributes refusal and `foreign_address?` - instead of leaving "if that ever becomes reachable" pointing at an open issue. The `any?` reasoning it explains is unchanged and stays.
- **`config/routes.rb`**, in the `resources :addresses` comment: the reuse flow is not future work. `EventsController` picks out of `group.addresses` today, which the same comment already says two sentences earlier, so the closing clause replaces a promise with the scope of what exists.
- **`spec/requests/addresses_spec.rb`**, in the comment closing the routes-that-no-longer-exist block: the venue catalogue was declined, and the reason is that an address belongs to one group.

## Steps

- Rewrite the closing clause of the `owners` comment in `app/policies/address_policy.rb` to state why two groups cannot point at one address, citing #187 as settled
- Rewrite the closing clause of the `resources :addresses` comment in `config/routes.rb` so the reuse flow reads as existing and per-group
- Rewrite the closing clause of the comment above `describe "the routes that no longer exist"` in `spec/requests/addresses_spec.rb` so the catalogue reads as declined
- Grep the tree for `#187` and confirm no remaining comment presents it as unanswered
- Reserve a group's home address to that group's owner in `AddressPolicy#update?`, cover the refusal and its control in `spec/policies/address_policy_spec.rb`, and state the precedence in `docs/AUTHORIZATION.md`
- Run the gates below

## Verification

- `bin/ci`, the repository's one local gate and a superset of its four CI jobs
- The `gh-solo` documentation check, for backticked paths that do not resolve and code fences that do not close
- `gh pr checks` green on `lint`, `scan_js`, `scan_ruby` and `test`

None of those gates can read. The diff is comments, so `bin/ci` proves only that the files still parse and nothing else broke; a comment that states the convention wrongly is green. Whether each rewrite is true, and whether a reader of any of the three now stops rather than following a pointer, is the owner's judgement on the diff.

## Open questions

None. The decision was made in the session that finished #187's description, against the evidence above; what is left is whether the three comments state it faithfully, which is a review comment rather than an open question.

## Settled

- **Does the argument belong in an ADR, as #186's did?** No. An ADR earns its place when the decision has consequences a reader has to act on; this one records that nothing changes. The issue holds the evidence, and the repository's existing convention is that a comment cites an issue number for the reasoning - which is what "Settled on #172" already does twice.
- **Does `docs/AUTHORIZATION.md` change?** It did in the end, though not for the reason this question was asked. The inheritance and the skipped pre-checks are untouched; what the review added is the precedence between a group and an event pointing at one address, in the note under the tables and in the closing line.
- **`AddressPolicy#update?` grants a group's home address to whoever may edit an event pointing at it. Which side is wrong, the policy or the tables?** Settled in the review round on RF1: the tables. An `events_administrator` may *use* the group's address - point an event at it - and may not edit it, which belongs solely to the `owner`. So the branch was rescoped to carry the fix rather than only the comments: `update?` asks the holding group alone wherever a group holds the address, and falls back to the events for an address no group calls home. The defect was pre-existing; retiring the `- #187` revisit pointer is what surfaced it.
