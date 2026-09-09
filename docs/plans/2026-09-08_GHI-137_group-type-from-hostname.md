> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Default a group's type from the hostname

Implementation plan for [#137](https://github.com/izkreny/groupifico/issues/137). The acceptance criteria live on the issue; this file answers *how*.

## The shape

Three objects, each with one job, and the group's enum reads the last of them.

`Brand` resolves a domain to the type a group started there should be. `Current.brand` carries the answer for the length of a request. `Group`'s enum default asks `Current.brand` instead of naming a fixed value.

The mapping has one entry - `chorifico.com` gives `choir` - and every other domain gives `general`. That is the whole behaviour change, and it is why the enum's `default: :choir` comes off rather than being generalised.

## Deviation from the issue's notes, and why

The issue's technical notes say `Current.host`, with `Brand` reading the host itself. This plan carries `Current.brand` instead, resolved once per request in `ApplicationController`, and the difference is worth stating rather than leaving as drift:

- **`request.domain` already does the subdomain collapse the notes asked for.** `ActionDispatch::Http::URL.extract_domain` answers `chorifico.com` for `www.chorifico.com` and for `api.www.chorifico.com`, and `nil` for a bare IP. Verified in `bin/rails runner` against this Rails. So the "match on the domain, not the host" rule needs no code of its own, which is the framework capability that `AGENTS.md` requires be used before anything is hand-built.
- **Resolving once per request beats resolving per `Group.new`.** The enum default is called on every instantiation, and a host string in `Current` would re-run the mapping each time for one answer that cannot change inside a request.
- **`Current.brand` cannot be nil**, because `ActiveSupport::CurrentAttributes` supports a `default:` and calls it when it is a Proc - `activesupport-8.1.3.1/lib/active_support/current_attributes.rb:238`, `Proc === value ? value.call : value.dup`. A `Current.host` of `nil` would push the same guard into the enum's lambda instead, where every reader of `Group` has to know about it.

## What the enum default can and cannot see

`ActiveRecord::Enum#_enum` passes `default:` straight to `attribute(name, **options)` at `activerecord-8.1.3.1/lib/active_record/enum.rb:238`, and `ActiveModel::Attribute::UserProvidedDefault#value_before_type_cast` calls the value when it is a Proc, at `activemodel-8.1.3.1/lib/active_model/attribute/user_provided_default.rb:18`. `dup_or_share` in that same file dups rather than sharing whenever the default is a Proc, so each `Group.new` re-evaluates instead of reusing the first answer. Verified in `bin/rails runner`: one subclass answered `choir`, then `general`, then `choir` again as the host changed under it.

The call is zero-arity and the lambda sees no `self`. This is where it differs from `belongs_to :creator, default:` at `app/models/event.rb:54`, which is a `before_validation` running in record context and can read `group` and `new_record?`. So the rule has to read ambient state, and `Current` is the only ambient state this codebase has.

## Steps

- Add `app/models/brand.rb`: `Brand.for(domain)` returning a brand whose `group_type` is `choir` for `chorifico.com` and `general` for everything else, `nil` included, since `request.domain` answers `nil` on a bare IP. The object carries `group_type` and nothing else - #221 will want a sender address and an API token from the same rule and #223 a display name, but neither is scheduled and an attribute with no caller is speculative generality.
- Add `attribute :brand, default: -> { Brand.for(nil) }` to `app/models/current.rb`, so the unbranded answer comes from the same method rather than a second constructor.
- Set `Current.brand = Brand.for(request.domain)` in a `before_action` on `ApplicationController`, which is what puts the brand in reach of both group-creation routes: `GroupsController#create` and `SignUp.redeem!` from `SignUpConfirmationsController#create`.
- Change `Group`'s enum to `default: -> { Current.brand.group_type }` and drop `default: :choir`.
- Replace the `with_default(:choir)` clause in `spec/models/group_spec.rb:27` with hand-rolled examples, per `.agents/testing.md`: matchers for what they express, hand-rolled for what they cannot. Three cases - no brand set gives `general`, a `chorifico.com` brand gives `choir`, and an explicit `group_type: :band` under that brand still gives `band`. Each wrapped in `Current.set(brand: …)`, which is leak-proof whatever the example order.
- Add `spec/models/brand_spec.rb` for the mapping itself, including `www.chorifico.com`, `api.www.chorifico.com`, a bare IP and `nil`.
- Extend the existing request specs for `groups#create` and `sign_up_confirmations#create` with a `host! "chorifico.com"` context each, one `host! "www.chorifico.com"` example, and one example asserting that the suite's default `www.example.com` host gives `general` - without that last one, the wiring's absence is caught by nothing.
- Update the `group_type` ERD comment at `README.md:142` so it states the rule instead of naming a fixed default.

## Verification

- [ ] `bin/ci`

`bin/ci` is this repository's one gate, per `.agents/gh-solo.md`, and it covers `lint`, `scan_js`, `scan_ruby`, `test` and the browser suite.

What it cannot see: that `chorifico.com` actually resolves to `choir` in production, which is unprovable until [#76](https://github.com/izkreny/groupifico/issues/76) configures the Kamal proxy and its hostnames. Development cannot serve that host either without host-authorization changes this branch has no business making, so the request specs' `host!` is the closest thing to production evidence the branch can offer.

## Consequences worth naming

`db/seeds.rb` builds its groups through the factory with no `group_type`, so seeded groups become `general` rather than `choir`. Nothing asserts their type and generic Faker groups are arguably better described as `general`, so this plan changes neither the seeds nor the factory. Restoring `choir` at either call site would be reinstating the default this issue exists to remove.

`spec/factories/groups.rb` stays minimal and names no `group_type`, per the minimal-factories rule in `.agents/testing.md`.

## Open questions

None.

## Settled

None yet.
