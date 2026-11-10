> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: deploy the application to a vps with kamal (#76)

## Approach

Kamal is already current: `Gemfile.lock` pins `kamal` 2.12.0, which is the newest release on RubyGems, so every command here runs through `bin/kamal` and nothing is bumped. Kamal builds the image on the developer machine by default, and that machine has no Docker yet, so a local Docker install is the first step and waits on the owner like every other install.

The application goes onto the shared VPS that will also host a sibling app. kamal-proxy runs once per host and routes by hostname, so a second app on the box is an ordinary Kamal setup rather than a special case. The image goes to ghcr.io under the repository owner's namespace, and `.kamal/secrets` gains `KAMAL_REGISTRY_PASSWORD` read from the encrypted Rails credentials, never written in the clear.

`config/deploy.yml` reads the server from `KAMAL_SERVER` in the environment, since SSH reaches the VPS only over a private network, and gets the ghcr.io registry and a `proxy` block with `ssl: true` and the application's hostnames. The owner holds both `chorifico.com` and `groupifico.com` and wants both serving from the first deploy, so the hosts are those two and their `www` subdomains, and kamal-proxy obtains a Let's Encrypt certificate for each. The commented builder `args:` example, which carries a stale `RUBY_VERSION: 3.4.7`, is deleted rather than bumped, so the `Dockerfile`'s `ARG RUBY_VERSION` stays the one build-time copy beside `.ruby-version`, the pair `.agents/dependencies.md` moves together.

`config/environments/production.rb` turns on `assume_ssl` and `force_ssl`, which `config/deploy.yml` states an SSL proxy requires. `assume_ssl` marks every request as HTTPS, so `force_ssl` never redirects and `ssl_options` needs no `/up` exclusion. `config.hosts` admits both domains and their subdomains, with `host_authorization` excluding `/up` as the generated comment on that line recommends for the health check endpoint, and the mailer's `default_url_options` host moves off `example.com` to `chorifico.com`, per Q2 in `## Settled`.

## Deploy overlap

Kamal always boots the new container and health-checks it before it stops the old one, whether or not the role is proxied. For a few seconds per deploy, two Puma processes, each running Solid Queue in-process, therefore share the SQLite files on the `groupifico_storage` volume, and the new container runs `bin/rails db:prepare` from `bin/docker-entrypoint` while the old one still serves. SQLite is built for several processes on one file, so this is not a corruption case. The two costs are a second Solid Queue supervisor polling the same queue and an old process serving against a schema the new one may just have migrated. The alternative is a `pre-app-boot` hook that stops the old container first, which trades the gapless deploy for a few seconds of downtime on every deploy. Q3 in `## Settled` keeps the gapless default.

Both halves were checked on 2026-11-08 rather than recalled. Kamal 2.12.0's `Kamal::Cli::App::Boot#run` calls `start_new_version` before `stop_old_version` with no branch on whether the role is proxied, and `Kamal::Cli::App#boot` runs the `pre-app-boot` hook immediately before that boot. The Solid Queue 1.7.2 README supports several supervisors on one database ("run `bin/jobs` on multiple machines at the same time"), and warns that without `FOR UPDATE SKIP LOCKED`, which SQLite lacks, "you might run into lock waits if you run multiple workers for the same queue", which a few seconds of overlap can afford.

## Steps

- ::S1:: Owner step: install rootless Docker on the developer machine and start its daemon, since `docker` group membership grants root-level privileges
- ::S2:: Owner step: export as `KAMAL_SERVER`, in a shell on the owner's private network, an SSH host whose client config offers the `kamal` key, since Kamal loads `~/.ssh/config` by default and passes no key of its own
- ::S3:: Owner step: point the DNS A and AAAA records of `chorifico.com`, `www.chorifico.com`, `groupifico.com` and `www.groupifico.com` at the VPS
- ::S4:: Owner step: create a classic GitHub token with `write:packages` alone, through `https://github.com/settings/tokens/new?scopes=write:packages` since the plain form also ticks `repo`, and store it with `bin/rails credentials:edit` as `kamal.registry_password`
- ::S5:: Build the image locally with `docker build -t groupifico .` against the `RUBY_VERSION=4.0.9` that `Dockerfile` already carries
- ::S6:: Fill in `config/deploy.yml`: `servers.web` as `<%= ENV.fetch("KAMAL_SERVER") %>`, `ssh.user` as `kamal`, `image`, the ghcr.io `registry` with its username and password secret, the `proxy` block with `ssl: true` and all four hosts, and the deletion of the commented builder `args:` example with its `RUBY_VERSION: 3.4.7`, rewording the comment above the kept `secrets:` example to "Pass secrets to the Docker build process"
- ::S7:: Add `KAMAL_REGISTRY_PASSWORD=$(bin/rails credentials:fetch kamal.registry_password)` to `.kamal/secrets`
- ::S8:: In `config/environments/production.rb`, turn on `assume_ssl` and `force_ssl`, set `config.hosts` for both domains and the `/up` exclusion in `host_authorization`, and set the mailer host to `chorifico.com`
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

- ::Q4:: **Should the issue's first acceptance criterion read `RUBY_VERSION=4.0.9`?** It names 4.0.6, but `Dockerfile` and `.ruby-version` both carry 4.0.9, and the criterion is the owner's to edit.

## Settled

- ::Q2:: **Which host do email links use while both domains serve?** `default_url_options` takes one host, and `SignUp.redeem!` creates the group under the brand of the domain the confirmation link opens on, so one fixed host gives every sign-up that domain's group type. The owner settled it in the session on 2026-11-09: `chorifico.com` for the start, with links built from the requesting domain as backlog issue #414.
- ::Q1:: **Does the shared VPS exist yet, and at what address and SSH user does Kamal reach it?** Kamal connects as a non-root `kamal` user in the `docker` group, with Docker preinstalled, and `builder.arch` stays `amd64`. SSH reaches it only over the owner's private network, so `servers.web` comes from `KAMAL_SERVER` rather than a committed address, and the machine running `bin/kamal` must be on that network. DNS stays with Porkbun for the start, its A and AAAA records on the public address where Let's Encrypt and visitors arrive, settled by the owner in the session on 2026-11-10.
- ::Q3:: **Keep Kamal's gapless deploy, or add a `pre-app-boot` hook that stops the old container first?** Keep the gapless default with no hook, settled by the owner in the session on 2026-11-10.
- ::Q6:: **Where does the registry token live?** In the encrypted Rails credentials as `kamal.registry_password`, fetched by `.kamal/secrets`, so nobody exports it per shell. GitHub Packages accepts only a classic token, and one with `write:packages` alone can touch container images and nothing else, which bounds what the deployed app could do with it. Settled by the owner in the session on 2026-11-10.
