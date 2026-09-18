# ATOM Monitor — Phase 3 PostgreSQL Migration

Checkpoint started: 18 September 2026

## Objective

Move the current Synology development/test station registry from SQLite to PostgreSQL so persistent state can later be shared safely by multiple stateless API replicas. This phase does not introduce API replicas, a load balancer or collector high availability, and it does not change ATOM Monitor's station-only product boundary.

## Starting point

The development/test stack currently consists of one Gunicorn/Flask API container, one single-active OGN station collector and the SQLite registry at `server/data/atommonitor.sqlite3`. Phase 2 backups remain the rollback source. This deployment is not a production service, so Phase 3 favours a controlled stop/migrate/test sequence rather than zero-downtime complexity.

## Target for this phase

```text
OGN station-status feed
        |
        v
single-active collector
        |
        v
Gunicorn / Flask API
        |
        v
PostgreSQL
        |
        v
persistent Docker volume
```

The public HTTPS and LAN API routes remain unchanged. Phone clients must not need a database-specific change.

## Implementation sequence

1. Add a PostgreSQL Compose service with a persistent named volume, private Compose-network access and a database healthcheck. Database credentials remain in ignored local environment configuration and are never committed.
2. Introduce a database abstraction in the server so API behaviour and station JSON remain independent of SQLite/PostgreSQL syntax.
3. Define the PostgreSQL `stations` schema with the same logical fields and primary key as the existing registry.
4. Add an explicit migration utility that reads the verified SQLite registry and writes PostgreSQL rows without deleting or modifying the SQLite source.
5. Compare source and destination total station counts and confirmed PilotAware counts.
6. Switch the development/test API to PostgreSQL and exercise `/health`, `/ready`, authenticated observation ingestion, stale/future ordering and station read endpoints.
7. Restart/recreate the stack and prove PostgreSQL persistence.
8. Retain the SQLite source/backups until the PostgreSQL checkpoint is accepted.

## Configuration

The intended server configuration uses a database URL supplied through the local ignored `server/.env`, for example a PostgreSQL URL assembled from local credentials. No password, ingest token or SMTP credential is committed to Git.

PostgreSQL is not published to an Internet-facing host port. The API reaches it over the private Compose network. Administrative access, if temporarily required during migration/testing, should be through `docker compose exec` rather than a permanently exposed database port.

## Migration and rollback

Migration is one-way for the test: SQLite is the preserved source and PostgreSQL is the new destination. The migration utility must be repeatable/upsert-safe so a failed test can be cleared/re-run deliberately.

Before switching the API, verify the latest SQLite backup. During the backend switch the development/test services may be stopped. After copying, record SQLite and PostgreSQL station counts. A mismatch blocks the switch.

Rollback does not copy PostgreSQL back into SQLite. Stop the PostgreSQL-backed stack, restore the previous SQLite API configuration, and restart against the untouched SQLite registry. Keep PostgreSQL data for diagnosis unless there is a specific reason to reset it.

## Acceptance

Phase 3 is **Tested** only after the PostgreSQL service is healthy; schema creation succeeds; SQLite-to-PostgreSQL migration counts agree; `/ready` reports database `ok`; expected station reads work; authenticated collector writes work; stale/future observation protection still passes; container restart/recreation preserves station state; and rollback to the preserved SQLite checkpoint has either been rehearsed or its exact tested configuration boundary is recorded.

### Acceptance result — 18 September 2026

**PASS / Tested.** The Synology development/test API is cut over to PostgreSQL. `/ready` reported `database=ok`, `databaseBackend=postgresql` and 307 confirmed stations; live collector writes returned HTTP 202 and were committed to PostgreSQL; unauthenticated ingestion remained HTTP 401; station-list and detail reads returned HTTP 200; stale observations did not overwrite newer state; implausibly future observations were rejected with HTTP 400; PostgreSQL restart and forced container recreation preserved state (309 rows before and after recreation); and the API/collector recovered automatically. The preserved rollback boundary is `server/data/atommonitor.sqlite3`; on 18 September it remained present (104K) and a read-only `PRAGMA integrity_check` returned `ok`. Rollback therefore remains the documented configuration switch back to SQLite using this preserved database; a disruptive live rollback rehearsal was not required for this development/test checkpoint.

## What follows

After Phase 3 passes, the API can be made stateless and replicated behind a load balancer because all replicas can use the same PostgreSQL database. That is the next architecture phase, not part of this migration.
\n\n## Checkpoint synchronization — 18 September 2026\n\nPostgreSQL is the active registry and Phase 3 is Tested. The full cross-phase run reconfirmed the named-volume mount, PostgreSQL readiness/population, preserved SQLite rollback boundary, persistence across PostgreSQL restart and API recovery. PostgreSQL backup/restore remains a separate outstanding operational requirement. See `CHECKPOINT-2026-09-18.md`.\n