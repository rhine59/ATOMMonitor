# ATOM Monitor checkpoint — 16 September 2026

This file records the project state at the documentation checkpoint requested after the current iPhone map/help work.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM **ground-station operational health and technical status only**. It does not display, record or retain aircraft movements, aircraft tracks or aircraft identities. This invariant applies to collector, database, API, iPhone UI, diagnostics and future work.

## Working system

The Synology Docker service receives OGN/APRS receiver/status traffic, classifies PilotAware/ATOM ground stations, maintains a persistent SQLite station registry and serves station snapshots over REST. The current LAN host mapping is port 8088. The iPhone app consumes that API and retains a latest-snapshot cache.

Live server testing has established a registry of roughly 300 stations. PWFirefly testing on 16 September measured position cadence around 300 seconds and heartbeat cadence around 291 seconds. Current heartbeat health thresholds remain provisional pending wider cadence validation.

## iPhone state

The SwiftUI iPhone app targets iOS 17+ and provides Map, Stations, Favourites, Settings and Help tabs. Map is full-screen/adaptive, supports clustering, Find, direct detail, Standard/Satellite map layers, Home station and manual refresh. `Last updated` is plain text below the title/button row and above Find. A failed current server request replaces it with red `No Network`, while cached data remains visible.

Automatic refresh occurs at startup and then at a configurable 1–10 minute interval. The default is now 5 minutes. Existing installations retain an already stored preference until changed.

The User Guide is local native SwiftUI content under Help and does not open GitHub/Safari. The repository `docs/USER-GUIDE.md` remains the maintained documentation counterpart; user-facing changes must update both.

The atom app icon is configured as `AppIcon` and the icon-enabled project has completed a successful Simulator build.

## Build checkpoint

Generate with:

```bash
cd ~/Documents/Xcode/ATOMMonitor/ios
xcodegen generate
```

For command-line Simulator build, keep DerivedData outside Documents/File Provider storage:

```bash
rm -rf /tmp/ATOMMonitor-DerivedData
xcodebuild build \
  -project ATOMMonitor.xcodeproj \
  -scheme ATOMMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/ATOMMonitor-DerivedData
```

Latest reported result at this checkpoint: `** BUILD SUCCEEDED **`.

## Current technical debt / next engineering items

1. Make server URL changes actually replace/reconfigure the repository used by `StationStore`; do not leave a store bound to an old immutable repository.
2. Make station caches server-specific or deliberately clear/re-key them when server changes.
3. Add a distinct refresh-in-progress state and serialize refresh requests so timer/manual/startup loads cannot overlap.
4. Do not report a successful network fetch as failed solely because writing the local cache fails.
5. Harden deterministic UI-test preference reset and UI-test selectors.
6. On the server, compare packet timestamps before upsert so stale technical packets cannot overwrite newer values.
7. Restrict/authenticate the observation-ingestion endpoint before public Internet exposure; expose only the intended read API through HTTPS.
8. Continue multi-station cadence validation before treating health thresholds as stable.
9. Continue resolving an authoritative complete ATOM registry/bootstrap mechanism rather than treating the `PW` prefix as complete classification.

## Documentation state

At this checkpoint the repository documentation set has been reviewed for the current project direction. `README.md`, `REQUIREMENTS.md`, `MAP-UI.md` and `USER-GUIDE.md` reflect the latest user-facing behaviour; this checkpoint consolidates the current implemented state, build result and known outstanding engineering work. Existing specialist documents remain authoritative for their areas: API/data model, OGN/APRS/data sources, architecture, public server setup, live integration tests, build/test, demo automation, research notes and design decisions.
