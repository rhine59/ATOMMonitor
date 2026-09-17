# ATOM Monitor — Checkpoint — 17 September 2026

This checkpoint records the project state after Phase 1 server hardening, public HTTPS deployment, station-state ordering protection and the latest iOS/Android Station Detail work. `docs/FEATURE-STATUS.md` remains the authoritative live status register.

## Product boundary

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It does not display, record or retain aircraft movements, tracks, aircraft identities or aircraft packet history.

## Server state

The production service runs on the Synology NAS using Docker Compose. The Flask API is served by Gunicorn 23.0.0 with two workers and two threads per worker. The collector waits for API readiness. Containers use restart-unless-stopped, bounded JSON logs and graceful stop handling.

`GET /health` is a cheap process-liveness endpoint. `GET /ready` checks SQLite and returns the current confirmed-station count. The persistent registry has been retained across controlled API restart/recreate testing.

Normal public reads use `https://granvillehouse.synology.me:8445/` through DSM reverse proxy and a valid TLS certificate. Host port 8088 is retained for LAN diagnostics and is not intended for direct Internet exposure.

Observation ingestion is authenticated with a bearer token supplied locally through ignored `server/.env`. Intended collector writes have returned HTTP 202 while an unauthenticated public POST returned HTTP 401. The secret itself is not committed.

Stale-packet protection orders position, technical status and heartbeat independently. Older observations cannot overwrite newer state in their category. Explicit malformed packet times and packet clocks more than five minutes ahead of receive time are rejected. The test suite covering stale and future timestamps passed, and a live PWAachen position nearly 12 hours in the future was rejected while its valid heartbeat continued.

Phase 1 test evidence is recorded in `docs/PHASE1-TEST-EVIDENCE-2026-09-17.md`.

## iPhone state

The iOS SwiftUI app uses the public HTTPS service by default and provides Map, Stations, Favourites, Report, Settings and Help. It has persistent station caching/favourites, shared health/version filters, configurable Inactive threshold, report/share, configurable map presentation and Home-station behaviour.

Test Connection uses `/ready` and reports the confirmed station count. This has passed on a physical iPhone.

Recent Station Detail changes are implemented but require a fresh build/runtime regression before being marked Tested. Detail now shows the effective status icon and explanation, useful station telemetry, an absolute record date/time plus relative observation ages, and a Google Maps link requesting satellite imagery with a pin at the exact station coordinates. Uptime, supply voltage and frequency correction are intentionally not displayed; RF correction remains a separate field.

A recent Map refresh correction ensures a no-filter station reload does not reset Home focus to the UK; this also warrants regression with the current build.

## Android state

The native Kotlin/Jetpack Compose Android client provides Map, Stations, Favourites, Report, Settings and Help and consumes the same station-only API.

Station Detail has now been brought up to parity with the latest iPhone detail objective: status icon/explanation including back-level presentation, station/software, location/system/time/radio telemetry, absolute and relative timestamps, omission of the unused uptime/voltage/frequency-correction display fields, and Google Maps satellite/pin access.

Android remains build-pending until a real Gradle build succeeds. Older parity gaps remain explicit: map clustering/mixed cluster presentation, configurable map-icon colours, and Home-relative filtered-map focus.

## Cross-platform development rule

User-facing phone features and behaviour changes are implemented on iPhone and Android in the same development cycle unless a documented platform-specific reason prevents this. Build and runtime-test status are tracked separately; success on one platform never implies success on the other.

## Current build/test commands

Android:

```bash
cd ~/Documents/Xcode/ATOMMonitor
git pull
cd android
./gradlew clean
./gradlew assembleDebug
```

Server ordering suite on Synology:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose run --rm \
  -e ATOM_DB=/tmp/atommonitor-test.sqlite3 \
  -v "$PWD/test_app.py:/app/test_app.py:ro" \
  --entrypoint python \
  atom-api \
  -m unittest -v test_app.py
```

See `docs/BUILD-AND-TEST.md` for the complete current procedure.

## Next checkpoints

1. Build the current Android source and correct any Kotlin/Compose errors before runtime testing.
2. Build/test the current iPhone Station Detail and Google Maps satellite/pin behaviour, including Home-focus regression.
3. Close the remaining Android parity gaps rather than allowing iOS-only user-facing functionality to accumulate.
4. Continue resilience work with repeatable SQLite backup/recovery, followed later by PostgreSQL before API replication/load balancing.

## Documentation rule

`docs/FEATURE-STATUS.md` is authoritative for current feature state. Checkpoint files are historical snapshots. Architecture, API, build/test and in-app User Guides must be updated in the same development cycle as user-visible or operational changes.
