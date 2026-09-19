# ATOM Monitor — Checkpoint — 18 September 2026

## Scope invariant

ATOM Monitor remains a ground-station operational-health product only. It does not display, record or retain aircraft movements, tracks, aircraft identities or aircraft packet history.

## Server architecture at checkpoint

The active Synology development/test stack is PostgreSQL plus two stateless Gunicorn/Flask API replicas behind Nginx, with one single-active OGN/APRS station-only collector. Nginx alone publishes host port 8088. PostgreSQL and the API replicas remain private to the Compose network. The collector submits authenticated station observations through Nginx. Public HTTPS remains DSM Reverse Proxy at `https://granvillehouse.synology.me:8445/`.

PostgreSQL is the active station registry in the named Docker volume `server_atommonitor-postgres-data`. The preserved SQLite file is a rollback/historical boundary, not the live database.

## Phase status

Phase 1 base service/resilience checks: Tested.

Phase 2 SQLite backup/recovery tooling: Tested for preserved-database integrity, temporary backup, checksum verification, retention and controlled restore. The old SQLite backup path is now historical because PostgreSQL is live. PostgreSQL backup/restore remains a separate operational requirement.

Phase 3 PostgreSQL migration: Tested. The full acceptance run proved the named-volume mount, PostgreSQL-backed readiness, populated registry, reads/authentication, preserved SQLite rollback boundary, PostgreSQL restart persistence and API recovery.

Phase 4 API replication/load balancing: runtime acceptance passed. Two API replicas, Nginx routing, loss and rejoin of either replica, API recreation, Nginx recreation, collector HTTP 202 traffic through Nginx, authentication boundary and final recovery were exercised successfully.

## Full acceptance checkpoint

`scripts/all-phases-acceptance.sh` passed end-to-end on the Synology. The final current-stack service/API matrix also passed:

- Nginx `/health`, `/ready`, station list, station detail and missing-station 404;
- safe invalid-feedback HTTP 400 and unauthenticated observation HTTP 401;
- PostgreSQL confirmed-PilotAware count matching the API (308 at the checkpoint);
- direct `/health`, `/ready` and station-list checks on both API replicas;
- a new live collector station-only observation returning HTTP 202 through Nginx.

The Phase 3 persistence checkpoint observed 310 total PostgreSQL station rows. Counts are evidence at a point in time, not hard-coded expectations.

## Acceptance framework

Committed runners now include `phase1-acceptance.sh`, `phase2-acceptance.sh`, `phase3-acceptance.sh`, `phase4-acceptance.sh`, `service-api-acceptance.sh` and `all-phases-acceptance.sh`, with shared helpers under `scripts/lib`. The cross-phase framework is Tested.

## Rebuild/documentation rule

Every infrastructure, deployment, database, networking, secret/configuration, build or runtime change must update the clean-rebuild documentation in the same development cycle. The authoritative Synology rebuild procedure is `docs/SYNOLOGY-HOSTING-RUNBOOK.md`; `docs/SETUP.md` and the phase/architecture documents must remain consistent with it.

## Phone clients

The iOS application has completed its current simulator checkpoint. Android work is paused at the current parity checkpoint; the Home-station picker scrolling defect remains open. Functional phone changes continue to require iOS/Android parity in the same cycle unless a platform-specific reason is documented.

A future phone feature remains queued: Station Detail should allow adding/removing a Favourite and immediately reflect the persisted favourite state elsewhere on both platforms.

## Outstanding server work

The major operational gap is PostgreSQL backup/restore and its NAS/external backup policy. Phase 4 close-out documentation should also retain the exact single-API rollback procedure. Multiple API replicas on one Synology improve process/container resilience only; they do not provide NAS, router, broadband, power or site high availability. The collector remains deliberately single-active.

No Phase 5 acceptance contract has yet been defined. It must not be invented retrospectively; define its objective and acceptance criteria before implementation.


## 19 September 2026 follow-on

Per-container build/start verification scripts have been added for PostgreSQL, API replicas, Nginx and the OGN station collector, plus an all-container dependency-ordered wrapper. They deliberately preserve the PostgreSQL named volume and keep resilience/failure testing separate in the Phase acceptance suite. Runtime verification of these new build scripts is pending.
