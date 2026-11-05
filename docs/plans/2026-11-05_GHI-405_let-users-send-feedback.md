> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: let users send feedback (#405)

The acceptance criteria live on #405, and the design and architecture behind them were settled with the owner before this plan, on Mobbin-backed mockups; the plan only says how.

## The record

- One table, `feedbacks`: `user_id` (foreign key), `description` (text), `context` (JSON), `issue_number` (integer, empty until filed) and timestamps. Everything captured without typing lives in `context`: the page path, the user agent, the revision and every device field, since nothing ever queries them and they only travel into the issue body.
- `bin/rails active_storage:install` adds `active_storage_blobs`, `active_storage_attachments` and `active_storage_variant_records`, its standard migration unedited; Active Storage is configured for local disk in every environment but has never been installed. Files land under `storage/`, the Kamal volume, never in SQLite.
- `Feedback` in `app/models/feedback.rb` (new): `belongs_to :user`, `has_many_attached :screenshots`, `store_accessor :context` for each captured field, `normalizes` the page to its path, and validations: a present description, at most 3 screenshots, each PNG, JPEG, GIF or WebP by its sniffed content type and at most 5 MB, HEIC refused with its own message, every context field in its expected shape, and length caps on the description and the whole context, since SQLite enforces neither.
- `Feedback::Filing` in `app/models/feedback/filing.rb` (new): `after_create_commit :file_issue_later`, and `file_issue`, which returns at once when `issue_number` is set, otherwise uploads the screenshots, creates one issue and writes its number back.
- `Feedback::GithubIssue` in `app/models/feedback/github_issue.rb` (new): a plain Ruby object on `Net::HTTP` with exactly two calls, upload an attachment and create an issue, per the 37signals pattern of `Webhook::Delivery` and `Opengraph::Fetch`. The token and the private repository's name come from Rails credentials.
- `Feedback::FileIssueJob` in `app/jobs/feedback/file_issue_job.rb` (new): `perform(feedback)` calls `feedback.file_issue`, retrying with backoff on network and GitHub errors.

## The request

- `resources :feedbacks, only: %i[ new create show ]` in `config/routes.rb`.
- `FeedbacksController` in `app/controllers/feedbacks_controller.rb` (new): `new` keeps the Referer's path in a hidden field; `create` builds from `Current.user`, the params and `request.user_agent`, saves, and redirects with 303 to `show`; `show` is the thank-you page. `rate_limit` keyed `by: -> { Current.user.id }`, as `ActionController::RateLimiting` allows.
- `FeedbackPolicy` in `app/policies/feedback_policy.rb` (new): `create?` for any signed-in user, `show?` for the author only, and the controller finds through `Current.user.feedbacks`.
- The revision is read once at boot into `config.x.revision` from `KAMAL_VERSION`, which Kamal 2.12 sets in the app container's environment, and is blank in development.
- `public/500.html` links to `/feedbacks/new`. The app sets no `Referrer-Policy`, so the browser default sends the failing page as the Referer and `new` records it with no special case.

## The screens

- Built through the daisyUI Blueprint MCP server, with the `daisyui-blueprint-mcp` skill loaded first, in the `organic` and `organic-dark` themes, default daisyUI components only.
- `app/views/feedbacks/new.html.erb` (new): design C, top to bottom: the info alert, the screenshot thumbnails with an Add screenshot tile, the description textarea with its placeholder and a screen-reader label, the one note below the form, then Cancel and Send. The copy is #405's, verbatim.
- `app/views/feedbacks/show.html.erb` (new): the success alert "Your feedback was sent.", then, centred, "Thank you", the line and "Back to where you were" to the recorded page.
- `app/views/layouts/_me_menu.html.erb`: a Send feedback row just below Edit profile, with `icon :feedback`, a new meaning in `IconsHelper::ICONS` mapped to `chat-bubble-left-ellipsis`.
- `ApplicationHelper`: the thank-you page carries a group and a section read from the recorded page's path, only when the user is a current member of that group, so its tabs and dock draw as on that page; from a page outside any group it draws none.
- Three Stimulus controllers in `app/javascript/controllers/`: `feedback_context_controller.js` (new) fills the hidden device fields on connect; `feedback_draft_controller.js` (new) keeps the description in `localStorage`, restores it on connect and clears it when the thank-you page loads; `screenshots_controller.js` (new) draws a thumbnail per picked file with a remove button and hides the Add tile at 3, keeping the file input's list in step through `DataTransfer`.

## Seen red

Every example is new and covers code that does not exist yet, so each is red before its step lands: an unknown constant, a missing route or a missing column. The ones below can pass vacuously once the code exists, so each names the mutation, a throwaway edit never committed, that must turn it red.

- Model: a screenshot whose bytes are a PNG but whose declared type is `text/plain` is accepted, and a text file declared `image/png` is refused. Removing the content-type check turns the second red.
- Model: `file_issue` on a feedback that already has an issue number makes no GitHub call. Removing the early return turns it red.
- Model: the page is stored without its query string, so a sign-in token in the Referer never survives. Removing the normalisation turns it red.
- Request: another user's feedback answers not found. Finding through `Feedback` instead of `Current.user.feedbacks`, with `show?` relaxed, turns it red.
- Request: the sixth submission inside the window is refused. Removing `rate_limit` turns it red.
- System: a description typed, the form left and reopened, still holds the text. Removing the restore in `feedback_draft_controller.js` (new) turns it red.

## Steps

- Install Active Storage and add the `feedbacks` migration and `Feedback` with its validations, normalisation and model spec
- Add `Feedback::GithubIssue`, `Feedback::Filing` and `Feedback::FileIssueJob` with their specs, `Net::HTTP` stubbed at its boundary with RSpec doubles, no new gem
- Verify against a throwaway private repository whether GitHub accepts a fine-grained token on the attachment upload, and keep the Contents API fallback only if it refuses
- Add the route, `FeedbacksController`, `FeedbackPolicy`, the revision config and their request and policy specs
- Build the form, the thank-you page and the three Stimulus controllers through the Blueprint MCP server, with their system spec
- Add the Send feedback row and its icon, the thank-you page's tabs in `ApplicationHelper`, and the `public/500.html` link, with their specs

## Verification

- Every example in "Seen red" was seen red, by the condition it names
- `bin/rspec spec/models/feedback_spec.rb spec/models/feedback spec/jobs spec/requests/feedbacks_spec.rb spec/policies/feedback_policy_spec.rb`, every file new
- `bin/rspec spec/system/feedback_spec.rb`, a new file
- `bin/rspec spec/system/me_spec.rb spec/system/group_shell_spec.rb spec/helpers/application_helper_spec.rb`
- `bin/ci`

No gate here can tell whether picking a screenshot from a real iPhone's or Android phone's gallery works, or whether the form stays usable with the on-screen keyboard open: #405's last criterion asks for that check on real devices, which only the owner can run.

## Open questions

- The private feedback repository and its fine-grained token, with Issues write and, if the fallback is kept, Contents write on that repository only, are the owner's to create; the filing steps need both in credentials.
- How long a stored feedback row and its screenshots are kept once the issue exists: keep them, or purge the screenshots after filing?
- On a retry whose earlier attempt timed out after GitHub had created the issue, should the job search the private repository first, or accept the rare duplicate?
- The rate limit: 5 submissions per user within 10 minutes, unless the owner wants other numbers.
