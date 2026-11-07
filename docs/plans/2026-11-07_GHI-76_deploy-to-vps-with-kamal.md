> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: deploy the application to a vps with kamal (#76)

## Approach

Kamal is already current: `Gemfile.lock` pins `kamal` 2.12.0, which is the newest release on RubyGems, so every command here runs through `bin/kamal` and nothing is bumped. Kamal builds the image on the developer machine by default, and that machine has no Docker yet, so a local Docker install is the first step and waits on the owner like every other install.

The application goes onto the shared VPS that will also host a sibling app. kamal-proxy runs once per host and routes by hostname, so a second app on the box is an ordinary Kamal setup rather than a special case. The image goes to ghcr.io under the repository owner's namespace, and `.kamal/secrets` gains `KAMAL_REGISTRY_PASSWORD` read from the environment, never from a committed file.

`config/deploy.yml` gets the real server, the ghcr.io registry and a `proxy` block with `ssl: true` and the application's hostnames. `chorifico.com` is the one registered domain per `app/models/brand.rb`, so it and `www.chorifico.com` are the proposed hosts until Open questions says otherwise. The stale `RUBY_VERSION: 3.4.7` in the commented builder args becomes 4.0.9, matching `Dockerfile` and `.ruby-version`.

`config/environments/production.rb` turns on `assume_ssl` and `force_ssl`, which `config/deploy.yml` states an SSL proxy requires, with `ssl_options` excluding `/up` so kamal-proxy's health check is not redirected to HTTPS. `config.hosts` admits `chorifico.com` and its subdomains, with `host_authorization` excluding `/up` for the same reason, and the mailer's `default_url_options` host moves off `example.com`.

## Deploy overlap

Kamal always boots the new container and health-checks it before it stops the old one, whether or not the role is proxied. For a few seconds per deploy, two Puma processes, each running Solid Queue in-process, therefore share the SQLite files on the `groupifico_storage` volume, and the new container runs `bin/rails db:prepare` from `bin/docker-entrypoint` while the old one still serves. SQLite is built for several processes on one file, so this is not a corruption case. The two costs are a second Solid Queue supervisor polling the same queue and an old process serving against a schema the new one may just have migrated. The alternative is a `pre-app-boot` hook that stops the old container first, which trades the gapless deploy for a few seconds of downtime on every deploy. Open questions carries the choice.

## Steps

- Owner step: install Docker on the developer machine and start its daemon, chosen through the machine's package-management procedure, since an install is never run by an agent
- Owner step: name the VPS address and the SSH user Kamal connects as, and confirm the box is x86, since `builder.arch` is `amd64`
- Owner step: point the DNS A records of `chorifico.com` and `www.chorifico.com` at the VPS
- Owner step: create a GitHub token with `write:packages` and export it as `KAMAL_REGISTRY_PASSWORD` in the shell that runs Kamal
- Build the image locally with `docker build -t groupifico .` against the `RUBY_VERSION=4.0.9` that `Dockerfile` already carries
- Fill in `config/deploy.yml`: `servers.web`, `image`, the ghcr.io `registry` with its username and password secret, the `proxy` block with `ssl: true` and both hosts, and `RUBY_VERSION: 4.0.9` in the commented builder args
- Add `KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD` to `.kamal/secrets`
- In `config/environments/production.rb`, turn on `assume_ssl`, `force_ssl` and the `/up` exclusion in `ssl_options`, set `config.hosts` and the `/up` exclusion in `host_authorization`, and set the mailer host to `chorifico.com`
- Apply the overlap decision from Open questions: either no hook, or a `pre-app-boot` hook in `.kamal/hooks/` that stops the old container
- Run `bin/kamal setup` against the VPS from a clean checkout
- Write a marker file into `/rails/storage` on the running container, deploy a trivial change with `bin/kamal deploy`, and read the marker and the production database back
- Tick each of the issue's acceptance criteria as its gate passes

## Verification

- `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-07_GHI-76_deploy-to-vps-with-kamal.md` exits 0
- `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-07_GHI-76_deploy-to-vps-with-kamal.md` exits 0
- `docker build -t groupifico .` exits 0
- `bin/kamal config` exits 0
- `grep -nE '^[^#]*(192\.168\.0\.1|localhost:5555|example\.com)' config/deploy.yml config/environments/production.rb` finds nothing, having been seen to find all three placeholders against `main`
- `bin/ci` passes, browser suite included
- `bin/kamal setup` exits 0
- `curl -fsS https://chorifico.com/up` exits 0, which fails on an invalid or self-signed certificate
- `curl -fsSI http://chorifico.com/` answers with a redirect to `https://`, proving `force_ssl` is on behind the proxy
- `bin/kamal app exec --reuse 'test -f /rails/storage/redeploy-marker && test -f /rails/storage/production.sqlite3'` exits 0 after the second `bin/kamal deploy`, having been seen to exit 1 before the marker was written
- The second `bin/kamal deploy` exits 0

No gate here proves that `bin/kamal console` opens a usable console, which is the owner's to judge by opening it and reading a record. Nor does any gate see the deploy overlap itself: a few seconds with two Solid Queue supervisors leave no trace that a command could check afterwards.

## Open questions

- **Does the shared VPS exist yet, and at what address and SSH user does Kamal reach it?** The recommendation is a non-root deploy user in the `docker` group, with Docker installed on the box ahead of `bin/kamal setup`, since Kamal installs Docker itself only when it connects as root.
- **Are `chorifico.com` and `www.chorifico.com` the hostnames, with `chorifico.com` as the mailer host?** The recommendation is yes, since it is the only registered domain and `groupifico.com` is not.
- **Keep Kamal's gapless deploy, or add a `pre-app-boot` hook that stops the old container first?** The recommendation is to keep the gapless default with no hook: Solid Queue runs several supervisors against one database by design, and only the new container ever runs `db:prepare`. That claim gets checked against the `solid_queue` source before the step lands.
- **Should the issue's first acceptance criterion read `RUBY_VERSION=4.0.9`?** It names 4.0.6, but `Dockerfile` and `.ruby-version` both carry 4.0.9, and the criterion is the owner's to edit.

## Settled

None yet.
