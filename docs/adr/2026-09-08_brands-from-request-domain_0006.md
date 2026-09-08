> 🤖 Written by AI --- read/modified by izkreny! 🤓

# 0006. Brands resolved from the request domain

## Status

Accepted, 2026-09-08.

Records the decisions #137 builds, so that #137 and its two siblings cite this file rather than each carrying the reasoning. #221 and #223 consume the same rule and are the reason the mechanism is written down before either of them exists.

## Context

Groupifico serves, or will serve, several brand domains. `chorifico.com` is registered; `bandifico.com` and `groupifico.com` are not. Groupifico is the platform's canonical name and the others are brands sitting on top of it, so nothing here is a rename.

Three issues want the same question answered - what brand did this visitor arrive through - and each wants a different thing from the answer. #137 wants a new group's `group_type`. #221 wants a sender address and a MailPace API token. #223 wants the browser tab, the `application-name` meta and the PWA manifest. #221 established that the answer must come from the request rather than from a group's type, because one person can belong to a choir and a band at once, and because a sign-in request carries only an email address and a sign-up carries no group at all.

`Group` defaulted `group_type` to `choir` before this, which was a placeholder rather than a decision: it made every group started anywhere a choir.

## Decision

### The framework was checked before anything was designed

`ActionDispatch::Http::URL::DomainExtractor` already collapses subdomains: `domain_from` is `host.split(".").last(1 + tld_length).join(".")`, guarded by `named_host?`, which returns nil for an IP. So `www.chorifico.com` and `api.www.chorifico.com` both answer `chorifico.com`, and a bare IP answers nothing. `request.domain` is that facility, and matching a host by hand would have re-implemented it worse - a bare equality check against `chorifico.com` would answer `general` on every subdomain the proxy serves.

Rails also ships `ActiveRecord::Middleware::ShardSelector`, whose `shard_resolver` takes the request and is documented with a subdomain example. It selects a database shard, which is not this problem, but it settles the shape: resolve from the request once, early, and stash the result.

### The brand is resolved from the domain, downcased

Nothing upstream normalises case. `ActionDispatch::Request#host` is `raw_host_with_port.sub(/:\d+$/, "")`, which strips the port and nothing else, and `domain_from` only splits and rejoins. Hostnames are case-insensitive per RFC 4343, so a client or proxy that does not lowercase the `Host` header would miss the mapping and get an unbranded group. Rails' own request tests cover IP hosts and multi-label TLDs and never cover a mixed-case host, so the framework is not going to catch this.

This is a recognised hazard rather than a theoretical one. Of the open-source Rails applications surveyed that resolve a host to configuration, most downcase somewhere in the path and several carry tests for a mixed-case `Host`; `gumroad` carries a comment recording the same bug reaching production, where a valid visitor was refused because Rack handed Rails the header as the browser sent it.

A trailing-dot FQDN needs no handling here, which was established by running it rather than reasoned: `chorifico.com.` already resolves to `choir`, because the split-and-rejoin drops the empty final label. An application comparing a whole hostname does need to strip it, which is why `gumroad` does and this does not.

### `Current.brand` carries the answer for the request

One `before_action` on `ApplicationController` sets `Current.brand = Brand.new(request.domain)`. This is the framework's own assumption: `ActiveSupport::CurrentAttributes` is what the authentication generator produces, the sign-up guide uses throughout, and `ActiveRecord::QueryLogs` reads `Current.tenant&.id` from.

Setting it centrally rather than in the two controllers that create groups is what keeps `SignUp.redeem!` out of it. That is a class method with no request in reach, and threading the domain down to it would put an argument through the transaction that finishes a sign-up.

`Current.brand` declares a callable default, `-> { Brand.new(nil) }`, so it is never nil. `CurrentAttributes` documents this - "If the value is a proc or lambda, it will be called whenever an instance is constructed... Default values are re-assigned when the attributes are reset" - and calls it eagerly, in `resolve_defaults`, on construction and on every reset. Without it the nil check would move into every reader instead.

### The group's type is set in a callback, not by a callable enum default

`Group` sets its own type in a `before_validation` on create, reading `Current.brand`, and its `enum` declares no default at all.

A callable `enum default:` was built first and rejected on evidence. It works - `enum` forwards its options to `attribute` - but it is unprecedented and its timing is wrong. Unprecedented: no application in the ~196 surveyed uses a callable `enum default:`, Rails' own `enum` tests use only static values, and every `enum default:` across the three 37signals applications surveyed passes a plain symbol.

The timing is the substantive half, and the two mechanisms are opposites. `CurrentAttributes` resolves a Proc default eagerly, per reset. `ActiveModel::Attribute::UserProvidedDefault` resolves one lazily and memoises it: `@memoized_value_before_type_cast ||= user_provided_value.call`, confirmed by Rails' own "procs are memoized before type casting". So a `Group` built inside a request and first read outside one resolves against whatever brand is current at the read. Both routes to a group happen to read it in-request, because `save` runs the validation that reads it, but that made the correctness an accident of call order that needed a comment and two specs to explain.

A `before_validation` has no such edge: it runs at a defined point inside `save`, so there is nothing to document. The trade is that an unvalidated `Group.new` carries no type at all, where the enum default answered one on read; the type is settled by `valid?`, which is the point every route to a group passes through.

`||=` carries the whole guarantee and no second guard is needed. An `on: :create` condition was written first and removed: the column is `null: false`, so a persisted row always has a type and `||=` already declines to overwrite it. Nothing could be made to fail without the condition, and with it present a spec asserting that an edit from another domain does not retype a group passed whether or not the operator was correct - the two guards masked each other. It is also what the surveyed applications do - `code_fund_ads` sets an organisation with `self.organization_id ||= Current&.organization&.id`, and `fizzy` defaults a column from a mapping with `before_validation -> { self[:color] ||= DEFAULT_COLOR.value }`.

### `Brand` is a thin value object, and not an ActiveRecord model

`Brand` holds the domain-to-`group_type` mapping and answers `group_type`. It is a plain class in `app/models/`, not a service object, and `app/services` remains unused.

The surveyed applications overwhelmingly resolve a host to an ActiveRecord row - `Site`, `Organization`, `Store`, `Tenant`, `Instance` - and that is the right answer for an application whose operators add domains through an admin screen. It is the wrong answer here: there is one registered domain, no table, and no operator. A `sites` table would be built for a future that is not scheduled.

The alternative was a frozen constant and a class method on `Group`, which is the 37signals reflex for a small closed mapping and would touch two files instead of four. It was rejected on reach rather than on size. A constant on `Group` answers only about group types, and the same question has two other consumers that want a display name and a sender address. `Brand` is where those land, under the vocabulary #223 fixes.

The cost is stated plainly: `Brand` today carries one attribute and its body is a `fetch` against a one-entry constant, and it does not implement `==` or `hash`, so it has a value object's shape without a value object's contract. It earns its place on what #221 and #223 will ask of it, and if either is abandoned it should be folded into `Group`.

### The reach, and the one place it does not reach

`Current.brand` is readable wherever the request is: controllers, views, partials, helpers. That is how #223 gets the browser tab and the PWA manifest, and reading `Current` in a view is established practice in the surveyed 37signals applications.

**It does not reach a mailer sent with `deliver_later`, and it fails quietly there.** `ActiveSupport::CurrentAttributes.clear_all` runs on `executor.to_complete`, and the executor wraps a job as well as a request, so a job starts with the defaults - meaning `Brand.new(nil)`, meaning `general`. A mail rendered in a job would be unbranded rather than raise. #221 already records the remedy: the host is passed into `deliver_later` as an argument.

## Consequences

**`general` is now what an unbranded arrival gets**, and the enum's fixed `choir` default is gone. A group created on `localhost`, on a bare IP, or on any domain not in the mapping is `general`. `db/seeds.rb` builds through the factory and names no type, so seeded groups are `general` too; nothing asserts their type and generic sample groups are better described that way, so neither the seeds nor the factory compensates.

**A new brand domain is a row in `Brand::GROUP_TYPES` and nothing else.** Registering `bandifico.com` and mapping it to `band` is one line. #118 adds a `team` type that a later domain could map to, and nothing here waits on it.

**The mapping cannot be exercised against production until the proxy serves those hostnames**, which #76 owns. Until then the request specs' `host!` is the closest evidence available, and development cannot serve `chorifico.com` without host-authorization changes that are out of scope.

**Whoever adds the second consumer decides whether `Brand` becomes a record.** The trade-off above is written so that decision is made against the reasoning rather than rediscovered: the case for a plain object was never that an ActiveRecord `Site` is worse in general, it was that one domain and no operator do not justify a table.

**Anything resolved from the request host belongs on `Current`, set in that one `before_action`.** A second `before_action` reading `request` for a second purpose would be two answers to one question, and the surveyed applications that hand-roll per-request state - a thread-local, a class variable - are the ones that did this before `CurrentAttributes` existed rather than examples to follow.
