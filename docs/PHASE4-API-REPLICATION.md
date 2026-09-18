# ATOM Monitor — Phase 4 Stateless API Replication and Load Balancing

Checkpoint started: 18 September 2026

## Objective

Run multiple stateless ATOM Monitor API instances against the tested shared PostgreSQL database and place a single load-balancing entry point in front of them. This phase improves tolerance of an individual API process/container failure and prepares the service for later scaling work.

This remains the Synology development/test deployment. It does not provide NAS, site, broadband, router or power high availability.

## Scope invariants

ATOM Monitor remains ground-station health/status only. No aircraft movements, identities, tracks or packet history may be introduced.

The OGN collector remains **single-active**. Phase 4 must not create duplicate collectors as a shortcut to collector high availability.

## Starting point

Phase 3 is Tested. PostgreSQL is the live station registry and survives restart/container recreation through its named Docker volume. The API is already database-independent through `ATOM_DATABASE_URL`, and live collector writes, public reads, authentication, stale/future ordering and persistence have passed on PostgreSQL.

Current request path:

```text
clients / collector
        |
        v
single Gunicorn/Flask API
        |
        v
PostgreSQL
```

## Target architecture

```text
public HTTPS / LAN diagnostics
             |
             v
       load balancer
        /         \
       v           v
  API replica 1  API replica 2
        \         /
             v
         PostgreSQL

single-active OGN collector
             |
             v
        load balancer
```

Both API replicas use the same PostgreSQL database and the same server-side configuration/secrets. No API replica may depend on container-local persistent application state.

## Implementation sequence

1. Remove the fixed API container identity and define a Compose service that can be replicated safely.
2. Add an internal load-balancing service with health-aware routing to API replicas.
3. Move the host/LAN API publication to the load balancer so clients keep the existing external contract.
4. Keep PostgreSQL private on the Compose network and health-gate API startup on PostgreSQL.
5. Point the single-active collector at the load-balancing service rather than one named API container.
6. Start two API replicas and verify both are healthy and share the same PostgreSQL state.
7. Exercise readiness, station list/detail reads and authenticated collector ingestion through the load balancer.
8. Stop one API replica and prove reads and collector writes continue through the surviving replica.
9. Restore the replica and prove it rejoins without data repair or local-state recovery.
10. Recreate an API replica and the load balancer and verify service recovery.

## Rollback boundary

Phase 4 does not change the PostgreSQL data model. Rollback is therefore a Compose topology rollback: return to one API instance pointed directly at the same PostgreSQL database and restore the previous host-port/collector routing. PostgreSQL data is not converted or restored during this rollback.

## Acceptance

Phase 4 is **Tested** only after two API replicas are running against PostgreSQL; the load balancer is the normal API entry point; existing read/write/security/ordering behaviour still passes; loss of either API replica does not interrupt station reads or authenticated collector ingestion; the stopped/recreated replica can rejoin cleanly; and the exact single-API rollback boundary is recorded.

## Non-goals

This phase does not implement PostgreSQL high availability, collector high availability, multi-NAS/site failover, external orchestration, Kubernetes, or geographic redundancy. Those require separate failure-domain decisions after the same-Synology API-replication checkpoint is understood.

## Pre-cutover runtime checkpoint — 18 September 2026

Immediately before the first Phase 4 topology deployment, the existing single-API PostgreSQL-backed stack was verified on the Synology with `sudo docker compose ps`:

- `atommonitor-api`: Up/healthy, host `8088 -> 8080`.
- `atommonitor-postgres`: Up/healthy, private `5432/tcp`.
- `atommonitor-ogn-probe`: Up.

The existing entry point was then checked with:

```bash
curl -fsS http://localhost:8088/ready
```

and returned:

```json
{"confirmedStations":308,"database":"ok","databaseBackend":"postgresql","service":"atommonitor-api","status":"ready"}
```

This is the rollback/reference checkpoint immediately before deploying the Phase 4 load-balancer topology. No Phase 4 runtime cutover had occurred at this point.

## First load-balancer deployment finding — 18 September 2026

The first `atom-lb` start exposed a required Nginx/Docker DNS setting. Nginx restarted with:

```text
no resolver defined to resolve names at run time in upstream "atommonitor_api"
```

Because the upstream uses `server atom-api:8080 resolve;` for runtime replica discovery, the Nginx configuration must explicitly use Docker's embedded DNS resolver. The configuration was corrected with:

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
```

This setting is part of the reproducible Compose environment and must be retained in a clean rebuild. The failure occurred before the load balancer could serve host port 8088; PostgreSQL and the recreated API remained separate from this Nginx configuration failure.
