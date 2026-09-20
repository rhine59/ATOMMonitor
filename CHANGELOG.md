# Changelog

## 2026-09-17 — Reporting, sharing and cross-platform checkpoint

- Added iPhone Report with station totals, counts by displayed operational status and PilotAware version.
- Added responsive horizontal bar graphs to the shared HTML report while retaining exact count tables and station-level CSV.
- Fixed first-attempt iPhone share-sheet presentation by binding presentation to a populated report payload; physical-iPhone result confirmed good.
- Added persistent XcodeGen automatic-signing configuration using Development Team `VNQTGCW476`; regeneration no longer requires manual Team selection on the configured development Mac.
- Extended the iOS Simulator feature tour to cover the compact Stations heading and Report summary/share control; rerun pending for this checkpoint.
- Advanced Android source toward Report parity with a Report navigation item, status/version counts, responsive HTML bar graphs, CSV station data, Android share chooser and FileProvider-backed temporary report files; Android build/runtime verification pending.
- Synchronized the main README, user guide and authoritative feature-status register with the current implementation and verification state.
- Preserved the project invariant: reports and applications contain ATOM ground-station operational data only and no aircraft movements, tracks or identities.

## 2026-09-16 — Live station pipeline

- Added persistent SQLite station registry in the Synology API container.
- Added REST endpoints for API health, all confirmed ATOM stations, individual stations and collector observations.
- Added explicit `OGN-R/PilotAware` heartbeat parsing; this marker confirms a discovered source as PilotAware/ATOM rather than relying on the `PW` prefix alone.
- Kept position, heartbeat and technical-status timestamps separate.
- Connected the OGN collector container to the API container through Docker Compose.
- Registry retains discovered state across container restarts using `server/data`.
- iPhone now reads station data from the Synology, caches the station response and keeps a durable favourites cache.
- Stations without a position report remain available in Stations/Favourites but are omitted from the map until coordinates are known.
- Added Map/Stations favourite controls and Settings removal.
- Aircraft packets remain outside the accepted parser/database model and are not stored.
- Initial heartbeat health thresholds remain conservative/provisional while multi-station cadence measurements continue.

## 2026-09-15 — Project primed

- Established ATOM Monitor project scope.
- Defined map-first iPhone experience.
- Explicitly excluded aircraft tracking and aircraft-position persistence.
- Selected OGN APRS receiver/status data as the primary live-health candidate pending live validation.
- Proposed Synology/Docker collector + REST API + SwiftUI/MapKit architecture.
- Defined persistent station registry so silent stations remain visible.
- Defined initial health states: Healthy, Warning, No recent heartbeat, Unknown.
- Selected PWMalham as the initial reference/test station.
- Added project vision, requirements, architecture, data-source, OGN APRS, health, map UI, data-model, API, research, decision-log and roadmap documentation.

## 20 September 2026 — restricted API scaling source checkpoint

- Added private `atom-admin-control` service with writable Docker access isolated from the public API and monitoring service.
- Added confirmed, authenticated, bounded `atom-api` scaling (1–4), readiness waiting, serialization and rate limiting.
- Added persistent bounded admin audit events and `GET /api/v1/admin/events`.
- Added separate internal `ATOM_ADMIN_CONTROL_TOKEN` configuration and unit coverage.
- Synology 2→3→2 runtime acceptance and mobile Admin clients remain pending.

## 20 September 2026 — mobile Admin source checkpoint

- Added locked Admin tabs to iOS and Android.
- Added iOS Keychain and Android Keystore-backed administrator-token storage.
- Added infrastructure summary/container display and explicitly confirmed 1–4 API scaling controls.
- Client build/runtime verification remains pending.

## 20 September 2026 — Admin operational scripts

- Removed a fixed Docker API-version assumption for Synology compatibility.
- Added Admin container build/health/no-published-control-port validation.
- Added deferred 2→3→2 live acceptance automation with public-read, singleton and audit checks.
