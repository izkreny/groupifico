> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: deploy the application to a vps with kamal (#76)

## Approach

Kamal is already current: `Gemfile.lock` pins `kamal` 2.12.0, which is the newest release on RubyGems, so every command here runs through `bin/kamal` and nothing is bumped. Kamal builds the image on the developer machine by default, and that machine has no Docker yet, so a local Docker install is the first step and waits on the owner like every other install.

The application goes onto the shared VPS that will also host a sibling app. kamal-proxy runs once per host and routes by hostname, so a second app on the box is an ordinary Kamal setup rather than a special case. The image goes to ghcr.io under the repository owner's namespace, and `.kamal/secrets` gains `KAMAL_REGISTRY_PASSWORD` read from the environment, never from a committed file.

`config/deploy.yml` gets the real server, the ghcr.io registry and a `proxy` block with `ssl: true` and the application's hostnames. The owner holds both `chorifico.com` and `groupifico.com` and wants both serving from the first deploy, so the hosts are those two and their `www` subdomains, and kamal-proxy obtains a Let's Encrypt certificate for each. The stale `RUBY_VERSION: 3.4.7` in the commented builder args becomes 4.0.9, matching `Dockerfile` and `.ruby-version`.

`config/environments/production.rb` turns on `assume_ssl` and `force_ssl`, which `config/deploy.yml` states an SSL proxy requires. `assume_ssl` marks every request as HTTPS, so `force_ssl` never redirects and `ssl_options` needs no `/up` exclusion. `config.hosts` admits both domains and their subdomains, with `host_authorization` excluding `/up` as the generated comment on that line recommends for the health check endpoint, and the mailer's `default_url_options` host moves off `example.com` to whichever host Open questions settles.

## Deploy overlap

Kamal always boots the new container and health-checks it before it stops the old one, whether or not the role is proxied. For a few seconds per deploy, two Puma processes, each running Solid Queue in-process, therefore share the SQLite files on the `groupifico_storage` volume, and the new container runs `bin/rails db:prepare` from `bin/docker-entrypoint` while the old one still serves. SQLite is built for several processes on one file, so this is not a corruption case. The two costs are a second Solid Queue supervisor polling the same queue and an old process serving against a schema the new one may just have migrated. The alternative is a `pre-app-boot` hook that stops the old container first, which trades the gapless deploy for a few seconds of downtime on every deploy. Open questions carries the choice.

## Steps

- ::S1:: Owner step: install rootless Docker on the developer machine and start its daemon, since `docker` group membership grants root-level privileges
- ::S2:: Owner step: name the VPS address and the SSH user Kamal connects as, and confirm the box is x86, since `builder.arch` is `amd64`
- ::S3:: Owner step: point the DNS A records of `chorifico.com`, `www.chorifico.com`, `groupifico.com` and `www.groupifico.com` at the VPS
- ::S4:: Owner step: create a GitHub token with `write:packages` and export it as `KAMAL_REGISTRY_PASSWORD` in the shell that runs Kamal, noting that ticking `write:packages` on a classic token also ticks `repo`
- ::S5:: Build the image locally with `docker build -t groupifico .` against the `RUBY_VERSION=4.0.9` that `Dockerfile` already carries
- ::S6:: Fill in `config/deploy.yml`: `servers.web`, `image`, the ghcr.io `registry` with its username and password secret, the `proxy` block with `ssl: true` and all four hosts, and `RUBY_VERSION: 4.0.9` in the commented builder args
- ::S7:: Add `KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD` to `.kamal/secrets`
- ::S8:: In `config/environments/production.rb`, turn on `assume_ssl` and `force_ssl`, set `config.hosts` for both domains and the `/up` exclusion in `host_authorization`, and set the mailer host Open questions settles
- ::S9:: Apply the overlap decision from Open questions: either no hook, or a `pre-app-boot` hook in `.kamal/hooks/` that stops the old container
- ::S10:: Run `bin/kamal setup` against the VPS from a clean checkout
- ::S11:: Write a marker file into `/rails/storage` on the running container, deploy a trivial change with `bin/kamal deploy`, and read the marker and the production database back
- ::S12:: Tick each of the issue's acceptance criteria as its gate passes

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-07_GHI-76_deploy-to-vps-with-kamal.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-07_GHI-76_deploy-to-vps-with-kamal.md` exits 0
- ::V12:: `test "$(docker context show)" = rootless && docker buildx create --name kamal-driver-check --driver docker-container && docker buildx inspect --bootstrap kamal-driver-check && docker buildx rm kamal-driver-check` exits 0, having been seen to exit 1 with the rootless daemon stopped, since Kamal builds with the `docker-container` driver and neither Kamal's nor Docker's documentation says it works under rootless Docker
- ::V3:: `docker build -t groupifico .` exits 0
- ::V4:: `bin/kamal config` exits 0
- ::V5:: `grep -nE '^[^#]*(192\.168\.0\.1|localhost:5555|example\.com)' config/deploy.yml config/environments/production.rb` finds nothing, having been seen to find all three placeholders against `main`
- ::V6:: `bin/ci` passes, browser suite included
- ::V7:: `bin/kamal setup` exits 0
- ::V8:: `curl -fsS https://chorifico.com/up && curl -fsS https://groupifico.com/up` exits 0, which fails on an invalid or self-signed certificate for either domain
- ::V9:: `curl -fsSI https://chorifico.com/ | grep -qi '^strict-transport-security'` exits 0, having been seen to exit 1 against a deploy with `force_ssl` commented out, since kamal-proxy answers the HTTP-to-HTTPS redirect itself and the HSTS header is what `force_ssl` adds behind `assume_ssl`
- ::V10:: `bin/kamal app exec --reuse 'test -f /rails/storage/redeploy-marker && test -f /rails/storage/production.sqlite3'` exits 0 after the second `bin/kamal deploy`, having been seen to exit 1 before the marker was written
- ::V11:: The second `bin/kamal deploy` exits 0

No gate here proves that `bin/kamal console` opens a usable console, which is the owner's to judge by opening it and reading a record. Nor does any gate see the deploy overlap itself: a few seconds with two Solid Queue supervisors leave no trace that a command could check afterwards.

## Open questions

- ::Q1:: **Does the shared VPS exist yet, and at what address and SSH user does Kamal reach it?** The recommendation is a non-root deploy user in the `docker` group, with Docker installed on the box ahead of `bin/kamal setup`, since Kamal installs Docker itself, through the `get.docker.com` script, only when it connects as root or as a user with passwordless `sudo`.
- ::Q2:: **Which host do email links use while both domains serve?** `default_url_options` takes one host, and `SignUp.redeem!` creates the group under the brand of the domain the confirmation link opens on, so one fixed host gives every sign-up that domain's group type. The recommendation is `chorifico.com` for this deploy, with links built from the requesting domain as a separate beta issue.
- ::Q3:: **Keep Kamal's gapless deploy, or add a `pre-app-boot` hook that stops the old container first?** The recommendation is to keep the gapless default with no hook: Solid Queue runs several supervisors against one database by design, and only the new container ever runs `db:prepare`. That claim gets checked against the `solid_queue` source before the step lands.
- ::Q4:: **Should the issue's first acceptance criterion read `RUBY_VERSION=4.0.9`?** It names 4.0.6, but `Dockerfile` and `.ruby-version` both carry 4.0.9, and the criterion is the owner's to edit.

## Settled

None yet.
