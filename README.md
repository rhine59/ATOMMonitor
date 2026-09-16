# ATOM Monitor

ATOM Monitor is an iPhone application and supporting Synology-hosted service for monitoring the operational health and technical status of PilotAware ATOM ground stations.

> **Scope:** ATOM Monitor does not display, record or retain aircraft movements, tracks or aircraft identities.

## Current checkpoint — 16 September 2026

The project has a working Synology Docker server and native SwiftUI iPhone application using live ATOM station data.

### Server

The Synology Docker deployment maintains a persistent ground-station registry from OGN/APRS receiver/status traffic and exposes station data through a REST API. The internal/LAN service is host port `8088`; runtime station state is stored in SQLite. Aircraft messages are discarded and aircraft movement data is not part of the database or API.

Public access is through DSM Reverse Proxy at `https://granvillehouse.synology.me:8445/`, terminating valid HTTPS and forwarding internally to `http://localhost:8088`. Port 8088 is diagnostic/internal and must not be directly Internet-forwarded. The complete rebuild/deployment procedure is in `docs/SYNOLOGY-HOSTING-RUNBOOK.md`.

Current health states are **Healthy**, **Warning**, **No recent heartbeat** and **Unknown**. Missing optional telemetry is displayed as `Not reported` and does not by itself make a station unhealthy.

### iPhone application

The iOS application targets iOS 17+ and is generated with XcodeGen. Its main tabs are **Map**, **Stations**, **Favourites**, **Settings** and **Help**.

The Map is full-screen and adaptive across iPhone sizes. It supports station clustering, direct station-detail selection, search (`Find`), Standard/Satellite map layers, a configurable Home station and manual refresh. The status line below the title/button row and above `Find` shows `Last updated: HH:MM` after a successful server refresh and `No Network` when the current server request fails. Cached station data remains visible during a connection failure.

Station detail now displays **Record date & time** as the absolute local date/time of the station's latest `lastSeen` record. Last heartbeat, Last seen, Last position and Last technical status remain relative-age indicators.

Station data is fetched at startup and then automatically at a configurable 1–10 minute interval; the default is **5 minutes**. The latest successful station snapshot is cached locally. Favourites, Home station, map layer and refresh preference are stored on the iPhone.

The Help tab contains a **native local User Guide**. Normal user help does not require GitHub, Safari or an Internet connection.

The app icon is the ATOM atom graphic in `ios/ATOMMonitor/Assets.xcassets/AppIcon.appiconset/`, selected by `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `ios/project.yml`.

## Build

Generate the project:

```bash
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

For command-line Simulator builds on the development Mac, use DerivedData outside `~/Documents` because File Provider metadata there has previously caused code-signing failures:

```bash
rm -rf /tmp/ATOMMonitor-DerivedData
xcodebuild build \
  -project ATOMMonitor.xcodeproj \
  -scheme ATOMMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/ATOMMonitor-DerivedData
```

The current icon-enabled configuration has been verified with `** BUILD SUCCEEDED **`.

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
              |
              v
       iPhone / SwiftUI
```

Before the Internet-facing deployment is treated as fully hardened, observation ingestion must not remain an unauthenticated public write surface; public access should be restricted to intended read functionality wherever practical.

## Known follow-up work

Important engineering work includes making the verified public HTTPS endpoint the compiled app default, making server switching/cache ownership robust, protecting the public ingestion path, preventing overlapping refreshes, separating cache-write errors from successful network refreshes, hardening UI-test preference reset, correcting server upserts so older packets cannot overwrite newer telemetry, and continuing validation of health thresholds against multiple live stations.

## Documentation

`docs/` is part of the implementation. It contains architecture, requirements, API/data-model design, OGN/APRS and data-source research, build/test and demo procedures, live-integration evidence, map/UI behaviour, public-server setup, the complete Synology hosting runbook, design decisions, checkpoints and the maintained user guide. User-facing changes must also be reflected in the local in-app User Guide.

## Terminology

A missing heartbeat means no recent status report has been observed. It is not proof that the physical installation is powered off, so the application deliberately says **No recent heartbeat** rather than **Offline**.
