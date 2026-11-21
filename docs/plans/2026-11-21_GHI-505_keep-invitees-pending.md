> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: keep invitees pending until they join (#505)

## Approach

`MembersController#create` takes the address and nothing else, saves the member `pending` with no role, and sends `MemberMailer.invitation` instead of `MemberMailer.welcome`. The enum default stays `active`, because a link joiner and `Group#add_owner` both rely on it. The member form draws its status and role fields for an existing member only, so a new one shows the address alone. AC5's "set afterwards on the member's edit form" is read as once the invitee has joined. A pending member keeps no pencil and no edit form, so the paragraph in `docs/AUTHORIZATION.md` that says no column changes a pending member through the form still holds.

### The invitation link is not a credential

ADR 0004's `The invitation link is not a credential` decides AC1's "signs them in". The invitation carries no token. It links to the ordinary sign-in form with the address filled in and `return_to` set to the group's invitation page. #430's sign-in cycle then carries that path into the emailed sign-in link and redirects there once the link is redeemed. An invitee who already has an account and is signed in would hit `refuse_authenticated`, which sends them to the root, and the root lists no group they are pending in. So `refuse_authenticated` redirects to `return_to` when there is one and to the root otherwise. `return_to` is already `url_from`'s check, so the change adds no open redirect.

### One join page, reached two ways

N4's route is `resource :invitation, only: %i[ show update destroy ]` under `resources :groups`, served by `Groups::InvitationsController` (`app/controllers/groups/invitations_controller.rb` (new)) in the `entry` layout. It finds the caller's own membership through `Current.user.members`, answers 404 where there is none, and renders `join_requests/new`, so both ways in end on one template. That template's pending branch replaces "Your request to join is waiting for approval." with a filled **Join** and a ghost **Decline**, posting `PATCH` and `DELETE` to the group's invitation path. A pending person who opens a join link therefore gets the same choice. `update` and `destroy` find the membership among the caller's `pending` ones only. `update` writes `status: :active` as a plain write, as ADR 0008 says #505 ships until #126 lands, and redirects to the group's page. `destroy` removes the membership, leaves the user, and redirects to the root. No confirmation is asked, matching the Mobbin screens (Grok, PlanetScale, Attio), and an invitee who declines by mistake can be invited again.

The controller runs under `skip_verify_authorized`, on `UsersController#destroy`'s argument. Its record is named by the caller's own session, never by the URL, so a rule would have one possible input and one possible answer. Both pre-checks in `ApplicationPolicy` refuse a pending member anyway, so a policy here would have to skip them to say anything at all. `docs/AUTHORIZATION.md` records this under the records with no group at all. N2 needs no code: `ProfileSetup` already runs on every GET of a signed-in user, `show` included.

### Resending, and the pre-check that would refuse it

N7's Resend is `resource :invitation, only: :create` under `resources :members`, served by `Members::InvitationsController` (`app/controllers/members/invitations_controller.rb` (new)). It authorizes `MemberPolicy#create?` on an unattached `Member.new(group:)`, the way `Groups::JoinLinksController` does, because resending is inviting again. Asking first means every id gets the same refusal from a member who may not invite, so the refusal confirms nothing. It then finds the member among the group's `pending` ones and sends the invitation again. On the Pending tab the row shows a text "Resend invitation" button in place of the pencil, for the members `manages` already admits, as Slack and User Interviews do.

`conceal_pending_members!` denies every write on a pending record, including `create?` on the new pending member that `MembersController#create` now builds. It is narrowed to a persisted record, because a member being invited is not yet hiding from anybody.

### Out of scope

N6 needs nothing: existing active members stay as they are. No `Member::StatusChange` is written, since #126 has not landed. Withdrawing an invitation is not built: no column removes a pending member today, and N7 asks only for Resend.

## Steps

- ::S1:: In `app/policies/member_policy.rb`, narrow `conceal_pending_members!` to a persisted pending record, and rewrite its comments and the scope's comment so a pending member is an invitee who has not joined. In `spec/policies/member_policy_spec.rb`, add a "#505 AC5" example per role column for `create?` on a new pending member
- ::S2:: In `app/controllers/members_controller.rb`, make `create` build the member from the address alone with `status: :pending`, drop its `manage_roles?` ask and its use of `role_records`, send `MemberMailer.invitation` on every save, and rewrite the WHY comment and the notice. In `app/views/members/_form.html.erb`, draw the status and role fields for a persisted member only and rewrite the address hint. Rewrite the comments at `app/helpers/members_helper.rb` and on `Member#not_moved_into_pending` that say pending is entered by asking to join
- ::S3:: In `app/mailers/member_mailer.rb`, replace `welcome` with `invitation` and rewrite the class comment. Add `app/views/member_mailer/invitation.html.erb` (new) and `app/views/member_mailer/invitation.text.erb` (new), linking `new_session_url(email:, return_to: group_invitation_path(group))`, and delete `app/views/member_mailer/welcome.html.erb` (delete) and `app/views/member_mailer/welcome.text.erb` (delete). Rewrite `spec/mailers/member_mailer_spec.rb` for the invitation, keeping the address and the return path in the query string and no token minted
- ::S4:: In `spec/requests/members_spec.rb`, rewrite the create examples: "#505 AC1" for the pending member and the invitation mail, and "#505 AC5" for a posted status and posted roles leaving the invitee pending with none. Delete the examples for removed behaviour, which are a role granted at invitation, an administrator refused for posting one, an unknown role name on create, and an inactive invitee getting no mail. Add a new-form example showing no status or role field
- ::S5:: In `app/controllers/concerns/authentication.rb`, make `refuse_authenticated` redirect to `return_to || root_path`, with its comment saying why. In `spec/requests/sessions_spec.rb`, add a "#505 AC1" example where a signed-in user opening the sign-in form with a `return_to` lands on that path
- ::S6:: In `config/routes.rb`, add `resource :invitation, only: %i[ show update destroy ], module: :groups` under `resources :groups`, with a WHY comment, and add `app/controllers/groups/invitations_controller.rb` (new). In `app/views/join_requests/new.html.erb`, replace the pending branch with Join and Decline buttons, passing each button's content as the first argument to `button_to`. Add `spec/requests/groups/invitations_spec.rb` (new) covering every action signed in and signed out. It names "#505 AC2" for Join making the invitee active, "#505 AC3" for Decline removing the membership and keeping the user, and "#505 AC4" for the invitee refused the group page until they join. It also covers a non-member's 404, an active or inactive member's update and destroy answering 404, and the N2 redirect to the profile form. In `spec/requests/join_requests_spec.rb`, turn the pending example into one offering Join and Decline
- ::S7:: In `docs/AUTHORIZATION.md`, rewrite the pending sentence of the second question, the "asked to join" capability row, the inviting paragraph and the pending paragraph so pending means invited and not yet joined. Add a paragraph under the records with no group at all saying that answering an invitation asks no policy, and why
- ::S8:: In `config/routes.rb`, add `resource :invitation, only: :create, module: :members` under `resources :members`, and add `app/controllers/members/invitations_controller.rb` (new). In `app/views/members/_member.html.erb`, give a pending row a "Resend invitation" button where the pencil would be, for `manages`. Add `spec/requests/members/invitations_spec.rb` (new), covering resend for each column, a paused manager refused, a non-pending member's 404 and the signed-out redirect. In `spec/requests/members_spec.rb`, add a "#505 AC4" example where the Pending tab lists the invitee with Resend and the Active tab does not list them, and one where an event's roster leaves them off
- ::S9:: Extend `spec/system/join_page_spec.rb` with the invitation in the browser. An invitee signs in from the invitation mail's link, lands on the join page and presses Join, which reaches the group's page. A second invitee presses Decline and lands on the root. Both pages are checked with `be_accessible`. Extend `spec/system/member_new_page_spec.rb` so the form shows the address alone and sending it lands on the pending member, and `spec/system/members_list_spec.rb` so Resend paints on a pending row

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-21_GHI-505_keep-invitees-pending.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-21_GHI-505_keep-invitees-pending.md docs/AUTHORIZATION.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/policies/member_policy_spec.rb spec/mailers/member_mailer_spec.rb` passes. The "#505 AC5" policy examples are seen failing against `main`'s `conceal_pending_members!`, and the mailer examples against `main`'s `welcome`
- ::V4:: `mise exec -- bin/rspec spec/requests/members_spec.rb spec/requests/sessions_spec.rb spec/requests/join_requests_spec.rb` passes. The "#505 AC1" and "#505 AC5" create examples are seen failing against `main`'s `create`. The `return_to` example is seen failing against `main`'s `refuse_authenticated`. The "#505 AC4" roster example passes on `main` and is seen failing with `Member.current` widened to include `pending`
- ::V5:: `mise exec -- bin/rspec spec/requests/groups/invitations_spec.rb spec/requests/members/invitations_spec.rb` passes. The "#505 AC2" example is seen failing with `update` writing `:paused`, "#505 AC3" with `destroy` removing the user rather than the membership, the N2 example with `allow_unset_profile only: :show` added to the controller, and the resend refusals with the `authorize!` call removed
- ::V6:: `mise exec -- bin/rspec spec/system/join_page_spec.rb spec/system/member_new_page_spec.rb spec/system/members_list_spec.rb` passes. The invitation examples are seen failing with the pending branch of `join_requests/new.html.erb` restored
- ::V7:: `mise exec -- bin/rspec spec/styleguide` passes, since the styleguide draws `members/form` for a newcomer and `bin/ci` never runs it
- ::V8:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V9:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot judge the invitation mail's copy, the join page's wording for an invitee, or whether Decline needs a confirmation. The per-criterion screenshots comment is owed after the review round, with AC1's mail in a section that names its spec rather than an image.

## Open questions

None.

## Settled

- None yet.
