# ATOM Monitor — Restricted Infrastructure Administration

Last updated: 20 September 2026

## Objective

Add a restricted administrator area to the iOS and Android applications for monitoring the health and resource use of the ATOM Monitor container infrastructure and for deliberately scaling the stateless API tier up or down.

This is infrastructure administration, not station administration. It must preserve ATOM Monitor's invariant that aircraft identities, positions, tracks and movement history are neither displayed nor stored.

## Current deployment boundary

The current Synology development/test stack is:

```text
single-active OGN station collector
          |
          v
       Nginx
          |
    +-----+-----+
    v           v
 API replica  API replica
    \           /
     PostgreSQL
```

Only the stateless `atom-api` service is initially scalable. PostgreSQL, Nginx and the collector remain singleton services. In particular, the collector must not be scaled by the app because duplicate active collectors are not the agreed HA design.

## Security architecture

The phone application must never receive Docker socket access, Synology shell credentials, PostgreSQL credentials, the collector ingest token, or an unrestricted command-execution facility.

Administrative operations must pass through a dedicated server-side admin control service/API. That service is the only component permitted to perform a tightly allow-listed set of container-management operations.

Admin access requires a separate administrator credential from `ATOM_INGEST_TOKEN`. Store its server-side value only in ignored local configuration/secrets. The mobile client stores only the credential/token required for its authenticated admin session using platform-secure storage (iOS Keychain / Android Keystore-backed storage).

The normal public station endpoints remain public read-only endpoints. Admin routes must be separately authenticated and authorization-checked on every request. Authentication failure returns 401; authenticated non-admin access returns 403 where applicable.

Do not expose a generic Docker API, shell command endpoint, arbitrary Compose service name, arbitrary replica count, environment-variable reader, filesystem browser, log-file download, or secret/configuration dump.

## Proposed API

Version the administration contract separately under `/api/v1/admin`.

### GET /api/v1/admin/summary

Returns a compact infrastructure summary:

- overall infrastructure state;
- API desired/running/healthy replica counts;
- PostgreSQL health;
- Nginx health;
- collector running state;
- host CPU load;
- host memory used/total;
- filesystem used/total/free for the relevant Docker/data volume;
- server timestamp.

### GET /api/v1/admin/containers

Returns an allow-listed view of ATOM Monitor containers only, including the monitoring and control-plane containers themselves:

- logical service;
- container name/instance;
- image/tag;
- running state;
- Docker health state where defined;
- uptime/start time;
- restart count;
- CPU percentage;
- memory usage/limit/percentage;
- network receive/transmit counters where safely available.

It must not enumerate unrelated Synology containers.

### GET /api/v1/admin/events

Returns bounded recent operational events for ATOM Monitor infrastructure: admin scale requests/results, container unhealthy/restart transitions and control-service errors. Do not return arbitrary raw Docker logs through this endpoint.

### POST /api/v1/admin/api-scale

Request body:

```json
{"replicas": 3}
```

The server validates the count against configured minimum and maximum values before acting. Initial policy: minimum 1, maximum 4. The operation applies only to `atom-api`.

A successful response includes requested count, resulting running count and resulting healthy count. The operation is not reported successful merely because a Compose command exited successfully: the control service waits for the requested replicas and readiness state, subject to a bounded timeout.

Scaling down must never select PostgreSQL, Nginx or the collector.

## App user experience

Add an `Admin` area on both iOS and Android. It is hidden or locked until administrator authentication succeeds.

The first screen is read-only and shows overall status plus cards/rows for PostgreSQL, Nginx, collector and each API replica. Resource information should be operationally useful rather than a full Docker management console.

The API tier shows the current replica count and provides explicit scale controls. Scaling is a deliberate action: choose the target replica count, review the change, confirm, submit, then show progress/result and refresh infrastructure state.

Do not implement automatic scaling in the phone client. A future server-side autoscaling policy would be a separate feature with its own thresholds, hysteresis, resource safeguards and acceptance criteria.

## Guardrails

- Scale only `atom-api`.
- Default/normal target remains two API replicas.
- Initial permitted range is 1–4 replicas.
- Never allow zero API replicas from the app.
- Require a confirmation before a scale change.
- Serialize scale operations so two requests cannot race.
- Record timestamp, authenticated administrator identity/session identifier, old replica count, requested count and result.
- Rate-limit admin authentication and state-changing requests.
- Do not include secrets in responses or logs.
- Resource monitoring must be read-only.
- A failed scale operation must leave the last known service state visible and report the failure rather than guessing success.
- Public station service and collector ingestion must remain usable while a valid scale operation occurs.
- Scaling does not create host/site high availability; all replicas still run on one Synology.

## Docker control implementation

Do not mount `/var/run/docker.sock` into the existing public ATOM API container. That would turn compromise of the public API into control of the Docker host.

Use a separate, narrowly scoped admin-control component. Its interface exposes only ATOM Monitor health/resource reads and the allow-listed API replica scaling operation. The implementation must validate every requested action server-side and must never concatenate user input into shell commands.

The exact Synology-side privilege mechanism must be selected and tested before implementation is marked build-ready. Whichever mechanism is chosen must be documented in the clean-rebuild runbook and kept unavailable to the normal public API process.

## Monitoring data

The first implementation should use lightweight Docker/host metrics rather than introducing Prometheus/Grafana as a prerequisite. Useful initial data are Docker health/state/restart count/stats plus host CPU, memory and relevant disk capacity.

Long-term metrics/history and alerting can be added later if operational value justifies persistent monitoring. The first admin screen is current-state monitoring, not a new telemetry warehouse.

## Acceptance criteria

Implementation is Tested only when all of the following have evidence:

1. unauthenticated admin summary/control requests are rejected;
2. normal public station reads still work without admin credentials;
3. authenticated admin summary shows only ATOM Monitor infrastructure;
4. secrets are absent from admin responses;
5. both iOS and Android can authenticate and display the same administrative information;
6. API scaling 2 -> 3 reaches three healthy replicas while public reads and collector writes remain available;
7. API scaling 3 -> 2 returns to two healthy replicas while public reads and collector writes remain available;
8. attempts to request 0, above the configured maximum, an invalid value or a non-API service are rejected;
9. PostgreSQL, Nginx and collector remain singletons throughout;
10. concurrent scale requests are serialized/rejected safely;
11. administrative scale actions are recorded in the bounded audit/event trail;
12. the clean Synology rebuild documentation reproduces the admin-control component, authentication configuration and permissions without committing secrets.

## Delivery sequence

1. Server-side admin authentication/control design and tests.
2. Read-only infrastructure summary/resource API.
3. Scale API with strict allow-list and bounds.
4. Server acceptance tests, including availability during scale changes.
5. iOS Admin monitoring UI and secure credential/session storage.
6. Android parity implementation in the same development cycle.
7. Runtime tests on both clients.
8. Update user guide, architecture, API, setup/runbook, build/test and feature-status evidence.

## Status

Planned. No Docker-control privilege has yet been granted to an application component, and no admin endpoint should be considered implemented until the server-side security boundary and Synology privilege mechanism have been built and tested.


## Implementation checkpoint — read-only monitoring

The first server-side slice is now implemented in source. `atom-admin-monitor` is a separate service with a separate `ATOM_ADMIN_TOKEN`; Nginx routes only `/api/v1/admin/` to it. It exposes authenticated summary/container reads and filters Docker discovery to the current Compose project plus the explicit ATOM service allow-list. It has no mutation/scale endpoint. The Docker socket is mounted read-only into this dedicated monitor; note that filesystem read-only mode does not itself constrain Docker API verbs, so the service's code-level GET-only implementation, isolation from the public API process and strict route surface are security controls. A stronger Docker API proxy/authorization boundary remains required before scaling capability is enabled. Source/unit tests are committed; Synology build/runtime testing is pending.

## Implementation checkpoint — controlled API scaling

The second server-side slice is implemented in source. The public-facing `atom-admin-monitor` retains the read-only metrics role and now forwards only confirmed, authenticated scale requests to a private `atom-admin-control` service. Only that private service receives writable Docker-socket access; it exposes no host port and implements only allow-listed `atom-api` scaling plus bounded audit-event reads.

The scale contract is `POST /api/v1/admin/api-scale` with `{"replicas":3,"confirmed":true}`. Counts are restricted to 1–4, Boolean/string counts are rejected, operations are serialized and rate-limited, and success is returned only after the requested number of replicas are running and Docker-healthy within the configured timeout. Scale activity is written to the persistent `atommonitor-admin-audit` volume without secrets. `ATOM_ADMIN_CONTROL_TOKEN` is a third, internal-only secret and must differ from both the external admin and ingest tokens.

Source unit tests pass. Status remains **Implemented — Synology build/runtime acceptance pending**. It must not be marked Tested until the documented 2→3→2 live test proves public reads and collector writes continue, singleton services remain single, audit events are recorded, and both phone clients have been exercised.

## Device pairing authentication — 3 October 2026

Manual entry of the shared administrator token in phone applications has been replaced by one-time device pairing.

- From an allowed local network, open `<server>/api/v1/admin/pair`.
- The server creates one eight-character, single-use code that expires after five minutes and displays both a QR representation and the short code.
- Enter the short code in the iOS or Android Admin screen. The exchange returns a separate random credential for that device.
- Only a SHA-256 hash and device metadata are stored server-side in the persistent `atommonitor-admin-devices` volume. iOS stores the credential in Keychain; Android stores it encrypted using Android Keystore.
- iOS requires Face ID or the device passcode before an existing paired credential is used. Lock keeps pairing; Remove administrator access revokes the server credential and deletes the local copy.
- The pairing page is restricted by `ATOM_ADMIN_PAIRING_NETWORKS`, defaulting to RFC1918 and loopback networks. Add the actual trusted client subnet when the Synology reverse-proxy topology presents another address.
- The legacy `ATOM_ADMIN_TOKEN` remains accepted temporarily for migration and rollback, but is no longer entered in either phone UI. `ATOM_ADMIN_CONTROL_TOKEN` remains internal-only.

Both clients provide **Scan pairing QR code** and exchange the scanned one-time payload immediately. Manual entry of the displayed short code remains available as a fallback. The QR contains no permanent credential.


## Working device-pairing checkpoint — 3 October 2026

The production flow is now QR/short-code pairing, not manual entry of the shared Admin token. Pairing challenges are stored persistently in `/data/admin-pairings.json` alongside the device registry volume. This removed the HTTP 401 caused when page generation and exchange reached different processes or a recreated process.

A live physical-iPhone pairing test passed. The repeatable server check is `scripts/admin-pairing-acceptance.sh`; the complete rebuild/release procedure is `docs/ADMIN-PAIRING-AND-RELEASE.md`. Android source parity exists but remains build/device-runtime pending.


### Admin self-monitoring checkpoint — 3 October 2026

The inventory allow-list includes both `atom-admin-monitor` and `atom-admin-control`. They appear in the same container health/resource list as PostgreSQL, API replicas, Nginx and the collector. This is observation only: the app can still scale only `atom-api`; neither Admin service can be scaled or mutated through the mobile control plane.
