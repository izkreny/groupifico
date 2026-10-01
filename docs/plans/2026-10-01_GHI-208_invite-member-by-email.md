> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Invite a member by email address

Implementation plan for [#208](https://github.com/izkreny/groupifico/issues/208). The acceptance criteria live on the issue; this file answers how. Why the invitation carries no credential of its own is [ADR 0004](../adr/2026-08-31_passwordless-email-sign-in_0004.md), under *The invitation link is not a credential*, and is not restated here.

## What already exists

Half of this was built by #139 on the sign-in side. `app/views/sessions/new.html.erb` already fills its email field from `params[:email]`, with a comment naming this issue, and `SessionsController#new` renders without mailing anything, so following the invitation link sends nothing until the person presses the button. What is missing there is a spec saying so.

Landing is also done: `SignInsController#create` redirects to the root, which is `groups#index`, and that lists `User#current_groups`, so a freshly created `active` or `paused` membership is visible the moment the person signs in.

The unique index `index_members_on_user_id_and_group_id` refuses a second membership, but only as a database exception. The criterion that refuses a repeat invitation with a message needs a model validation, which is what #91 describes.

## The approach

**The address lives on `Member`, as a virtual attribute used on create.** `Member#email` resolves `user` with `User.find_or_initialize_by`, normalised exactly as `User` normalises it, so the lookup and the uniqueness index compare one spelling. One `@member.save` then writes the user and the membership in one transaction, which is criterion 2 without a service object. `SignUp` already makes the same normalisation argument and does the same `find_or_create_by!` at confirmation.

**The address is validated on `Member` itself, at least as strictly as `User` validates it.** `belongs_to` saves a new user in `before_save` without validating it first, after the member has already passed its own validation, so a bad address would reach the `INSERT` with a nil `user_id` and answer a 500 rather than a form error. Presence, length and `URI::MailTo::EMAIL_REGEXP` on `Member#email` close that, which is the reasoning `SignUp` records for its own copy of those rules.

**A repeat invitation is refused on the `email` field.** The form builder renders an error under the field it names, so the refusal has to land on `:email` rather than on `:user`, or it would be invisible. It is asked of the group's existing members whatever their status, an `inactive` one included; see *Open questions*.

**The welcome mail is sent by `MembersController#create`, never by a model callback.** A callback would also fire from `Group#add_owner` during sign-up and from every `create(:member)` in the suite. `MemberMailer` (new) is its own mailer, for the reason `SignUpMailer` gives for being one: different recipient, different link, different copy. It is named for the member rather than for an invitation, because *invited* already means something else in this application: a `Registration` status. Its link is `new_session_url(email:)`, a query parameter rather than a path segment, so `config/initializers/filter_parameter_logging.rb`'s existing `:email` filter redacts it, and it mints nothing.

**The form asks for the address only when the record is new.** `member_params` already keeps `user_id` out of updates so a membership cannot be handed to somebody else; the email field follows the same line, and `new_member_params` swaps `:user_id` for `:email`. The `manage_roles?` second question on create stays exactly as it is, which is the roles criterion already met.

## Steps

- `app/models/member.rb`: the `email` virtual attribute, its normalisation and validations on create, the user resolution, and the repeat-invitation refusal on `:email`, with model specs in `spec/models/member_spec.rb` for a new address, a known address, an invalid address and an address already in the group
- `app/mailers/member_mailer.rb` (new) with `app/views/member_mailer/welcome.html.erb` (new) and `app/views/member_mailer/welcome.text.erb` (new): names the group, links to the pre-filled sign-in form, says the page has a button on it and that the link does not expire; `spec/mailers/member_mailer_spec.rb` (new) asserts the addressee, the address in the query string and never the path, and that no `SignInToken` row is minted
- `app/controllers/members_controller.rb`: permit `:email` in place of `:user_id` on create and deliver `MemberMailer.welcome` after a successful save; every `POST` example in `spec/requests/members_spec.rb` moves from `user_id` to `email`, with new examples for creating the user, enqueuing the mail, and the repeat refusal answering `422` with its message
- `app/views/members/_form.html.erb`: the email field, drawn for a new record only; `spec/system/member_new_page_spec.rb` (new) for what the browser adds, the rejected field's message painting and no accessibility violations
- `spec/requests/sessions_spec.rb`: `GET /session/new?email=…` renders the address in the field and enqueues no mail; `spec/system/authentication_spec.rb` gains the invited person's whole route, from the welcome mail's link through the button to a root listing the group
- `docs/AUTHORIZATION.md`: the *Add a person to the group* row says it is done by email address, with a sentence on why inviting needs no rule of its own

## Verification

- `bin/ci`

It cannot see a real mail client: whether the welcome mail reads well, and whether a real mail filter following the link leaves the inbox empty, are the owner's to judge on a deployed environment.

## Open questions

- **Whether an administrator can see that an invited person has never signed in.** The issue asks for this to be decided before building; assumed out of scope here, so nothing is added to `Member` or `User` for it.
- **Whether this PR closes #91.** It is a `draft` with no criteria and no milestone, but the uniqueness validation it describes is what the repeat-invitation criterion needs, so it lands here; assumed the owner closes #91 by hand, so the body does not say `Closes #91`.
- **Re-inviting a member whose status is `inactive`.** Assumed refused like any other existing membership, since an owner or administrator can set the status back on the member's own page; reactivating on invitation would be a second way to change a status.
