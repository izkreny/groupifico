> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Plan: back up the production data (#396)

## Approach

Litestream 0.5.18, the newest release, runs as a Kamal accessory named `litestream` beside the application on the same server, and replicates `storage/production.sqlite3` to a Cloudflare R2 bucket used for nothing else. The accessory takes the `web` role's hosts through `roles:`, so the server's name still comes only from `KAMAL_SERVER`. It mounts the `groupifico_storage` volume at `/rails/storage`, the same path the application sees, and reads its configuration from `config/litestream.yml` (new), which Kamal uploads through `files:`. In Kamal 2.12.0, `kamal deploy` boots accessories only when `kamal setup` calls it, so a redeploy leaves a running accessory alone, and Kamal starts an accessory with `--restart unless-stopped`, so replication outlives redeploys and reboots without anyone restarting it.

The image is `litestream/litestream:0.5.18`, the Debian variant rather than `-scratch`, because it carries the `sqlite3` CLI that the integrity check and the restore steps use. That variant runs as root, and a root-owned `-wal` or `-shm` file, or Litestream's own state beside the database, would be unwritable for the application, which runs as `1000:1000` per the `Dockerfile`. The accessory therefore runs with `options: user: "1000:1000"`.

`config/litestream.yml` (new) commits no account id, bucket, key or host. Litestream expands `${VAR}` in its configuration, so the R2 endpoint, the bucket and both keys arrive as environment variables from `accessories/litestream/env/secret`. `.kamal/secrets` fetches them from the encrypted Rails credentials under `litestream.*`, as it already fetches `kamal.registry_password`. The replica uses `type: s3`, `region: auto` and `endpoint: ${LITESTREAM_R2_ACCOUNT_ID}.r2.cloudflarestorage.com`, written without a scheme as Litestream's S3-compatible guide writes it, which assumes HTTPS. Only `production.sqlite3` is listed, per N2 on the issue.

Snapshot retention and the failure alert are configuration. Q1 and Q2 below decide their values. The alert is Litestream's `heartbeat-url`, which pings a dead-man's-switch service only while every database has synced within `heartbeat-interval`, so the service emails the owner when the pings stop, whether the container died, the server died or R2 refused the writes.

`docs/BACKUP.md` (new) holds what the owner needs on a bad day: what is backed up and what is not, how to read replication's state, and two restores, onto a new server after the old one is lost and to a point in time on the running one. The restore that proves AC3 and AC4 follows that file to the letter, on the developer machine through Docker, which #76 already installed, so no Litestream binary is installed anywhere. The update round's inventory in `.agents/dependencies.md` gains an entry for the image tag, because Dependabot watches no `config/deploy.yml` and nothing else would notice a new Litestream release.

## Weighed against it

A nightly `sqlite3 .backup` pushed to object storage is the simpler tool, but it loses up to a day of writes and needs a scheduler that outlives the application. A job in Solid Queue's `config/recurring.yml` is that scheduler only on paper, since it stops when the application does, which is the failure a backup has to outlast. rclone to Google Drive's hidden app-data folder was dropped because an unattended OAuth token there needs either rclone's shared client or a published Google OAuth app. R2 wins the destination on its free tier of 10 GB-month with free egress, and on API tokens scoped to named buckets, which keeps this backup and the attachments of #417 out of each other's reach.

## Steps

- ::S1:: Owner step: open a Cloudflare account, create an R2 bucket for backups alone, and create an R2 API token with the Object Read & Write permission scoped to that bucket alone
- ::S2:: Owner step: create the heartbeat check in the service Q1 settles, with an alert to the owner's email
- ::S3:: Owner step: store the account id, the bucket name, the token's access key id and secret, and the heartbeat URL with `bin/rails credentials:edit` under `litestream.r2_account_id`, `litestream.bucket`, `litestream.access_key_id`, `litestream.secret_access_key` and `litestream.heartbeat_url`
- ::S4:: Write `config/litestream.yml` (new): the `production.sqlite3` database, its R2 replica, the snapshot `interval` and `retention` Q2 settles, and `heartbeat-url` with `heartbeat-interval`
- ::S5:: Add the `litestream` accessory to `config/deploy.yml`, replacing the commented generator example, with the image, `roles: [web]`, `cmd: replicate -config /etc/litestream.yml`, a `files:` entry mounting `config/litestream.yml` (new) where that `-config` points, the `groupifico_storage` volume, `options: user: "1000:1000"` and the five secrets
- ::S6:: Add the five `LITESTREAM_*` lines to `.kamal/secrets`, each fetched with `bin/rails credentials:fetch`
- ::S7:: Write `docs/BACKUP.md` (new) with the backup's scope, how to check it, and both restores
- ::S8:: Add the Litestream image to the inventory in `.agents/dependencies.md`, compared with `gh release view --repo benbjohnson/litestream --json tagName --jq .tagName`
- ::S9:: Boot the accessory with `bin/kamal accessory boot litestream` and read its log for the first snapshot reaching R2
- ::S10:: Owner step: sign in on production once after a `bin/kamal deploy`, so the replica must carry a `Session` row written after the redeploy
- ::S11:: Restore onto the developer machine by following `docs/BACKUP.md` (new), and run V7 to V9 against the copy
- ::S12:: Stop the accessory with `bin/kamal accessory stop litestream`, wait past the heartbeat's grace period for the owner's alert, then boot it again
- ::S13:: Tick each of the issue's acceptance criteria as its gate passes

## Verification

- ::V1:: `python3 <skill-dir>/scripts/plan-check.py docs/plans/2026-11-10_GHI-396_back-up-the-production-data.md` exits 0
- ::V2:: `python3 <skill-dir>/scripts/docs-check.py --root . --plans docs/plans docs/plans/2026-11-10_GHI-396_back-up-the-production-data.md docs/BACKUP.md` exits 0
- ::V3:: `bin/kamal config | grep -q litestream/litestream:0.5.18` exits 0, having been seen to exit 1 against `main`
- ::V4:: `git grep --untracked -nE 'r2\.cloudflarestorage\.com/|[0-9a-f]{32}|hc-ping\.com/' -- config/deploy.yml config/litestream.yml .kamal/secrets docs/BACKUP.md` exits 1, having been seen to exit 0 with a literal 32-hex account id planted in `config/litestream.yml` (new)
- ::V5:: `bin/rails credentials:fetch litestream.<key>` exits 0 for each of the five keys S3 names, having been seen to exit 1 with "Invalid or missing credential path" before S3
- ::V6:: The `docs/BACKUP.md` (new) restore, then `test -s tmp/restore/production.sqlite3`, exits 0, having been seen to exit non-zero before S9 put a replica in R2
- ::V7:: `test "$(sqlite3 tmp/restore/production.sqlite3 'PRAGMA integrity_check')" = ok` exits 0, having been seen to exit 1 on a copy truncated with `head -c 65536`
- ::V8:: `bin/rails runner` in the production image against the restored copy exits 0 on `exit(Member.count == m && Event.count == e && Session.maximum(:created_at) > t)`, with `m` and `e` read from production through `bin/kamal app exec --reuse` and `t` the S10 redeploy time, having been seen to exit 1 with `m` off by one
- ::V9:: `bin/ci` passes, browser suite included

AC7 is proven by the owner, who judges whether the heartbeat service's alert reaches their inbox after S12 and stops when the accessory is back. AC6's first half is proven the same way: the owner reads the token's bucket scope off Cloudflare's token page, since no other bucket exists yet to be refused. No gate proves the retention rule prunes anything, since the first snapshot older than the window appears only after the window has passed, nor measures the seconds of data a lost server would cost.

## Open questions

- ::Q1:: **Which dead-man's-switch service receives the heartbeat?** Recommended: healthchecks.io, whose free Hobbyist plan monitors 20 checks; S2 confirms it alerts by email before relying on it.
- ::Q2:: **How long are restore points kept?** Litestream's default `retention` is `24h`, so a deletion noticed the next day could no longer be undone. Recommended: a daily snapshot kept for 30 days, `interval: 24h` and `retention: 720h`, well inside R2's free 10 GB-month for a database this small.

## Settled

None yet.
