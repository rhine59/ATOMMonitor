# ATOM Monitor — Checkpoint — 17 September 2026

This checkpoint records the project state after Phase 1 server hardening and the 17 September Android parity work. `docs/FEATURE-STATUS.md` remains the authoritative live status register.

## Product boundary

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It does not display, record or retain aircraft movements, tracks, aircraft identities or aircraft packet history.

## Server state

The production service runs on the Synology NAS using Docker Compose. The Flask API is served by Gunicorn 23.0.0 with two workers and two threads per worker. The collector waits for API readiness. Containers use restart-unless-stopped, bounded JSON logs and graceful stop handling.

`GET /health` is a cheap process-liveness endpoint. `GET /ready` checks SQLite and returns the current confirmed-station count. Normal public reads use `https://granvillehouse.synology.me:8445/`. Observation ingestion is authenticated and stale/future packet protection is active. Phase 1 evidence is recorded in `docs/PHASE1-TEST-EVIDENCE-2026-09-17.md`.

## iPhone state

The iOS SwiftUI app uses the public HTTPS service by default and provides Map, Stations, Favourites, Report, Settings and Help. It has persistent station caching/favourites, shared health/version filters, configurable Inactive threshold, report/share, configurable map presentation and Home-station behaviour.

Test Connection uses `/ready` and reports the confirmed station count. This has passed on a physical iPhone. Recent Station Detail changes remain subject to their current build/runtime regression status in `docs/FEATURE-STATUS.md`.

## Android checkpoint

The native Kotlin/Jetpack Compose Android client provides Map, Stations, Favourites, Report, Settings and Help and consumes the same station-only API. The responsive Pixel 10a layout uses the available phone window and previously passed runtime testing with the live 305-station dataset.

The Android ↔ iOS parity audit is recorded in `docs/ANDROID-IOS-PARITY-AUDIT.md`. P1 work now includes a dedicated `/ready` Test Connection, Home ATOM station selection, Home map control/focus, compact last-updated/station count, and filtered-count/clear feedback.

### Verification completed in this checkpoint

- Dedicated Android Test Connection runtime test passed and displayed `Connection OK • 305 confirmed stations`.
- The Home selector/focus correction is commit `24ba858`.
- `./gradlew assembleDebug` passed after pulling that correction on 17 September 2026.
- Runtime test confirmed that selecting a Home ATOM station and returning to Map now centres the map on the selected station.

### Known defect at checkpoint

The Home ATOM station selection list still does **not scroll correctly** with the full station dataset. The searchable/scrollable picker introduced by `24ba858` therefore remains incomplete despite the successful build and successful map-centering test. This is the first Android item to resume; do not mark the Home selector flow fully Tested until scrolling is corrected and rerun.

### Remaining Android parity work

P1 still requires the Home-picker scrolling correction and map-layer selection. P2 remains configurable status colours, distinct Inactive presentation, clustering and mixed-health cluster presentation. Later runtime regression still covers existing Station Detail, filters, favourites, report/share, cache/no-network behaviour and device-size/orientation coverage. Android Help/User Guide restructuring remains a later parity item.

## Cross-platform development rule

User-facing phone features and behaviour changes are implemented on iPhone and Android in the same development cycle unless a documented platform-specific reason prevents this. Build and runtime-test status are tracked separately; success on one platform never implies success on the other.

## Resume point

When Android work resumes, start with the Settings Home-station picker scrolling defect. Preserve the successful Home map-centering behaviour while fixing the picker. After that, complete P1 map-layer parity before moving to P2 presentation/clustering work.

Current Android build command:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew assembleDebug
```

## Documentation rule

`docs/FEATURE-STATUS.md` is authoritative for current feature state. Checkpoint files are historical snapshots. Architecture, API, build/test and in-app User Guides must be updated in the same development cycle as user-visible or operational changes.
