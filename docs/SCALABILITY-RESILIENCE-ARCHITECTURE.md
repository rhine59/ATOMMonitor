# ATOM Monitor — Synology Scalability & Resilience Architecture

Status: planned architecture
Date: 16 September 2026

This document defines the target architecture and technical implementation plan for making the Docker-hosted ATOM Monitor service on the Synology NAS more scalable, recoverable and resilient. It supplements `SYNOLOGY-HOSTING-RUNBOOK.md` and `IMPROVEMENT-ROADMAP.md`.

## 1. Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. The scalability work must not introduce storage, processing or exposure of aircraft identities, positions, tracks or movement history.

## 2. Current architecture

The current production service is deliberately simple:

```text
OGN/APRS receiver/status feed
        |
        v
atommonitor-ogn-probe
        |
        v
atommonitor-api
        |
        +--> SQLite /data/atommonitor.sqlite3
        |
Synology host :8088
        |
DSM Reverse Proxy :8445 HTTPS
        |
ATOM Monitor clients
```

Strengths of the current design are simplicity, persistent storage, Docker restart policy, DSM TLS termination and a tested public endpoint. Its main resilience limitations are a single API container, a single SQLite database, one NAS host, host-local persistent state, limited health semantics and no load-balancing/failover layer between DSM and multiple API instances.

## 3. Design objectives

The target architecture should provide:

- disposable/stateless API containers;
- automatic container restart and meaningful health checking;
- preservation of service during failure/replacement of one API replica;
- persistent data outside application containers;
- safe concurrent access from multiple API replicas;
- deterministic database backup, integrity checking and tested restoration;
- controlled public/private API separation;
- structured logging and operational metrics;
- repeatable deployment and rollback;
- capacity to add API/worker replicas without redesigning the application;
- graceful degradation where practical;
- no unnecessary Kubernetes/orchestration complexity on the current single Synology host.

This improves service-level resilience but does **not** make the Synology itself highly available. The NAS, DSM reverse proxy, router/Internet connection and site power remain shared failure domains. True host-level HA requires a second independent host/site or external service.

## 4. Target single-Synology topology

```text
                         INTERNET
                            |
                     HTTPS TCP 8445
                            |
                   DSM Reverse Proxy
                            |
                    internal API port
                            |
                 +----------+----------+
                 |                     |
          atom-api replica 1     atom-api replica 2
                 |                     |
                 +----------+----------+
                            |
                       PostgreSQL
                            |
                     persistent volume
                            |
                   backup + integrity
                            |
                    off-NAS backup copy

OGN/APRS receiver/status feed
            |
     atommonitor-ogn-probe
            |
      private Docker network
            |
     authenticated/private ingestion
            |
          API/database

Monitoring/operations:
health endpoints + Docker healthchecks + structured logs + external availability check
```

The API should become stateless. PostgreSQL becomes the authoritative persistent station registry. The collector remains a separate process and should communicate only over a private Docker network or an authenticated ingestion route.

### 4.1 Runtime naming invariant

The Compose project name is `atommonitor`, the lowercase Git repository name. Every runtime container must therefore begin with `atommonitor-`. Singleton services retain concise explicit names, while scalable API replicas use Compose-generated names such as `atommonitor-atom-api-1` and `atommonitor-atom-api-2`; assigning a fixed `container_name` to the API would prevent scaling.

The Compose project name is independent of persistent storage identity. The existing Docker volume names remain explicitly pinned as `server_atommonitor-postgres-data`, `server_atommonitor-admin-audit`, and `server_atommonitor-admin-devices`, so renaming/recreating containers cannot silently select empty replacement storage. Admin monitoring and scaling filter Docker resources by the new `atommonitor` Compose project label.

## 5. Phase 1 — harden the existing Compose deployment

Do this before database migration or replication.

### 5.1 Add meaningful health endpoints

`GET /health` should remain cheap and suitable for frequent probing. It should confirm the process is serving requests. Add a deeper readiness check, for example `GET /ready`, that confirms required dependencies such as the database are accessible.

Suggested semantics:

```json
{
  "status": "healthy",
  "service": "atommonitor-api",
  "version": "<release-or-git-sha>",
  "database": "healthy"
}
```

Do not expose secrets, filesystem paths or sensitive configuration.

### 5.2 Add Docker healthchecks

Add Compose healthchecks for the API and, where meaningful, the collector. Example pattern:

```yaml
healthcheck:
  test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 20s
restart: unless-stopped
```

If the application image does not contain `curl`, use a small Python/stdlib health command or deliberately add an appropriate healthcheck utility rather than relying on an unavailable binary.

### 5.3 Graceful shutdown

Ensure the API handles SIGTERM correctly: stop accepting new work, allow active requests to complete within a bounded grace period, close database connections and exit cleanly. The collector should likewise close network connections and stop ingestion cleanly.

### 5.4 Resource limits

Define sensible memory/CPU limits or reservations supported by the Synology Compose environment. Avoid allowing one faulty container to consume all NAS memory. Establish limits from observed steady-state and peak usage rather than arbitrary small values.

### 5.5 Logging

Write application logs to stdout/stderr rather than files inside containers. Use consistent timestamps, severity and service identity. Configure Docker log rotation so logs cannot exhaust the Synology volume.

Log operational events such as startup/version, database connection failure, collector connection state, rejected ingestion, migration execution and graceful shutdown. Do not log aircraft traffic or secrets.

## 6. Phase 2 — make the API stateless

Horizontal scaling requires any API replica to serve any request.

Remove authoritative mutable state from the API container filesystem. Runtime configuration should come from environment variables/secrets. Persistent station state belongs in the database. Temporary files should be disposable.

No client session, cache or local file should be required for another replica to continue serving requests after one replica disappears.

## 7. Phase 3 — migrate SQLite to PostgreSQL

SQLite is appropriate for the current single-instance service but is not the preferred authoritative store for multiple concurrently writing API replicas.

Introduce a PostgreSQL Compose service on the private backend network and persistent Synology storage. Use a database URL/environment configuration so development/test can remain independently configurable.

Migration actions:

1. Define the PostgreSQL schema corresponding to the existing station registry and observation timestamps.
2. Introduce explicit schema migrations (for example Alembic if the server uses SQLAlchemy, or the equivalent for the actual data layer).
3. Add unique keys/constraints needed for idempotent observation processing.
4. Implement timestamp precedence so stale observations cannot overwrite newer category-specific telemetry.
5. Build an export/import migration utility from the current SQLite registry.
6. Take and integrity-check a final SQLite backup.
7. Stop writes briefly for cutover.
8. Import into PostgreSQL and validate station counts/representative records.
9. Start the PostgreSQL-backed API.
10. Run local and public regression tests before removing the old SQLite path from active use.

Keep the original SQLite backup for rollback until the PostgreSQL deployment has passed an agreed stability period.

## 8. Database resilience and backup

The database volume must be persistent but persistence alone is not backup.

Implement:

- scheduled PostgreSQL logical dumps using `pg_dump`;
- timestamped backup names;
- retention/rotation policy;
- backup validation and failure logging;
- periodic restore into a disposable test database;
- Synology backup of database backups/configuration;
- an additional copy outside the NAS/failure domain.

Document Recovery Point Objective (RPO) and Recovery Time Objective (RTO) after observing actual data volume and restore duration. Do not claim an RPO/RTO until the backup/restore process has been measured.

## 9. Phase 4 — separate public read and private write paths

The collector's observation-ingestion endpoint must not be an unrestricted public write API.

Preferred order:

1. Keep collector ingestion on a Docker-private network and expose only public read endpoints through DSM Reverse Proxy.
2. If ingestion must cross a public/network boundary, require authentication/authorization and rate limiting.
3. Validate request schema, size and timestamps server-side.
4. Reject malformed, unauthorised and stale writes without altering current good state.

Port `8088` remains a LAN/diagnostic port and must not be forwarded from the Internet.

## 10. Phase 5 — API replication and load balancing

Only replicate the API after it is stateless and PostgreSQL-backed.

Run at least two identical API instances from the same immutable/versioned image. They must share no container-local authoritative state.

A load-balancing layer must distribute requests only to healthy/ready replicas. DSM Reverse Proxy can remain the external TLS endpoint, but the implementation must verify whether the installed DSM reverse-proxy configuration can health-aware balance the required upstream replicas. If it cannot provide the desired behaviour, place a small internal reverse proxy/load balancer (for example nginx, HAProxy or Traefik) between DSM and the API replicas.

Target:

```text
DSM HTTPS :8445
       |
internal load balancer
   |             |
API #1         API #2
   \             /
      PostgreSQL
```

Do not publish each API replica directly to the Internet.

Acceptance test: while continuously requesting `/health` and `/api/v1/stations`, deliberately stop one API replica. Client requests should continue through the remaining healthy replica except for any in-flight request affected during removal.

## 11. Collector resilience

The collector should remain independently restartable from the API.

Required behaviour:

- reconnect with bounded exponential backoff after upstream/feed interruption;
- tolerate API/database temporary unavailability;
- avoid tight retry loops;
- make observation submission idempotent where possible;
- use source/category timestamps so replayed delayed data cannot regress station state;
- expose/log collector health without recording unrelated aircraft traffic.

A durable queue is not initially required. Add Redis/message-queue infrastructure only if measurements show that temporary downstream outages cause unacceptable loss or if background workloads grow substantially. Avoid infrastructure that has no demonstrated need.

## 12. Idempotency and concurrency

Scaling creates retries and concurrent processing. Database rules must make duplicate/replayed observations safe.

Use appropriate unique identifiers/constraints and transactions. For each observation category, compare the incoming source timestamp with the stored timestamp and update only when equal/newer according to the documented precedence rule.

Concurrency tests must submit duplicates and deliberately out-of-order observations from parallel clients and verify that the final station record is deterministic.

## 13. Versioned immutable deployment

Production should identify exactly what code is running.

Build/tag images using a release version and/or Git commit SHA rather than relying only on `latest`. Surface the version in `/health` and startup logs.

Deployment procedure should become:

```text
Git commit -> tests -> image build -> version tag -> database migration -> deploy -> readiness -> public smoke test
```

Retain the immediately previous known-good image/tag so application rollback is straightforward. Database migrations must have an explicit rollback/recovery plan; application rollback alone is insufficient after an incompatible schema change.

## 14. Observability

Minimum production observability:

- Docker container health status;
- `/health` and `/ready` endpoints;
- structured application/collector logs;
- log rotation;
- container restart counts;
- database backup success/failure;
- disk-space monitoring;
- external HTTPS availability test against `https://granvillehouse.synology.me:8445/health`.

Later, if operational value justifies it, add metrics/dashboard tooling such as Prometheus/Grafana and centralized logs. Do not make a large monitoring stack a prerequisite for the first resilience improvements.

Alerts should focus on actionable conditions: public service unavailable, all API replicas unhealthy, database unavailable, backup failed, disk space low, collector disconnected beyond an expected interval, or repeated container restarts.

## 15. Synology-specific failure domains

Multiple containers on one NAS protect against application/container failure, not NAS failure.

Remaining single points of failure include:

- Synology hardware;
- DSM/Container Manager;
- PostgreSQL container/volume;
- DSM Reverse Proxy;
- NAS network interface/switch/router;
- broadband connection;
- site power.

The next resilience tier, only if justified, is a second independent Docker host with replicated/restorable data and DNS/proxy failover. Do not describe two containers on one Synology as full high availability.

## 16. Security actions accompanying scale-out

- keep backend/database networks private;
- expose only DSM HTTPS publicly;
- do not expose PostgreSQL, Redis (if later used), Docker socket or management interfaces;
- keep credentials out of Git;
- use least-privilege database credentials;
- patch DSM/Container Manager/base images;
- authenticate any write endpoint that cannot remain private;
- consider request/rate limits at the public boundary;
- validate backup access permissions because backups contain the authoritative registry.

## 17. Proposed Compose service layout

The eventual Compose project is expected to contain roles similar to:

```text
atom-api-1 / replicated atom-api service
atom-api-2
atom-db (PostgreSQL)
atommonitor-ogn-probe
atom-internal-proxy (only if required for replica balancing)
```

Use two networks conceptually:

```text
frontend: DSM/internal proxy <-> API
backend:  API/collector <-> PostgreSQL
```

The database belongs only on the backend network. The collector should not require public exposure.

Exact Compose syntax should be implemented and tested against the Synology Container Manager/Compose version in use rather than copied blindly from generic Docker examples.

## 18. Technical implementation sequence

Implement in this order:

1. Baseline current CPU, memory, request rate, DB size and restart behaviour.
2. Improve `/health`; add `/ready`.
3. Add Docker healthchecks and log rotation.
4. Verify SIGTERM/graceful shutdown.
5. Add resource safeguards based on measurements.
6. Harden public-read/private-ingestion separation.
7. Implement stale-observation protection and idempotency tests.
8. Introduce schema migration tooling.
9. Add PostgreSQL and persistent storage.
10. Build/test SQLite-to-PostgreSQL migration and rollback.
11. Automate PostgreSQL backup, retention, integrity and restore test.
12. Make API fully stateless.
13. Build versioned immutable API images.
14. Run two API replicas.
15. Introduce/verify health-aware internal load balancing.
16. Perform replica-failure testing under continuous requests.
17. Add external availability and backup-failure alerts.
18. Run NAS reboot/recovery test.
19. Document measured recovery times and remaining single points of failure.
20. Only then evaluate whether a second host is warranted.

## 19. Acceptance tests

The scalable/resilient milestone is complete when all of the following have been demonstrated:

- public HTTPS health and station APIs work normally;
- an API container can be deleted/recreated without data loss;
- one of two API replicas can be stopped while service continues through the other;
- API replicas share the same PostgreSQL-backed station state;
- delayed/duplicate observations cannot regress or duplicate authoritative state;
- collector restart does not damage station state;
- database survives API/container recreation;
- a scheduled backup can be restored successfully into a clean test database;
- a NAS/container-stack restart returns the service to an operational state without manual reconstruction;
- public clients cannot submit unauthorised observations;
- logs identify the running application version and meaningful failures;
- no aircraft identities/tracks/movement history are introduced by monitoring, logging or tests.

## 20. Rollback principle

Every production architecture change must have a rollback path before deployment. Preserve the previous Compose configuration/image tag and a verified pre-change database backup. For database cutovers, define the point after which rollback requires restoring data rather than merely restarting an old image.

## 21. What is deliberately not proposed yet

Kubernetes, Docker Swarm, Redis, a distributed message broker, PostgreSQL streaming replication and multi-site automatic failover are not current prerequisites. They add operational failure modes and maintenance cost. Introduce them only when measured load, recovery objectives or host-level availability requirements justify them.

The immediate target is a well-engineered resilient Compose deployment on the existing Synology: stateless replicated APIs, PostgreSQL persistence, health-aware routing, tested backup/recovery, private ingestion and observable/versioned operations.\n\n## Checkpoint synchronization — 18 September 2026\n\nThe planned shared-state/multi-API architecture is now implemented for the development/test Synology: PostgreSQL, two stateless APIs, Nginx and one single-active collector. Full resilience acceptance passed. This protects against an individual API process/container failure only, not NAS/router/broadband/power/site failure. See `CHECKPOINT-2026-09-18.md`.\n

## Restricted in-app operations

The resilience roadmap now includes a restricted iOS/Android Admin function for current infrastructure health/resource visibility and deliberate scale up/down of the stateless API tier. This is a control-plane feature, not autoscaling. PostgreSQL, Nginx and the collector remain singleton/non-scalable from the app. Docker-host control must be isolated from the public API and narrowly allow-listed. See `ADMIN-INFRASTRUCTURE.md`.


## Admin control-plane implementation checkpoint — 3 October 2026

The current Compose topology includes `atom-admin-monitor` and internal-only `atom-admin-control`. The monitor reports all ATOM Monitor service containers, including both Admin services. The control boundary can scale only the stateless API tier and cannot mutate PostgreSQL, Nginx, collector or either Admin service. Device pairing replaces shared-secret entry on phones. Scaling timeout layers are ordered so health convergence completes before a gateway/client timeout. This improves operational control but does not change the single-NAS failure domain.
