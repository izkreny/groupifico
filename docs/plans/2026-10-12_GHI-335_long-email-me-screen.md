> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Keep a long email inside the Me screen

## What overflows

The Me screen never draws the email itself. What overflows is the name heading in `app/views/user_profiles/_user_profile.html.erb`: a member with no first or last name is headed by `UserProfile#full_name`'s fallback, the email's local part, and `create(:user)` builds exactly that member. A local part is one word with nowhere to break, and the `h1` sits in a flex row beside the avatar, so it keeps its full width and pushes the page sideways. Signing in as `maximilian.featherstonehaugh-wolstenholme@example.com` shows it as 102px of overflow at the 390px phone width.

## The fix

The `h1` takes `min-w-0`, which lets the flex row shrink it below its content's width, and `truncate`, which cuts it to one line with an ellipsis. Truncation rather than wrapping is the owner's call on the issue. The full address stays one tap away, in Edit me behind the Account row, and the truncated heading still carries the whole text for a screen reader. Truncation applies to any heading too long for its line, so a real name that long is cut the same way rather than wrapped.

## Seen red

- The overflow example in `spec/system/me_spec.rb`, signing in the fixed long address, fails on the unchanged heading with 102px of overflow.

## Steps

- Sign the overflow example in `spec/system/me_spec.rb` in with a fixed long email, and watch it fail against the unchanged heading.
- Add `min-w-0 truncate` to the `h1` in `app/views/user_profiles/_user_profile.html.erb`, and watch the example pass.
- Run `bin/ci`.

## Verification

- `bin/rspec spec/system/me_spec.rb` passes, its overflow example having failed on the unchanged heading
- `bin/ci` is green

No gate looks at the truncated heading itself, only at the page's width, so whether the ellipsis reads well under both themes is the owner's to judge on the Me screen of a member with no name.
