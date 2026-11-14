> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: add a group join link (#445)

## Approach

**A join link is a record, not a column.** A `JoinLink` row belongs to one group, through a unique `group_id`, and carries its token under a unique index, from `has_secure_token`. Turning the link on mints a row, turning it off deletes it, and regenerating replaces it, so "on" is a row existing and every link that was ever shared resolves to nothing the moment its row is gone (AC2, AC3). It does not include `Redeemable`, which is single-use and fifteen-minute by construction. A row rather than a `join_token` column also gives #447 something to point at: a join request can belong to the link it came through, and a regenerated link deletes the requests made through the old one by foreign key, which is that issue's AC6.

**The link stays copyable for as long as it is on**, per Q1: the token is stored as it is, so the members page shows the link on every visit, as every comparable screen on Mobbin does (Todoist, Linear, Notion, GitBook, Telegram).

**Managing the link is `Groups::JoinLinksController`, a singular `resource :join_link` under the group**: `create` turns it on or regenerates it, `destroy` turns it off. Both authorize `GroupPolicy#update?`, the owner's alone, so the capability gets a row in the Group table of `docs/AUTHORIZATION.md` and no rule of its own, proven where it is decided exactly as the group's home address is. No new rule name means nothing to add to `ApplicationPolicy::WRITE_RULES`, and a paused owner is already refused `update?`. The controls sit on the members page beneath Invite member, per Q2, and since every member reads that page they are drawn only for a member `GroupPolicy#update?` admits, which is AC4's "see no join link".

**The link opens `JoinRequestsController#new`**, routed as `resource :join_request, only: :new, path: "join"`, with the token in the query string, because only the query string is filtered from the log, per ADR 0004. A token no row carries raises `ActiveRecord::RecordNotFound`, so a link that is off, regenerated, unknown or malformed renders `public/404.html` exactly as a missing record does. A live one renders a page naming the group and nothing else here; the form, the token moved into the browser session, and the rate limits are #446's. It is unauthenticated by design, like the sign-up pages, so it takes a permanent `skip_verify_authorized` naming its action, recorded in `.agents/rails-style.md` and in `docs/AUTHORIZATION.md`'s `## Records that have no group at all`.

The copy control is a new Stimulus `clipboard` controller with a source target and a confirmation, since no controller in `app/javascript/controllers/` copies anything yet.

## Steps

- ::S1:: Add the join link row to the Group table of `docs/AUTHORIZATION.md`, owner alone, with the sentence on rows that have no rule of their own extended to it, and a paragraph under `## Records that have no group at all` saying opening a join link asks no policy; add `JoinRequestsController` to the permanent skips listed in `.agents/rails-style.md` (AC4)
- ::S2:: Add a migration creating `join_links` with a unique, cascading `group_id` and a unique `token`, the `JoinLink` model in `app/models/join_link.rb` (new) with `has_secure_token`, `.mint`, which replaces the group's existing row and returns its token, and `.find_by_token`, which answers `nil` for a blank, malformed or unknown token, `has_one :join_link` on `Group`, a factory in `spec/factories/join_links.rb` (new), and `spec/models/join_link_spec.rb` (new) proving the token is stored, a minted token resolves, a replaced or deleted row's token does not, and a blank or non-string token answers `nil` (AC2, AC3)
- ::S3:: Route `resource :join_request, only: :new, path: "join"`, add `app/controllers/join_requests_controller.rb` (new) and `app/views/join_requests/new.html.erb` (new) on the `entry` layout, and `spec/requests/join_requests_spec.rb` (new) proving a live token renders the group's name signed in and signed out, and a token that was turned off, regenerated, never minted, or left blank answers `404` (AC2, AC3)
- ::S4:: Route `resource :join_link, only: %i[ create destroy ], module: :groups` under `resources :groups`, add `app/controllers/groups/join_links_controller.rb` (new) authorizing `update?` on the group, and `spec/requests/groups/join_links_spec.rb` (new) proving an owner's `create` turns the link on and lands on the members page, a second `create` retires the first, `destroy` retires it, and an administrator, an events administrator, a members administrator, a plain member and a paused owner are each refused both actions with the link unchanged, a non-member gets `404` and a signed-out visitor the sign-in redirect (AC1, AC2, AC3, AC4)
- ::S5:: Draw the join link controls on the members page, for an owner, in `app/views/groups/_join_link.html.erb` (new): off shows a turn-on button, and on shows the link in a read-only field with Copy, Regenerate and Turn off; add `app/javascript/controllers/clipboard_controller.js` (new); extend `spec/requests/members_spec.rb` with both states for an owner and no section for every other column or a paused owner, and `spec/system/members_list_spec.rb` with turning the link on, copying it, regenerating it and turning it off, each state painted and accessible (AC1, AC2, AC3, AC4)

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-12_GHI-445_group-join-link.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-12_GHI-445_group-join-link.md docs/AUTHORIZATION.md .agents/rails-style.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/join_link_spec.rb` passes; the stored-token example is seen failing against a `.mint` returning a token it never stored, the replacement example against a `.mint` that creates without removing the group's existing row, and the `nil` examples against a `.find_by_token` without its string guard
- ::V4:: `mise exec -- bin/rspec spec/requests/join_requests_spec.rb` passes; the `404` examples are seen failing against a controller that renders the page whether or not a row was found
- ::V5:: `mise exec -- bin/rspec spec/requests/groups/join_links_spec.rb` passes; the refusal examples are seen failing against the controller authorizing `show?` instead of `update?`, and the retirement examples against a `create` that keeps the old row and a `destroy` that deletes nothing
- ::V6:: `mise exec -- bin/rspec spec/requests/members_spec.rb` passes; the owner's state examples are seen failing against a members page that does not render the join link partial, and the absence examples against one that renders it for everyone
- ::V7:: `mise exec -- bin/rspec spec/system/members_list_spec.rb` passes; the copy example is seen failing against a `clipboard` controller whose `copy` action does nothing
- ::V8:: `mise exec -- bin/rubocop` over the changed Ruby files and `node_modules/.bin/herb-lint --ignore-disable-comments` over the changed views exit 0
- ::V9:: `mise exec -- bin/ci` passes, browser suite included

The gates cannot see whether the join link's copy reads as clear to an owner, nor whether the new Group table row reads as the rule the owner means; both are the owner's to judge on the members page and in the diff.

## Open questions

None.

## Settled

- ::Q1:: N1 stored only a digest, so an owner would see the link once and regenerate it, retiring the shared one, to copy it again. Keep N1, or store the token so the link stays copyable? Decided on #453: store the token as it is, readable for as long as the link is neither turned off nor regenerated.
- ::Q2:: Where do the join link's controls live? Decided by the owner in the session: on the members page beneath Invite member, where people already come in, not on the group's edit screen.
