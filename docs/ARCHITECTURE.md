# ATOM Monitor — Architecture

Last updated: 17 September 2026

## Purpose and scope

ATOM Monitor monitors the operational health and technical status of PilotAware ATOM ground stations. It does not display, record or retain aircraft movements, tracks, aircraft identities or aircraft packet history.

## Current architecture

```text
OGN APRS (receiver-status traffic only)
        |
        v
Synology NAS / Docker Compose
  ogn-station-probe collector
        |
        | authenticated station observations
        v
  ATOM API (Gunicorn + Flask)
        |
        v
  SQLite persistent station registry
        |
        +---- HTTPS public reads via DSM reverse proxy :8445
        |
        +---- HTTP LAN diagnostics :8088
        v
iOS SwiftUI client / Android Kotlin Compose client
```

The collector connects receive-only to the OGN APRS service and classifies PilotAware/ATOM ground-station messages. Aircraft messages are discarded and are not persisted.

## Server deployment

The current development/test deployment runs on the Synology NAS using Docker Compose. The API container is served by Gunicorn 23.0.0 with two workers and two threads per worker. The collector waits for the API readiness healthcheck before starting.

The API exposes inexpensive process liveness at `/health` and database-backed readiness at `/ready`. Docker checks `/ready` and uses bounded JSON logging, a graceful stop period and `restart: unless-stopped`.

The SQLite database is persisted outside the disposable container filesystem. PostgreSQL and horizontally replicated stateless API instances remain future resilience/scalability work; multiple API replicas must not be introduced while SQLite is the shared state mechanism.

## Network boundary

Normal remote clients use:

`https://granvillehouse.synology.me:8445/`

DSM reverse proxy terminates valid HTTPS and forwards internally to the API published on host port 8088. Port 8088 is retained for trusted LAN diagnostics and must not be exposed directly to the Internet.

Public station reads are intentionally available. `POST /api/v1/observations` is a write boundary and requires `Authorization: Bearer <token>`. The collector and API receive the same `ATOM_INGEST_TOKEN` through the local `server/.env`. That file is ignored by Git and the token must never be committed, printed in documentation or exposed in diagnostic output.

## Station state ordering

Station observations are ordered independently by category: position, technical status and PilotAware heartbeat. A delayed older packet cannot overwrite newer state in the same category. Explicit packet timestamps that are malformed or more than five minutes ahead of the observation receive time are rejected so an erroneous remote clock cannot poison later ordering. A stale rejected observation does not move `lastSeen` backwards or forwards.

## Client architecture

Both phone clients consume the same station-only REST API and maintain a local last-successful station cache plus durable user preferences/favourites. They derive the configurable Inactive state locally from `lastSeen`; the default threshold is two days.

The product rule is cross-platform parity: a user-facing phone feature or behaviour change is implemented on both iOS and Android in the same development cycle unless a documented platform-specific reason prevents it. Build and runtime-test status are tracked independently for each platform.

### iOS

The iPhone client is SwiftUI, iOS 17+, iPhone only. It provides Map, Stations, Favourites, Report, Settings and Help. It uses the public HTTPS server by default and supports LAN diagnostics. Map/Home behaviour does not request device location.

### Android

The Android client is native Kotlin/Jetpack Compose, API 26 minimum, and provides the same six functional areas. It uses osmdroid for its native map and the same public HTTPS server by default.

## Station detail contract

Station Detail presents the effective status icon and a plain-language explanation, station identity/software, location, system, time and radio telemetry, using `Not reported` for absent optional telemetry. The latest station record has an absolute local date/time while observation ages remain relative.

Uptime, supply voltage and frequency correction are deliberately omitted from the displayed detail schema because the live feed does not populate them reliably. Compatibility fields may remain in the API/client model. RF correction is a separate field and remains displayed.

When coordinates exist, Station Detail provides a Google Maps link requesting satellite imagery, zoom 18 and a pin/query at the exact station latitude/longitude.

## Health presentation

Server health values are Healthy, Warning, No recent heartbeat and Unknown. Clients additionally derive Inactive from the configured age threshold. A Healthy station reporting an older PilotAware version may be presented as Healthy — back-level software without changing its operational health state.

Missing optional technical telemetry by itself is not treated as a station failure.

## Resilience roadmap

The current Phase 1 development/test deployment has health/readiness checks, authenticated ingestion, bounded logging, graceful restart behaviour, Gunicorn WSGI serving and stale/future-packet protection. Phase 2 SQLite backup/recovery is substantially implemented but remains open for the deferred recovery drill and NAS backup-policy check.

Phase 3 migrates the development/test persistent station registry from SQLite to PostgreSQL before any stateless API replication/load balancing. PostgreSQL will run as a dedicated Compose service with its own persistent volume and healthcheck. The API and collector contract remains station-only and unchanged. Migration will be explicit and repeatable: preserve/verify the SQLite source, initialise PostgreSQL schema, copy station rows, compare total and confirmed PilotAware counts, then switch the API database backend. Because this is not a production service, no zero-downtime migration is required; correctness, rollback and evidence take priority.

The Phase 3 rollback boundary is the database-backend switch. The verified SQLite database and its backups remain intact until PostgreSQL runtime tests pass. If the PostgreSQL deployment fails acceptance, the development/test stack can be returned to the SQLite-backed configuration without converting PostgreSQL data back into SQLite.

Only after PostgreSQL migration passes will the architecture move to multiple stateless API replicas behind a load balancer. The collector remains single-active at that stage; collector HA is a separate later problem and must not be implemented by simply starting duplicate collectors.

Two replicas on the same Synology would protect only against an individual process/container failure; they would not protect against NAS, router, broadband, power or site failure.
