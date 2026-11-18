> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let signed-in visitors ask to join (#447)

## Approach

**The button posts to `JoinRequestsController#create`, per N2, routed by adding `create` to `resource :join_request, only: %i[ new create ], path: "join"`.** The join page draws it with `button_to` for a signed-in visitor who holds no membership of the group, carrying the link's token as a parameter the way #446's form carries it in a hidden field. Opening the page is a `GET` that writes nothing, so a link previewed or opened by accident adds nobody (AC1).

**`create` writes `@group.members.create_with(status: :pending).find_or_create_by!(user: Current.user)` and redirects back to the join page.** `status: :pending` is stated outright because `Member` defaults to `active`, and a link that skipped it would let anyone straight in (AC2). Finding first means a second press, a double-click or a form left open in another tab changes nothing about a membership that already exists, whatever its status, so an `inactive` member pressing a stale button is not restored and no uniqueness error reaches the visitor. The redirect lands on the join page, which then shows the pending state, so the page itself is the confirmation and a reload never resubmits.

**The join page answers a signed-in visitor by the membership they already hold (AC4).** `new` looks up `@group.members.find_by(user: Current.user)`; `active` or `paused` reads that they are already in the group, with a link into it; `pending` reads that their request is waiting for approval; `inactive` reads that they left and that only an owner or administrator can bring them back. None of those draws the button. The pending state here is only the join page's answer; what a pending member sees on reaching the group itself is #449's.

**One `before_action` resolves the token for both actions**, replacing the inline lookup in `new`, so a link turned off or regenerated after the page was opened answers `create` with the same `404` and writes nothing (AC6).

**`create` asks no policy, joining `new` under the permanent `skip_verify_authorized`.** The link is still the visitor's whole standing: a pending member is refused everything in the group exactly like a non-member, so creating one grants nothing until somebody in the *Add a person* row approves it, which is #448's. Unlike `new`, `create` requires sign-in, so `.agents/rails-style.md`'s reason for this controller's skip, "unauthenticated by design", becomes false for it and is reworded, and `docs/AUTHORIZATION.md`'s join link paragraph says what pressing the button does.

## Steps

- ::S1:: Extend `docs/AUTHORIZATION.md`'s *Opening a join link* paragraph to say that a signed-in visitor's button adds them as a pending member and asks no policy, because pending grants nothing until approved; in `.agents/rails-style.md` give `JoinRequestsController` its own reason in the permanent-skip list, the link being the visitor's whole standing, since its `create` requires sign-in
- ::S2:: Route `create` on `resource :join_request` with its `WHY:` comment updated, move the token lookup in `app/controllers/join_requests_controller.rb` into a `before_action` for `new` and `create`, extend `skip_verify_authorized` to `create` with its comment updated, add `create` writing the pending membership and redirecting to the join page, and extend `spec/requests/join_requests_spec.rb` with `POST /join` proving: a signed-in visitor becomes a pending member of the link's group and is redirected to the join page (AC2); an `active`, `paused`, `pending` or `inactive` member pressing it is redirected with their membership unchanged and nothing added; a link turned off, regenerated or never minted answers `404` and adds nothing (AC6); and a visitor who is not signed in is redirected to sign in and adds nothing
- ::S3:: Draw the signed-in states on `app/views/join_requests/new.html.erb`, with `new` setting `@member` for a signed-in visitor: the "Ask to join {group}" button for one with no membership, and for one with a membership the already-in, waiting-for-approval or left message by its status; extend the signed-in examples of `spec/requests/join_requests_spec.rb` so opening the page adds nothing and shows the button posting the token (AC1), and each status shows its message and no button (AC4)
- ::S4:: Extend `spec/system/join_page_spec.rb` with a signed-in visitor pressing the button and landing on the waiting-for-approval state, and with the button state and each membership state passing axe in light and dark (AC1, AC2, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-18_GHI-447_ask-to-join.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-18_GHI-447_ask-to-join.md docs/AUTHORIZATION.md .agents/rails-style.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; the `POST` examples are seen failing against `main`, which routes no `create`; then the pending example against a `create` that drops `status: :pending`, the four unchanged-membership examples against one that builds a new member instead of finding the existing one, the `404` examples against one that skips the token lookup, the signed-out example against `create` added to `allow_unauthenticated_access`, the button example against a view drawing no button, the adds-nothing `GET` example against a `new` that creates the membership, and each status example against a view drawing the button for every signed-in visitor
- ::V4:: `mise exec -- bin/rspec spec/system/join_page_spec.rb` passes; the pressing example is seen failing against a `create` that redirects without writing, and the accessibility examples against the button rendered with no accessible name
- ::V5:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed view exit 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether the button and the three membership messages read clearly to somebody who has just opened a link from a group chat; that is the owner's to judge on screen.

## Open questions

None.

## Settled

None yet.
