> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: drop the session routes with no action (#332)

## Approach

`config/routes.rb` narrows `resource :session` to `only: %i[ new create destroy ]`, the shape its `sign_in` and `sign_up` siblings already have. The route helpers every caller uses survive unchanged: Rails still names `POST /session` and `DELETE /session` as `session`, so `session_url` in `app/views/sessions/new.html.erb`, `session_path` in `app/views/user_profiles/show.html.erb` and every `new_session_path` keep resolving.

The proof that the three doors are gone is a `recognize_path` example per verb and path, the form `spec/requests/addresses_spec.rb` already uses for its missing `DELETE /addresses/:id`. Today each of them recognizes to `sessions#show`, `sessions#edit` or `sessions#update`, so the examples are red on the unchanged routes by construction.

## Steps

- Add "is not routable" examples to `spec/requests/sessions_spec.rb` for `GET /session`, `GET /session/edit`, `PATCH /session` and `PUT /session`, leaving every existing example as it is
- Run `spec/requests/sessions_spec.rb` against the unchanged `config/routes.rb` and watch all four new examples fail
- Add `only: %i[ new create destroy ]` to `resource :session` in `config/routes.rb`
- Run the spec file again and watch it pass, read `bin/rails routes -c sessions` for the issue's first criterion, then run `bin/ci`

## Verification

- `bin/ci` passes
- `bin/rspec spec/requests/sessions_spec.rb` passes, its four new examples having been seen red on the unchanged routes

What these gates cannot see: `bin/rails routes -c sessions` exits 0 whatever it prints, so the issue's first criterion is read off its output rather than gated; the new examples carry the same fact with an exit code.

## Open questions

None.

## Settled

- The new examples live in `spec/requests/sessions_spec.rb` beside the sign-in and sign-out examples, which stay byte-for-byte as they are; that is the issue's "untouched", and the file is where `spec/requests/addresses_spec.rb` puts its own not-routable example.
- The route line gets no comment: `only:` naming the three actions the controller defines is the conventional form, and nothing unconventional is left for a comment to explain.
