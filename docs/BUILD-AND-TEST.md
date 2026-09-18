# ATOM Monitor — Build and Test Guide

Last updated: 17 September 2026

This is the repeatable build/test guide for the server, iPhone and Android clients. Meaningful build/runtime evidence must be captured in Git and `docs/FEATURE-STATUS.md` must be updated as features progress through Implemented, Build passed and Tested.

## Scope invariant

All tests must preserve the product boundary: ATOM Monitor monitors PilotAware ATOM ground-station health only. Do not introduce, capture or persist aircraft identities, positions, tracks or aircraft packet history.

## Repository

Mac development checkout:

```bash
cd ~/Documents/Xcode/ATOMMonitor
git pull
git status --short
```

Synology deployment checkout:

```bash
cd /volume1/docker/ATOMMonitor
git pull
git status --short
```

Use `sudo` for Docker/Compose commands on Synology. Do not use `sudo` for Git.

## Server / Synology

Production Compose publishes the API on host port 8088. DSM reverse proxy exposes HTTPS on `granvillehouse.synology.me:8445`; do not expose 8088 directly to the Internet.

The API runs under Gunicorn. `/health` tests process liveness and `/ready` tests database readiness. The collector is health-gated on `/ready`.

Before recreating the production server, take a consistent SQLite backup using the SQLite backup API or another consistency-safe method; do not blindly copy a live database file.

Deploy/rebuild:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose build
sudo docker compose up -d
sudo docker compose ps
```

Do not print the contents of `server/.env`, and avoid commands/output that expand the private `ATOM_INGEST_TOKEN` into logs or documentation.

LAN checks:

```bash
curl -fsS http://127.0.0.1:8088/health
curl -fsS http://127.0.0.1:8088/ready
curl -fsS http://127.0.0.1:8088/api/v1/stations | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))'
```

Public read checks:

```bash
curl -fsS https://granvillehouse.synology.me:8445/health
curl -fsS https://granvillehouse.synology.me:8445/ready
curl -fsS https://granvillehouse.synology.me:8445/api/v1/stations | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))'
```

The station count is live and can change; compare consistency rather than expecting a hard-coded value.

Public write-boundary regression:

```bash
curl -s -o /dev/null \
  -w 'PUBLIC WRITE WITHOUT TOKEN: HTTP %{http_code}\n' \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  https://granvillehouse.synology.me:8445/api/v1/observations
```

Expected: HTTP 401. Separately inspect API logs to confirm intended collector POSTs are returning 202. Never paste the bearer token into test evidence.

### Server ordering tests

Run the unit suite inside the API image while mounting the test module:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose run --rm \
  -e ATOM_DB=/tmp/atommonitor-test.sqlite3 \
  -v "$PWD/test_app.py:/app/test_app.py:ro" \
  --entrypoint python \
  atom-api \
  -m unittest -v test_app.py
```

Current suite covers stale status/position ordering, valid newer updates, category independence, large-future timestamp rejection, tolerated small future skew and malformed packet-time rejection. Record the actual test count/result rather than hard-coding it into future expectations.

### Restart resilience checkpoint

Record station count and `/ready`, restart/recreate the API in a controlled way, then verify database readiness, station persistence and resumed collector 202 responses. Check `sudo docker stats --no-stream` when evaluating resource behaviour. Do not infer a memory leak or impose arbitrary limits from one sample.

## iPhone build

The iOS project is generated/configured for iOS 17+, iPhone only, automatic signing and Development Team `VNQTGCW476`. Use external DerivedData because File Provider metadata in the repository path has previously caused code-signing problems.

From the repository, regenerate the Xcode project if `project.yml` changed, then build in Xcode or with the established external DerivedData workflow. A source commit is not a passed build.

Physical-iPhone regression should cover Map, Stations, Favourites, Report/share, Settings/Test Connection, Help/User Guide, cached/no-network presentation and Station Detail.

Current Station Detail checks on iPhone:

- effective health icon and matching explanation
- Healthy/back-level presentation where applicable
- record absolute date/time and relative heartbeat/seen/position/technical ages
- station/software, location, system, time and radio sections
- no displayed Uptime, Supply voltage or Frequency correction
- RF correction remains separate
- Google Maps link opens the exact station location with a pin and satellite imagery requested at zoom 18
- normal no-filter refresh does not undo Home map focus

The Google Maps satellite/pin result must be checked on the physical device because final handling can depend on the installed Google Maps app/browser.

## Android build

The Android client is Kotlin/Jetpack Compose, minimum API 26 and compile/target API 37. The verified build toolchain is Android Gradle Plugin 9.4.0, Gradle 9.6.0 and Java 17. It uses the same public server and station-only scope.

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew clean
./gradlew assembleDebug
```

Expected debug APK location:

`app/build/outputs/apk/debug/app-debug.apk`

The Gradle wrapper has now been generated and verified locally, including the wrapper JAR, and is maintained with the project for reproducible command-line builds.

### Android build checkpoint — 17 September 2026

The first confirmed Android debug APK build passed using API 37, Android Gradle Plugin 9.4.0, Gradle 9.6.0 and Java 17. The generated APK was approximately 16 MB. Build evidence is retained in `artifacts/ATOMMonitor-Android-build.log` and `artifacts/ATOMMonitor-Android-kotlin-build.log`.

### Android runtime networking checkpoint — 17 September 2026

The Android client was run in Android Studio on a Pixel 10a emulator using Android 17 / API 37.2. The emulator browser independently reached the public `/ready` and `/api/v1/stations` endpoints successfully. Initial app refresh failed with `android.os.NetworkOnMainThreadException`; Logcat traced the exception to `StationVM.refresh()` because synchronous `HttpURLConnection` work was running on the main/UI coroutine dispatcher.

Commit `b472821` fixes the refresh by moving blocking HTTP work into `withContext(Dispatchers.IO)` while retaining Compose state updates on the main thread. The same change preserves detailed exception logging for future refresh failures. `./gradlew assembleDebug` passed after the change. The rebuilt app then loaded the live public station dataset successfully: 305 stations were shown and map markers rendered. The count is runtime evidence, not a hard-coded expected value.

This passes Android public-server connectivity, live station retrieval, JSON parsing, station count presentation and basic map-data rendering. It does not by itself pass the complete Android regression suite: Station Detail interactions, report/share, favourites, filtering, settings behaviour, cache/no-network behaviour, Google Maps intent and the outstanding parity items still require their own runtime checks.

Android runtime regression should cover the same six product areas as iPhone and the same Station Detail information contract. In particular verify the new Android detail icon/explanation, telemetry sections, omitted unused fields, and Google Maps satellite/pin intent.

Known Android parity work still outstanding as of 17 September 2026: map clustering/mixed cluster presentation, configurable map-icon colours, and Home-relative filtered-map focus. These are tracked explicitly in `FEATURE-STATUS.md` and are not to be treated as complete merely because iOS passes.

## Cross-platform parity rule

Every user-facing phone feature or behaviour change is implemented on both iOS and Android in the same development cycle unless a documented platform-specific reason prevents it. The implementation may use native platform mechanisms, but the user-visible objective should match. Build and runtime status remain independent.

## Evidence and status workflow

For every implementation change:

1. Update `docs/FEATURE-STATUS.md` and affected guides/documentation.
2. Commit implementation/documentation.
3. Build the affected platform(s).
4. Record meaningful build evidence in Git and move status only to `Build passed — runtime test pending`.
5. Run required runtime/regression checks.
6. Record evidence and only then mark the feature `Tested`.

If a later change touches a previously Tested behaviour, return the affected feature to a pending state until the relevant regression check passes again.

Simulator recordings/logs that are final evidence may be tracked. Raw intermediate `*-raw*.mp4` and DerivedData must remain ignored.

## Current evidence

Phase 1 Synology resilience/security evidence is recorded in `docs/PHASE1-TEST-EVIDENCE-2026-09-17.md`. The Android public-server runtime networking checkpoint is recorded above. The feature register is the authoritative current status source; historical checkpoint documents are snapshots and should not be interpreted as overriding it.

## Phase 4 API replication runtime tests — 18 September 2026

On the Synology development/test stack, Phase 4 runtime testing established the following checkpoints: Nginx cutover on host port 8088 preserved PostgreSQL-backed `/ready`; two scaled API replicas were simultaneously healthy; `/ready` and `/api/v1/stations` succeeded through the load balancer; stopping `server-atom-api-1` left reads available through replica 2 and live collector ingestion continued with HTTP 202; restarting replica 1 produced a clean healthy rejoin; force-recreating the scaled API service recreated both replicas, after which both became healthy, Nginx rediscovered the replacement backends, `/ready` succeeded and live observation POSTs again returned HTTP 202.

Detailed command/evidence sequence is retained in `docs/PHASE4-API-REPLICATION.md`. Phase 4 must not be marked fully Tested until the remaining acceptance items and clean-from-scratch runbook update/review are complete.
