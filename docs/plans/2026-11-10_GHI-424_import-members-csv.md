> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: import group members from a csv file (#424)

## Approach

`Member::Import` in `app/models/member/import.rb` (new) is a PORO beside the model it creates, the way `Feedback::Filing` sits beside `Feedback`. It takes a group and the CSV text, refuses a header row other than `first_name`, `last_name`, `email`, `mobile_phone` before reading any row, and then runs every row inside one transaction. Each row builds its membership through `group.members.new(email:)`, the path the member form takes, and fills the user's profile: a new user's profile from the row, and an existing user's blank fields only. Each row's outcome is collected as added, joined, already a member, or refused with the record's own error messages, and any refusal rolls the whole transaction back. `lib/tasks/members.rake` (new) stays thin: it finds the group, reads standard input, hands both to `Member::Import` and prints one line per row, aborting on an unknown group, a bad header or any refusal.

Nothing mails anyone, because `MemberMailer.welcome` is sent by `MembersController#create` and not by a model callback. `csv` is no longer a default gem on Ruby 4.0, so it is added to `Gemfile` on its own commit. Real member data never enters the tree: every spec builds its rows from factory data.

## Steps

- ::S1:: Add `gem "csv"` to `Gemfile` with a one-line `WHY:` comment, run `bundle install`, and commit `Gemfile` and `Gemfile.lock` alone
- ::S2:: Write `spec/models/member/import_spec.rb` (new) covering a new address, an address held outside the group, an address already in the group, a refused row rolling back every row, an unexpected header, and no mail sent, and watch it fail with `Member::Import` absent
- ::S3:: Write `app/models/member/import.rb` (new) until S2 passes, and commit it with S2
- ::S4:: Write `spec/tasks/members_import_spec.rb` (new) covering a file read from standard input, the printed line per row, an unknown group id and a bad header aborting before any row is read, and watch it fail with the task absent
- ::S5:: Write `lib/tasks/members.rake` (new) until S4 passes, with the production command from Q1 in its `desc`, and commit it with S4

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-10_GHI-424_import-members-csv.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-10_GHI-424_import-members-csv.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/member/import_spec.rb` passes every example, having been seen to fail every one with `app/models/member/import.rb` (new) absent
- ::V4:: `mise exec -- bin/rspec spec/tasks/members_import_spec.rb` passes every example, having been seen to fail every one with `lib/tasks/members.rake` (new) absent
- ::V5:: `mise exec -- bin/rubocop Gemfile app/models/member/import.rb lib/tasks/members.rake spec/models/member/import_spec.rb spec/tasks/members_import_spec.rb` exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite included

The specs read standard input from a string, so they cannot see the production run itself; Q1's `wc -l` check showed a piped file reaching the container, and the first real import is the owner's to judge, which the all-or-nothing transaction makes safe to retry.

## Open questions

None.

## Settled

- ::Q1:: How does the file reach the production container? Piped: `kamal app exec --interactive --reuse "bin/rails 'members:import[1]'" < members.csv`. Kamal 2.12.0 drops `docker exec` to `-i` when its standard input is not a terminal, so the file streams through SSH into the task and is never stored on the server; the owner confirmed it by piping a file into `wc -l` the same way, which counted its lines in the container.
