# ATOM Monitor — API Design

Last updated: 17 September 2026

The API exists solely to support PilotAware ATOM ground-station operational-health monitoring. Aircraft movements, aircraft identities, tracks and aircraft packet history are outside the API and persistence model.

## Base addresses

Production phone clients default to:

`https://granvillehouse.synology.me:8445/`

Trusted LAN diagnostics may use the Synology host on port 8088. Port 8088 must not be Internet-exposed.

## Read endpoints

### `GET /health`

Cheap process-liveness probe. It deliberately has no database dependency.

Typical response:

```json
{"status":"ok","service":"atommonitor-api"}
```

### `GET /ready`

Database-backed readiness probe. It opens the database, executes a simple query and reports the number of confirmed PilotAware stations. HTTP 200 means ready; database/readiness failure returns HTTP 503.

Typical response shape:

```json
{"status":"ready","service":"atommonitor-api","database":"ok","confirmedStations":305}
```

The count is live data and must not be hard-coded by clients or documentation tests.

### `GET /api/v1/stations`

Returns the current persistent station registry used by iOS and Android. Optional telemetry may be null/missing and clients display `Not reported` rather than inventing values.

Important station fields include identity/name, latitude/longitude/altitude, server health, observation timestamps, PilotAware/receiver software versions, CPU/RAM/temperature, NTP offset/correction, RF correction and signal quality.

Compatibility fields such as uptime, supply voltage and frequency correction can remain in the wire/model schema even though current phone Station Detail views deliberately do not display them.

## Observation ingestion

### `POST /api/v1/observations`

Private collector write endpoint. It requires:

`Authorization: Bearer <ATOM_INGEST_TOKEN>`

The shared token is supplied to the collector and API through the local `server/.env`, which is ignored by Git. Never commit or document the token value.

Unauthenticated or incorrect-token writes return HTTP 401 before parsing/upsert. Accepted station observations return HTTP 202. Invalid observations, including implausible future packet timestamps, return HTTP 400.

## Ordering and timestamp rules

Observation ordering is category-specific:

- position -> `lastPosition`
- technical status -> `lastTechnicalStatus`
- PilotAware heartbeat -> `lastHeartbeat`

An incoming observation older than the already stored timestamp for its category is accepted as stale/no-op rather than replacing newer category state. Categories are independent, so a new heartbeat does not prevent a valid position update and vice versa.

If an explicit packet timestamp is malformed, or is more than five minutes later than its receive timestamp, the observation is rejected. If packet time is absent, receive time is used. This protects persistent state from faulty remote clocks.

## Client health semantics

The server supplies the base health state. Phone clients may additionally derive `Inactive` when `lastSeen` is at least the configured Inactive-after age (default two days). Therefore consumers should not assume the server health string is the complete presentation state.

## Security boundary

Public HTTPS GET access is intentional for station-health information. Observation ingestion is authenticated. The collector is station-only and the API must never grow aircraft-position/identity endpoints as part of ATOM Monitor.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe API contract is now exercised through Nginx and directly on both API replicas by `scripts/service-api-acceptance.sh`. `/health`, PostgreSQL-backed `/ready`, station list/detail/404, safe feedback validation and observation authentication all passed. PostgreSQL/API confirmed-station counts agreed at the checkpoint; live counts must never be hard-coded. See `CHECKPOINT-2026-09-18.md`.\n

## Planned admin API

A separately authenticated `/api/v1/admin` contract is planned for infrastructure summary, allow-listed ATOM Monitor container/resource state, bounded operational events and guarded `atom-api` replica scaling. It uses an administrator credential distinct from `ATOM_INGEST_TOKEN`; no generic Docker/shell/filesystem/configuration API is permitted. See `ADMIN-INFRASTRUCTURE.md`.


## Read-only infrastructure administration — implemented, runtime pending

`GET /api/v1/admin/summary` and `GET /api/v1/admin/containers` are implemented by the separate `atom-admin-monitor` service and require `Authorization: Bearer <ATOM_ADMIN_TOKEN>`. The token is distinct from the collector ingest token. Responses are filtered to allow-listed ATOM Monitor Compose services. No scale/mutation endpoint exists yet. Runtime verification is pending.

## Restricted infrastructure administration — implemented contract

Authenticated admin routes are `GET /api/v1/admin/summary`, `GET /api/v1/admin/containers`, `GET /api/v1/admin/events`, and `POST /api/v1/admin/api-scale`. The scale body is `{"replicas": <1..4>, "confirmed": true}`; missing confirmation or invalid counts return 400, a concurrent operation returns 409, rate limiting returns 429, control unavailability/failed readiness returns 503, and success reports previous, requested, running and healthy replica counts. No route accepts a service name or arbitrary Docker operation.
