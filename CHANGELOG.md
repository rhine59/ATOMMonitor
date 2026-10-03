## 3 October 2026 — device pairing authentication

- Replaced phone entry of the shared administrator token with five-minute, one-time device pairing codes.
- Added persistent, individually revocable device credentials, a LAN-restricted pairing page with QR/short-code display, iOS Keychain plus Face ID/passcode unlock, and Android Keystore storage.
- Added direct in-app QR scanning on iOS and Android, retaining manual short-code entry as fallback.
- Persisted pending challenges in the shared Admin data volume, fixing the cross-process/restart HTTP 401 exchange failure.
- Confirmed the QR pairing flow live on a physical iPhone; Android device verification remains pending.
- Added an end-to-end pairing/revocation acceptance script and an authoritative rebuild/release runbook.
- Bumped the iOS TestFlight build to 1.0 (3) and Android version code to 3.

# Changelog

## 3 October 2026 — meaningful OGN collector health

- Added an APRS activity heartbeat and Docker healthcheck to `ogn-station-probe`.
- Collector health now distinguishes a running process from an active upstream APRS connection.
- Updated the collector rebuild to wait for Docker healthy rather than accepting running alone.


## 3 October 2026 — synchronized Admin checkpoint

- Synchronized architecture, requirements, design decisions, roadmaps, parity audit, platform guides and public/Synology deployment documentation.
- Updated complete rebuild scripts to recreate Nginx and run Admin pairing acceptance.
- Updated the Synology test runner to include Admin container logs and pairing verification.
- Added `docs/CHECKPOINT-2026-10-03-ADMIN.md` as the authoritative current checkpoint.
- Confirmed both apps consume the same generic container inventory while scaling remains restricted to `atom-api`.


## 3 October 2026 — Admin self-monitoring

- Added `atom-admin-monitor` and `atom-admin-control` to the restricted Admin container inventory.
- Kept mobile scaling restricted to `atom-api`; the Admin services remain read-only inventory entries.
- Added unit coverage for both required Admin service names.


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

## 3 October 2026 — Report drill-down and software highlighting preference

- Made Report total, status and PilotAware-version counts open the corresponding filtered Stations list on iOS and Android.
- Added a first-class Not reported version filter.
- Added persisted Highlight back-level software setting, Off by default.
- Preserved operational-health precedence and retained version reporting/filtering when highlighting is disabled.
- iOS and Android build/runtime verification remains pending.


## 3 October 2026 — Admin scaling timeout correction

- Increased the scale readiness window to 90 seconds.
- Ordered the Admin monitor, Nginx and mobile-client timeouts above that controller window.
- Prevents premature HTTP 504 responses while new API replicas are still becoming Docker-healthy.

## 3 October 2026 — station icon legend

- Added **More → Legend** on iOS and Android for station icon colours and meanings.
- The legend includes Healthy, Warning, No recent heartbeat, Inactive and Unknown.
- Back-level software appears only when highlighting is enabled; operational status retains precedence.
- Replaced Android's overcrowded nine-item bottom bar with Map, Stations, Favourites, Report and More.
- Bumped iOS to version 1.0 build 4 and Android to version code 4.
- Build/runtime verification remains pending on both platforms.
