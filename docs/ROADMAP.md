# Roadmap

## Phase 0 — Data validation

- Capture live OGN receiver/status data for PWMalham.
- Establish compliant connection/login/filter behaviour.
- Determine heartbeat interval.
- Catalogue actual fields and units.
- Repeat against representative ATOM stations/software versions.
- Investigate complete station-registry bootstrap source.

**Exit criterion:** we can reliably turn real receiver/status packets into a canonical station observation without retaining aircraft data.

## Phase 1 — Collector prototype

- Python collector.
- APRS reconnect/backoff.
- Receiver/status parser with fixture tests.
- ATOM classification.
- In-memory/latest station registry.
- Simple diagnostic output for PWMalham.

## Phase 2 — Persistent server

- FastAPI REST service.
- PostgreSQL schema/migrations.
- Persistent station registry.
- Latest health and history.
- Derived health evaluator.
- `/api/v1/stations`, detail, history and service-health endpoints.
- Dockerfile and Docker Compose for Synology.
- Operational diagnostics documentation.

## Phase 3 — iPhone MVP

- SwiftUI project.
- API models/client.
- MapKit map of all stations.
- Health markers and clustering.
- Search by station name.
- Selection summary card.
- Station detail view.
- Adaptive layouts for iPhone sizes.

## Phase 4 — History and polish

- Swift Charts health history.
- 24h/7d/30d ranges.
- Better map clustering semantics.
- Dark mode/Dynamic Type/accessibility.
- Caching/offline last-known station map.
- Favourites.

## Phase 5 — Optional monitoring

- Favourite-station notifications.
- Server-side debouncing/hysteresis.
- Distinguish individual station silence from upstream OGN/server outage.
- PilotAware supplementary metadata if a stable appropriate source is validated.

## Immediate next task

Build a minimal diagnostic OGN APRS collector whose only purpose is to find and print receiver/status messages for `PWMalham`, while explicitly discarding aircraft traffic. Use captured examples to define parser tests before designing the production schema around guessed packet formats.
\n\n## Checkpoint synchronization — 18 September 2026\n\nPhase 3 PostgreSQL migration is Tested; Phase 4 replicated API/Nginx runtime acceptance has passed; and the cross-phase acceptance framework is Tested. The next server priority is PostgreSQL backup/restore and backup-policy coverage, followed by formal Phase 4 close-out. No Phase 5 acceptance contract has yet been defined. See `CHECKPOINT-2026-09-18.md`.\n

## Planned restricted Admin function — 20 September 2026

Add a separately authenticated iOS/Android Admin area backed by a narrow server-side control service. Phase one provides current ATOM Monitor container/host health and resource monitoring; phase two permits deliberate scale up/down of `atom-api` only, with bounds, confirmation, serialization and audit events. This is not automatic scaling and does not change the single-Synology failure domain. See `ADMIN-INFRASTRUCTURE.md`.

## Admin implementation progress — 20 September 2026

Server delivery steps 1–3 are implemented in source: separate authentication/control design, read-only infrastructure monitoring, and guarded `atom-api` scaling. Next is Synology acceptance (including 2→3→2 availability and audit evidence), followed by iOS Admin UI/secure storage and Android parity/runtime tests.
