> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let managers correct registrations (#530)

## Approach

`RegistrationPolicy#update?` and `#destroy?` gain `manages_event?`, which `#create?` and `#manage_answers?` already carry (N1). Nothing else decides either capability: `RegistrationsController#update` asks `update?` and `manage_answers?`, `EventsController#authorize_list_changes!` asks `destroy?` of a registration on the event as loaded, and the roster and the edit form's list ask the same rules of a registration with no member on it (N3). So the manager gets the answer pills on every roster row and an enabled trash on every row of the edit form's list without a view naming them. A paused manager is refused both by `ApplicationPolicy`'s status pre-check, since `update?` and `destroy?` are in `WRITE_RULES`, and a manager of another event fails `manages_event?` (AC3, AC4).

### The one view change: a refused hand-on

`_list_fields` asks `destroy?` of `Registration.new(event: event)`, and a refused save draws `event` already carrying the posted `manager_id`. A manager who hands the event on, marks a removal and has the save refused would get the form back with that trash disabled, and a disabled checkbox does not post, so resubmitting drops the removal. `may_fill` already has this fix: `EventsController#update` reads it before assigning anything and `edit.html.erb` passes it through `_form`. `may_remove` gets the same route, `@list_removable` beside `@list_editable`, so the form asks the event as it was loaded. Before this branch the manager's trash was disabled either way, so the defect only becomes reachable now.

### Prose that states the old asymmetry

`docs/AUTHORIZATION.md` marks `manager` on both rows and loses the paragraph "A manager registers and does not remove" (AC5). Two more paragraphs there say the same thing in passing and are corrected, not removed: "A registration is answered, never withdrawn", which gives `destroy?` to the three roles alone, and "Requesting a response for a held place is registering", whose last sentence keeps the manager clear of the change-answer row. The policy's own comments, `Registration#request_response`'s comment, the `_roster.html.erb` header and the spec names and comments that state the asymmetry flip with it.

## Steps

- ::S1:: In `app/policies/registration_policy.rb`, add `|| manages_event?` to `update?` and `destroy?` and rewrite the comments on `create?`, `update?` and `destroy?`. In `spec/policies/registration_policy_spec.rb`, rewrite the header comment, flip the manager's `failed` examples under `update?` and `destroy?` to `succeed`, and add a manager removing their own registration (AC2), the manager of another event in the same group under both rules (AC3) and a paused manager under both rules (AC4), each headed `# WHY: GHI-530 ACn.`
- ::S2:: In `spec/requests/registrations_spec.rb`, replace "changes another member's answer, which the manager may not" with a context for the event's manager: writing `no` over another member's `yes` and `reserved` over another member's `yes` (AC1), refused on a registration of an event they do not manage (AC3), and refused while paused (AC4). Rename the example at "leaves an answer as it was, because a manager does not overrule one" in `spec/requests/registrations/response_requests_spec.rb` so its reason is that a request moves only a held place
- ::S3:: In `app/controllers/events_controller.rb`, read `@list_removable` beside `@list_editable`; pass it from `app/views/events/edit.html.erb` through `app/views/events/_form.html.erb` to `app/views/events/_list_fields.html.erb` as `may_remove`, which falls back to asking the policy where nothing was posted, as `may_fill` does
- ::S4:: In `spec/requests/events_spec.rb`, rewrite the manager context's comment; the manager's show example offers "Yes for Ben Cole" (AC1); the disabled-trash example becomes an enabled trash, and the refused-removal example becomes a posted removal that lands, for another member's registration and for the manager's own (AC2); and a save that hands the event on and is refused draws the removal mark again enabled and checked (S3)
- ::S5:: In `docs/AUTHORIZATION.md`, mark `manager` on both rows, delete "A manager registers and does not remove", and correct the two paragraphs named under *Prose that states the old asymmetry*. Correct the comment above `Registration#request_response` in `app/models/registration.rb` and the last paragraph of the header comment in `app/views/events/_roster.html.erb`

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-25_GHI-530_let-managers-correct-registrations.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-25_GHI-530_let-managers-correct-registrations.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/policies/registration_policy_spec.rb` passes. The flipped manager examples and AC2's own removal are seen failing on the pre-fix policy, AC3's on `manages_event?` widened to `membership.managed_events.exists?`, and AC4's on `update?` and `destroy?` removed from `ApplicationPolicy::WRITE_RULES`
- ::V4:: `mise exec -- bin/rspec spec/requests/registrations_spec.rb spec/requests/registrations/response_requests_spec.rb` passes. AC1's examples are seen failing on the pre-fix policy, AC3's on the same widening and AC4's on the same `WRITE_RULES` removal
- ::V5:: `mise exec -- bin/rspec spec/requests/events_spec.rb` passes. AC1's roster example and AC2's examples are seen failing on the pre-fix policy, and the refused hand-on example on the fixed policy with `_list_fields` asking the policy itself rather than taking `may_remove`
- ::V6:: `mise exec -- bin/rubocop` over the changed Ruby files exits 0
- ::V7:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether a manager correcting answers reads as intended on a real group's event, which is the owner's to judge on screen.

## Open questions

- ::Q1:: AC2 says a manager removes a registration "from the event's roster and from the edit form's list", and the roster has no remove control for anyone. 1. The removal is made in the edit form's list and then shows on both, as built. 2. The roster rows gain a remove control, which is a frontend issue of its own.
- ::Q2:: After this change everyone who reaches the edit form may remove, so `_list_fields` draws its disabled trash for nobody. 1. Keep it, with `may_remove` routed as S3 says, so the form still asks `destroy?` itself, as built. 2. Drop the disabled branch and `may_remove` with it, which also removes S3's hand-on fix, since the trash would no longer ask the event.

## Settled

None yet.
