# Backup and restore

Litestream replicates the production database to Cloudflare R2 continuously, so losing the server loses at most the last few seconds of writes. It runs as the `litestream` Kamal accessory in `config/deploy.yml`, configured by `config/litestream.yml`, and every account-specific value comes from the Rails credentials under `litestream.*` through `.kamal/secrets`.

## What is backed up

Only `storage/production.sqlite3`, which holds the groups, members, events and registrations. The other production databases are left out on purpose: `production_cache.sqlite3` and `production_cable.sqlite3` rebuild themselves, and `production_queue.sqlite3` holds only jobs that have not run yet, so losing it loses at most a few unsent emails.

Files uploaded through Active Storage, such as feedback screenshots, are not backed up.

R2 holds a full snapshot of the database once a day and the changes between snapshots, and keeps both for 90 days. A restore can therefore rebuild the database as it was at any moment in the last 90 days, to within about 30 seconds.

## Checking it

- **The alert.** Litestream pings a healthchecks.io check every minute while replication works, idle hours included. If the pings stop for more than 6 minutes, healthchecks.io emails the owner.
- **The container.** `bin/kamal accessory details litestream` shows whether it is running, and `bin/kamal accessory logs litestream` shows what it last did.

## Restoring a copy onto your machine

This is the restore to use for checking a backup, and for recovering records deleted by mistake. It leaves production untouched and needs Docker, nothing else. Run it from the repository root, in a shell where `KAMAL_SERVER` is set, as for any `bin/kamal` command:

```sh
bin/kamal secrets print | grep '^LITESTREAM_' > tmp/litestream.env
mkdir -p tmp/restore
docker run --rm --env-file tmp/litestream.env -v $PWD/config/litestream.yml:/etc/litestream.yml:ro -v $PWD/tmp/restore:/restore litestream/litestream:0.5.18 restore -config /etc/litestream.yml -o /restore/production.sqlite3 /rails/storage/production.sqlite3
rm tmp/litestream.env
sqlite3 tmp/restore/production.sqlite3 'PRAGMA integrity_check'
```

The last command prints `ok` for a sound copy. `restore` refuses to overwrite an existing file, so delete `tmp/restore/production.sqlite3` before restoring again.

To rebuild the database as it was at an earlier moment, add `-timestamp` with a UTC time before `-o`, for example `-timestamp 2026-11-10T09:00:00Z`. Copy the records you need back into production through `bin/kamal console` rather than replacing the production database, which would lose every write since that moment.

## Restoring after the server is lost

The accessory runs Litestream with `-restore-if-db-not-exists`, so on a server whose storage volume is empty it restores the database from R2 before it starts replicating again.

1. Prepare the new server and point DNS at it as for the first deploy, and set `KAMAL_SERVER` to it.
2. Boot the accessory alone, so the database is back before the application creates an empty one:

   ```sh
   bin/kamal accessory boot litestream
   ```

3. Wait until `bin/kamal accessory logs litestream` reports the restore finished and replication started.
4. Deploy the application, which finds the restored database on the volume:

   ```sh
   bin/kamal setup
   ```

5. Sign in and check that the groups, members and events are there.

`bin/kamal setup` skips the accessory, since its container already exists.
