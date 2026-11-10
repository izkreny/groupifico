> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: brand the application chrome per domain (#223)

## Approach

Every chrome site except two already reads `Current.brand.name`, so the work is in `Brand` and those two views. `Brand` gains `NAMES` and `TAGLINES` beside `GROUP_TYPES`, each a domain-keyed map with its own default, which is the shape the class comment already argues for: one map cannot carry two defaults, and three cannot share one. `Brand#name` reads `NAMES`, a new `Brand#tagline` reads `TAGLINES`, and `layouts/entry.html.erb` and `feedbacks/show.html.erb` read `Current.brand` instead of their hardcoded strings. The model spec owns the domain matrix (branded, unbranded, nil, any letter case); the request specs own that each site shows the request's brand, plus the `www.` collapse that only `request.domain` performs.

## Steps

- ::S1:: In `spec/models/brand_spec.rb`, replace the "until #223 lands" example with one expecting "Chorifico" for `chorifico.com`, add one for `ChoRifico.COM`, and watch both fail against `Brand` as it is on `main`
- ::S2:: Add `Brand::NAMES` and read it in `Brand#name`; rewrite the class comment's "carries `group_type` alone", the `GROUP_TYPES` comment's "a second branded domain is a row here" and the `DEFAULT_NAME` comment's "until #223", which this change makes false
- ::S3:: In `spec/requests/sessions_spec.rb`, assert that `GET /session/new` on `www.chorifico.com` titles the page, its `application-name` and its masthead "Chorifico", and on `127.0.0.1` "Groupifico"; in `spec/requests/groups_spec.rb`, assert that `GET /groups` on `chorifico.com` heads the shell "Chorifico" and keeps its own "Your groups" title; commit S1 to S3 together
- ::S4:: Add `#tagline` examples to `spec/models/brand_spec.rb`: "Who's coming to rehearsal." for `chorifico.com` in any letter case, "Who's coming to the next event." for an unbranded domain and for nil; watch them fail against `main`
- ::S5:: Add `Brand::TAGLINES`, `Brand::DEFAULT_TAGLINE` and `Brand#tagline`; render `Current.brand.tagline` in `app/views/layouts/entry.html.erb` and drop the comment there that defers per-brand copy to #223
- ::S6:: Render `Current.brand.name` in the thank-you copy of `app/views/feedbacks/show.html.erb`
- ::S7:: In `spec/requests/sessions_spec.rb`, assert the entry line on `chorifico.com` and on the default host; in `spec/requests/feedbacks_spec.rb`, assert the thank-you copy names "Chorifico" on `chorifico.com` and "Groupifico" on the default host; commit S4 to S7 together

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-10_GHI-223_brand-chrome-per-domain.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-10_GHI-223_brand-chrome-per-domain.md` exits 0
- ::V3:: `mise exec -- bin/rspec spec/models/brand_spec.rb` passes, having been seen to fail the new `chorifico.com` `#name` examples and every `#tagline` example against `app/models/brand.rb` as it is on `main`
- ::V4:: `mise exec -- bin/rspec spec/requests/sessions_spec.rb spec/requests/groups_spec.rb spec/requests/feedbacks_spec.rb` passes, having been seen to fail the "Chorifico" examples against `main`; the examples that already pass on `main` are each seen failing on a mutation instead: the "Groupifico" ones on `Brand::DEFAULT_NAME` set to "Chorifico", the kept "Your groups" title on `_head.html.erb` rendering `Current.brand.name` alone, the "rehearsal" line on `chorifico.com` on `entry.html.erb` hardcoding the event line, and the "Groupifico" thank-you copy on `feedbacks/show.html.erb` hardcoding "Chorifico"
- ::V5:: `mise exec -- bin/rubocop app/models/brand.rb spec/models/brand_spec.rb spec/requests/sessions_spec.rb spec/requests/groups_spec.rb spec/requests/feedbacks_spec.rb` exits 0
- ::V6:: `mise exec -- bin/ci` passes, browser suite and Herb's linter included

No gate sees the live site: that `https://chorifico.com/session/new` reads "Chorifico" and the rehearsal line after the deploy is the owner's to judge.

## Open questions

None.

## Settled

- ::Q1:: What does the entry line say on the general brand? "Who's coming to the next event.", with Chorifico keeping "Who's coming to rehearsal.", settled in the terminal before the issue was finished.
