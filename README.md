# ATOM Monitor

ATOM Monitor is a cross-platform mobile application and supporting Synology-hosted service for monitoring the operational health and technical status of PilotAware ATOM ground stations.

> **Scope:** ATOM Monitor does not display, record or retain aircraft movements, tracks or aircraft identities.

## Current checkpoint — 17 September 2026

The project has a working Synology Docker server, a native SwiftUI iPhone application with physical-device report/sharing verification, and a native Kotlin/Jetpack Compose Android application using the same ATOM station REST API. Android source has been advanced toward current iPhone parity but still requires its first confirmed Android build/runtime checkpoint.

### Server

The Synology Docker deployment maintains a persistent ground-station registry from OGN/APRS receiver/status traffic and exposes station data through a REST API. The internal/LAN service is host port `8088`; runtime station state is stored in SQLite. Aircraft messages are discarded and aircraft movement data is not part of the database or API.

Public access is through DSM Reverse Proxy at `https://granvillehouse.synology.me:8445/`, terminating valid HTTPS and forwarding internally to `http://localhost:8088`. Port 8088 is diagnostic/internal and must not be directly Internet-forwarded. The complete rebuild/deployment procedure is in `docs/SYNOLOGY-HOSTING-RUNBOOK.md`.

### iPhone application

The iOS application targets iOS 17+ and is generated with XcodeGen. Its functional areas are **Map, Stations, Favourites, Report, Settings and Help**. Report provides counts by displayed status and PilotAware version and shares a responsive HTML report with horizontal bar graphs plus a station-level CSV attachment through the native iOS share sheet.

The Map supports clustering, Find, selectable Apple map layers, Home station, manual refresh, configurable health/status colours and station-count status. Station detail displays **Record date & time** as the absolute local date/time of `lastSeen`, alongside relative observation ages. The latest station snapshot is cached locally and refresh defaults to five minutes.

XcodeGen now persists automatic signing for the development team (`VNQTGCW476`), removing the need to reselect Signing → Team after project regeneration on the configured development Mac.

### Android application

The `android/` directory contains a native Kotlin/Jetpack Compose counterpart targeting Android API 26+. Its navigation source now includes **Map, Stations, Favourites, Report, Settings and Help**. The Android Report implementation mirrors the station-only report scope: total/status/version counts, responsive HTML bar graphs, station-level CSV, and native Android sharing using FileProvider-backed temporary files.

The Android source also includes station mapping/search, station and favourite lists, technical detail, absolute Record date & time plus relative observation ages, public-server configuration, 1–10 minute foreground refresh, manual refresh, Home-station preference, persistent preferences and a local latest-snapshot cache. It defaults to `https://granvillehouse.synology.me:8445/`.

Android mapping currently uses osmdroid/OpenStreetMap so it requires no Google Maps API key. Marker clustering, full configurable colour parity, explicit `/health` Test Connection, stronger refresh lifecycle handling, Android automated tests and the approved app icon remain parity work. The current Android changes are **build pending** until Android Studio/Gradle confirms them.

## Build

### iOS

```bash
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

For command-line Simulator builds on the development Mac, keep DerivedData outside `~/Documents` because File Provider metadata there has previously caused code-signing failures. The recorded Simulator tour has been extended to cover the Report summary and Share report control; it must be rerun for the new checkpoint.

### Android

Open the repository's `android` directory in Android Studio and allow Gradle to sync, then run the `app` configuration on an emulator or physical Android phone. The project uses Kotlin, Jetpack Compose/Material 3 and osmdroid. See `android/README.md` for the build and parity checklist.

## Production topology

```text
OGN APRS receiver/status traffic only
              |
              v
       Synology Docker
  collector / classifier
  persistent station registry
  SQLite / REST API :8088 internal
              |
              v
       DSM Reverse Proxy
https://granvillehouse.synology.me:8445
          /          \
         v            v
 iPhone / SwiftUI   Android / Compose
```

Before the Internet-facing deployment is treated as fully hardened, observation ingestion must not remain an unauthenticated public write surface; public access should be restricted to intended read functionality wherever practical.

## Known follow-up work

Shared engineering work includes server/cache ownership robustness, protecting the public ingestion path, preventing overlapping refreshes, separating cache-write errors from successful network refreshes, correcting server upserts so older packets cannot overwrite newer telemetry, and continuing health-threshold validation. Android-specific parity work is tracked in `android/README.md`; the broader engineering sequence is in `docs/IMPROVEMENT-ROADMAP.md`.

## Documentation

`docs/` is part of the implementation. It contains architecture, requirements, API/data-model design, OGN/APRS and data-source research, build/test/demo procedures, live-integration evidence, UI behaviour, public-server/Synology hosting, design decisions, checkpoints and the maintained user guide. Platform-specific Android setup and parity status is maintained in `android/README.md`. User-facing changes should be synchronized across platform-local help where applicable.

## Terminology

A missing heartbeat means no recent status report has been observed. It is not proof that the physical installation is powered off, so the applications deliberately say **No recent heartbeat** rather than **Offline**.
