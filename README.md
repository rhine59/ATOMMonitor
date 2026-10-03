# ATOM Monitor

ATOM Monitor is a cross-platform mobile application and supporting Synology-hosted service for monitoring the operational health and technical status of PilotAware ATOM ground stations.

> **Scope:** ATOM Monitor does not display, record or retain aircraft movements, tracks or aircraft identities.

## Current checkpoint — 3 October 2026

The project has a working Synology Docker server, a native SwiftUI iPhone application, and a native Kotlin/Jetpack Compose Android application using the same ATOM station REST API. Administrator QR pairing has passed a live iPhone test. Android pairing source parity is implemented but still requires device runtime verification.

### Server

The Synology Docker deployment maintains a persistent ground-station registry from OGN/APRS receiver/status traffic and exposes station data through a REST API. The internal/LAN service is host port `8088`; runtime station state is stored in PostgreSQL in a persistent named Docker volume. Two stateless API replicas run behind Nginx; the preserved SQLite database is rollback/historical data, not the live backend. Aircraft messages are discarded and aircraft movement data is not part of the database or API.

Public access is through DSM Reverse Proxy at `https://granvillehouse.synology.me:8445/`, terminating valid HTTPS and forwarding internally to `http://localhost:8088`. Port 8088 is diagnostic/internal and must not be directly Internet-forwarded. The complete rebuild/deployment procedure is in `docs/SYNOLOGY-HOSTING-RUNBOOK.md`.

### iPhone application

The iOS application targets iOS 17+ and is generated with XcodeGen. Its functional areas are **Map, Stations, Favourites, Report, Settings, Help, Feedback and About**. The latest iPhone source has a confirmed Xcode build after XcodeGen regeneration; About/version/licensing refinements require the current checkpoint rebuild/runtime confirmation. Report provides counts by displayed status and PilotAware version and shares a responsive HTML report with horizontal bar graphs plus a station-level CSV attachment through the native iOS share sheet.

The Map supports clustering, Find, selectable Apple map layers, Home station, manual refresh, configurable health/status colours and station-count status. Station detail displays **Record date & time** as the absolute local date/time of `lastSeen`, alongside relative observation ages. The latest station snapshot is cached locally and refresh defaults to five minutes.

XcodeGen now persists automatic signing for the development team (`VNQTGCW476`), removing the need to reselect Signing → Team after project regeneration on the configured development Mac.

### Android application

The `android/` directory contains a native Kotlin/Jetpack Compose counterpart targeting Android API 26+. Its navigation source now includes **Map, Stations, Favourites, Report, Settings, Help, Feedback and About**. The Android Report implementation mirrors the station-only report scope: total/status/version counts, responsive HTML bar graphs, station-level CSV, and native Android sharing using FileProvider-backed temporary files.

The Android source also includes station mapping/search, station and favourite lists, technical detail, absolute Record date & time plus relative observation ages, public-server configuration, 1–10 minute foreground refresh, manual refresh, Home-station preference, persistent preferences and a local latest-snapshot cache. It defaults to `https://granvillehouse.synology.me:8445/`.

Android mapping currently uses osmdroid/OpenStreetMap so it requires no Google Maps API key. Marker clustering, full configurable colour parity, explicit `/health` Test Connection, stronger refresh lifecycle handling, Android automated tests and the approved app icon remain parity work. The responsive Android launcher previously built and ran successfully on the Pixel 10a emulator with live station data. The newer Feedback/About/licensing changes are **build/runtime test pending**. Home map centring passed, while the Home-station picker scrolling defect remains open.

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
  PostgreSQL persistent station registry
  Nginx -> two stateless REST API replicas :8088 internal
              |
              v
       DSM Reverse Proxy
https://granvillehouse.synology.me:8445
          /          \
         v            v
 iPhone / SwiftUI   Android / Compose
```

Observation ingestion is authenticated with the private collector token. The new feedback relay is not production-ready until private SMTP configuration, delivery testing and abuse/rate-limiting review are completed.

## Known follow-up work

Shared engineering work includes server/cache ownership robustness, protecting the public ingestion path, preventing overlapping refreshes, separating cache-write errors from successful network refreshes, correcting server upserts so older packets cannot overwrite newer telemetry, and continuing health-threshold validation. Android-specific parity work is tracked in `android/README.md`; the broader engineering sequence is in `docs/IMPROVEMENT-ROADMAP.md`.

## Documentation

`docs/` is part of the implementation. It contains architecture, requirements, API/data-model design, OGN/APRS and data-source research, build/test/demo procedures, live-integration evidence, UI behaviour, public-server/Synology hosting, design decisions, checkpoints and the maintained user guide. Platform-specific Android setup and parity status is maintained in `android/README.md`. User-facing changes should be synchronized across platform-local help where applicable.

## Terminology

A missing heartbeat means no recent status report has been observed. It is not proof that the physical installation is powered off, so the applications deliberately say **No recent heartbeat** rather than **Offline**.

## Copyright and third-party marks

Copyright © 2026 Richard Hine. All rights reserved.

Unless and until a separate licence is added to this repository, no licence to copy, modify, distribute or create derivative works from ATOM Monitor is granted beyond rights that apply by law or by the hosting platform terms.

PilotAware® is a registered trademark of PilotAware Ltd. ATOM Monitor is an independent project and is not affiliated with, endorsed by or sponsored by PilotAware Ltd. References to PilotAware and ATOM identify the third-party technology and ground-station network with which ATOM Monitor interoperates.

## 18 September 2026 checkpoint

Feedback and About are now first-class navigation areas on both phone clients. About carries creator, Version, Build, Platform/OS, PilotAware ATOM link, copyright/trademark/non-affiliation and distribution/licence information. Feedback UI is implemented but mail delivery is deliberately deferred until Synology SMTP configuration/testing is resumed.

Phase 2 SQLite backup/recovery tooling is retained and regression-tested against the preserved rollback database. Phase 3 PostgreSQL migration is Tested and PostgreSQL is the live backend. Phase 4 two-replica API/Nginx resilience acceptance passed, including loss/rejoin of either replica, API/LB recreation and live collector HTTP 202 traffic through Nginx. The complete Phase 1–4 plus service/API acceptance suite passed on the Synology. PostgreSQL backup/restore and the associated NAS/external backup policy remain the principal server operational gap. See `docs/CHECKPOINT-2026-09-18.md`.

## Restricted infrastructure administration checkpoint — 20 September 2026

The server source now contains a separate authenticated Admin control plane. Read-only monitoring is handled by `atom-admin-monitor`; confirmed manual scaling is delegated to an internal-only `atom-admin-control` service that can change only the `atom-api` replica count from 1–4. Operations are serialized, rate-limited, audited and reported successful only after all requested replicas are Docker-healthy. The inventory includes both Admin containers as healthy singleton services. iOS pairing has live physical-device evidence; Android build/device runtime acceptance remains pending.


## Administrator device pairing — tested 3 October 2026

Administrator access now uses a LAN-restricted, five-minute one-time QR/short code. The apps exchange it for an individually revocable device credential; shared administrator secrets are never entered on a phone. Pairing challenges and device registrations persist in the Admin Docker data volume, including across container recreation and load-balanced requests. The complete rebuild, release, acceptance and recovery procedure is in `docs/ADMIN-PAIRING-AND-RELEASE.md`.

The iOS QR → exchange → stored credential flow passed on a physical iPhone. Android includes the corresponding Google code-scanner and Keystore implementation; its current build and device-runtime verification remain pending.


## Admin service synchronization — 3 October 2026

Both mobile apps consume the same generic Admin container contract and therefore display `atom-admin-monitor` and `atom-admin-control` without platform-specific service lists. Only `atom-api` exposes scaling controls. Clean Admin rebuilds recreate Nginx, validate pairing/summary/scale routes and use timeout layers long enough for Docker health convergence.


The consolidated current Admin checkpoint is `docs/CHECKPOINT-2026-10-03-ADMIN.md`. Use `scripts/build-all-containers.sh` for a clean service rebuild plus pairing acceptance; use `scripts/all-phases-acceptance.sh` and `scripts/admin-scaling-acceptance.sh` for the complete regression.
