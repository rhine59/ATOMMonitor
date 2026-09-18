# ATOM Monitor — Phase 2 SQLite Backup and Recovery

Checkpoint started: 17 September 2026

## Objective

Make the current SQLite station registry recoverable before the later PostgreSQL migration and API-replication work. Phase 2 does not change the API contract, collector behaviour or station-only product boundary.

The live Synology database is:

```text
/volume1/docker/ATOMMonitor/server/data/atommonitor.sqlite3
```

The default backup destination deliberately sits outside the Git checkout:

```text
/volume1/docker/ATOMMonitor-backups
```

Backups are operational data and must not be committed to Git.

## Backup utility

The repository contains:

```text
scripts/atom-db-backup.py
```

It uses Python's SQLite online backup API, so a consistent backup can be created while the API is running. Each backup is then opened read-only, checked with `PRAGMA integrity_check`, checked for the `stations` table, counted, and accompanied by a SHA-256 sidecar. Incomplete `.partial` files are removed on failure.

Default retention is the newest 14 backups. Override with `--keep N` or `ATOM_BACKUP_KEEP`. Retention deletes the corresponding checksum sidecar with each expired database backup.

## First controlled test

On the Synology:

```bash
cd /volume1/docker/ATOMMonitor
git pull origin main
python3 scripts/atom-db-backup.py backup
```

Expected result includes:

```text
Integrity: ok
Stations: ...; confirmed PilotAware: ...
SHA-256: ...
```

The command must return exit status 0.

Then verify the newest backup independently:

```bash
python3 scripts/atom-db-backup.py verify
```

Expected final line:

```text
Controlled restore verification: PASS
```

`verify` checks the SHA-256 sidecar, copies the backup into a temporary restore location, opens that restored copy, runs SQLite integrity checking and counts the station registry. It does not touch the live database.

## Explicit restore

A backup can be restored only to an explicit target. The utility refuses to overwrite an existing target unless `--force` is supplied.

For a non-production recovery rehearsal:

```bash
mkdir -p /tmp/atommonitor-recovery
python3 scripts/atom-db-backup.py restore \
  /volume1/docker/ATOMMonitor-backups/atommonitor-YYYYMMDDTHHMMSSZ.sqlite3 \
  --target /tmp/atommonitor-recovery/atommonitor.sqlite3
```

Inspecting this controlled copy proves recovery without risking the production registry.

For an actual live restore, first stop the Compose services and preserve the damaged/current database separately. Only then use `restore --force` against `server/data/atommonitor.sqlite3`, restart Compose, and verify `/ready` and `/api/v1/stations`. A live restore must not be performed merely as a test.

The restore utility treats SQLite `-wal`, `-shm` and `-journal` files as part of the database generation being replaced. Without `--force`, the presence of the target database **or any of those sidecars** blocks restore. During an explicitly forced restore, after the backup has passed checksum/integrity checks and the replacement temporary copy has passed integrity checking, stale target sidecars are removed before the replacement database is atomically moved into place. This is safe only while every process that can access the database is stopped; otherwise a live SQLite process could recreate or continue using sidecar state during replacement.

## Synology scheduling

After the first manual backup and restore verification pass, configure DSM Task Scheduler to run once daily as the normal repository owner (or another account with read access to the database and write access to the backup directory):

```bash
cd /volume1/docker/ATOMMonitor && /bin/python3 scripts/atom-db-backup.py backup >> /volume1/docker/ATOMMonitor-backups/backup.log 2>&1
```

The Synology Python path was confirmed as `/bin/python3` on 18 September 2026. The 02:00 BST scheduled run at 01:00:03Z and a manual DSM Task Scheduler run both completed with SQLite integrity `ok`, valid SHA-256 output and plausible station counts. Do not use `sudo` unless NAS permissions require it; Git operations remain non-root.

The backup directory itself should be included in the Synology/NAS backup policy so a NAS-volume failure does not destroy both the live database and its local backup copies.

## Phase 2 acceptance tests

Phase 2 is **Tested** only after all of the following are recorded:

1. Online backup succeeds against the live registry while the service remains available.
2. `PRAGMA integrity_check` reports `ok` for the generated backup.
3. SHA-256 verification passes.
4. Controlled restore verification passes.
5. Restored station counts are plausible and the confirmed PilotAware count agrees with the live `/ready` count at the backup checkpoint (allowing for observations received after the backup).
6. Retention is demonstrated safely, preferably against a temporary test backup directory rather than deleting production recovery points.
7. The backup directory is included in an appropriate NAS backup policy or that external-backup dependency is explicitly recorded as outstanding.
8. The scheduled daily backup is configured and one scheduled run is observed successfully.

## Recovery acceptance

A production recovery is considered viable when a verified backup can be restored to a controlled database copy and, in a deliberate maintenance/recovery event, the API can start against the restored registry with `/ready` reporting database `ok` and `/api/v1/stations` serving the expected station registry.

## Next architecture phase

After Phase 2 passes, Phase 3 is migration of persistent state from SQLite to PostgreSQL. PostgreSQL is the prerequisite for safely running multiple stateless API replicas behind a load balancer; API replication is not part of Phase 2.
