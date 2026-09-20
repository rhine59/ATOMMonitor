# Requirements

Checkpoint: 16 September 2026.

## Functional requirements

### Map

- The application opens directly to a full-screen adaptive MapKit map.
- All known ATOM stations with usable coordinates are represented; stations remain represented after they stop reporting.
- Markers communicate Healthy, Warning, No recent heartbeat and Unknown states and dense areas cluster.
- The user can pan, zoom and tap a station to open full station detail directly.
- Search uses the compact `Find` field and accepts full or partial station names.
- Apple map presentation is selectable between Standard, Satellite + Labels and Satellite, with the selection remembered locally.
- A Home button returns to the ground station selected as Home in Settings. If none is configured, the exact message is `No home station set`.
- A manual refresh button requests a fresh snapshot.
- A plain status line below the title/buttons and above Find displays `Last updated: HH:MM` after success. If the current server request fails it displays `No Network`; cached station data remains visible.
- Device location permission is not required for normal use or Home station behaviour.

### Stations and favourites

- Stations presents the persistent registry and opens full station detail.
- Favourites provides local quick access to selected stations and is stored on the iPhone.
- Favourites do not alter server collection or registry state.

### Station details

Display when available: station name/identifier, latitude/longitude, altitude, latest observation/heartbeat timestamps, software/version/platform, CPU load and temperature, RAM usage/total, uptime, NTP offset/correction, RF/frequency correction/quality/gain, voltage and useful provenance.

The Health section must display **Record date & time** as an absolute local date/time derived from the station's latest `lastSeen` timestamp. Last heartbeat, Last seen, Last position and Last technical status remain relative-age indicators. This provides both an exact timestamp for the latest station record and an immediate indication of the age of individual observations.

Missing fields must be represented as `Not reported`; absence of optional telemetry alone must not create an unhealthy state.

### Health

Initial derived states are Healthy, Warning, No recent heartbeat and Unknown. Current provisional server heartbeat thresholds are <=420 seconds Healthy, <=900 seconds Warning, >900 seconds No recent heartbeat, and absent/invalid heartbeat Unknown. These remain subject to multi-station cadence validation. The UI must not claim a station is physically Offline merely because a heartbeat has not been observed.

### Refresh and offline behaviour

- Fetch once at application startup, then automatically while active.
- User-configurable whole-minute interval from 1 to 10 minutes; default **5 minutes**.
- Remember the selected interval on the iPhone.
- Preserve the last successful station snapshot in a local cache and display it during server/network failure.
- Manual refresh is available from Map and Stations.
- Avoid overlapping refresh operations as the implementation is hardened.

### Settings

- Server URL is configurable.
- Settings provides Test Connection.
- Home station, favourites, map layer and refresh interval persist locally.
- Normal remote operation uses HTTPS DNS; the established endpoint is `https://granvillehouse.synology.me:8445/`.
- Port 8088 is internal/LAN diagnostic access and must not be directly Internet-forwarded.

### Help

- The normal User Guide must be available locally inside ATOM Monitor as native app content.
- Opening the User Guide must not require Safari, GitHub or an Internet connection.
- User-facing changes must be reflected in both repository documentation and the in-app guide.

### Data collection

- Maintain one long-lived OGN APRS connection on the server rather than one per iPhone.
- Parse receiver/status messages relevant to ATOM ground-station health.
- Maintain a persistent station registry independent of current live status.
- Do not persist or expose aircraft positions, tracks, identities or movement history.
- Prevent stale incoming packets from overwriting newer corresponding telemetry as server persistence is hardened.

## Non-functional requirements

- Native SwiftUI iPhone application, iOS 17+.
- Adaptive layout across supported iPhone screen sizes.
- MapKit mapping and no third-party iOS runtime dependency requirement.
- Server deployable with Docker Compose on Synology.
- HTTPS/JSON interface between public server and app through DSM Reverse Proxy.
- Public observation-ingestion/write surfaces must be restricted or authenticated before Internet exposure is considered hardened.
- Reconnection/backoff for OGN interruption.
- Clearly distinguish observed telemetry from derived health state.
- ATOM Monitor is not a certified, safety-critical or authoritative aviation operational-status service.

## Build and source-control requirements

- Xcode project is generated from `ios/project.yml` with XcodeGen.
- Build/test procedures and meaningful milestone/failure evidence are tracked in Git.
- On the development Mac, command-line Simulator builds use DerivedData outside `~/Documents` to avoid File Provider signing metadata.
- Finished `.mp4` and `.log` evidence may be tracked; raw `*-raw*.mp4`, DerivedData, runtime SQLite and `.DS_Store` are not repository artefacts.
- Material implementation changes require synchronized documentation and a Git commit.
- Synology rebuild/deployment/recovery procedure is maintained in `docs/SYNOLOGY-HOSTING-RUNBOOK.md`.

## Data-source requirements

The provider design must remain replaceable/supplementable. OGN APRS receiver/status traffic is the current live source. `OGN-R/PilotAware` is a strong live PilotAware/ATOM classifier; `PW` prefix filtering is useful for discovery but is not by itself an authoritative complete registry rule. No undocumented source is assumed permanently guaranteed.
\n\n## Checkpoint synchronization — 18 September 2026\n\nCurrent server requirements are implemented through the PostgreSQL/two-API/Nginx checkpoint and the cross-phase acceptance framework is Tested. The ground-station-only scope and iOS/Android parity rule remain unchanged. PostgreSQL backup/restore remains an outstanding operational requirement. See `CHECKPOINT-2026-09-18.md`.\n

## Restricted infrastructure administration — planned 20 September 2026

A restricted cross-platform Admin function is now required for current ATOM Monitor infrastructure health/resource monitoring and deliberate API-tier scaling. It must use a dedicated authenticated server-side control boundary; phone clients must never receive Docker/Synology/database/ingest credentials or generic command execution. Only the stateless `atom-api` tier is initially scalable, with a proposed guarded range of 1–4 and normal target of two. PostgreSQL, Nginx and the single-active collector remain singletons. See `ADMIN-INFRASTRUCTURE.md`.
