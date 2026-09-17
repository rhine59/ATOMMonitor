# ATOM Monitor checkpoint — 17 September 2026

## Purpose

This checkpoint consolidates the current iPhone, Android, Simulator, documentation and build-tooling state after station reporting/sharing and persistent Xcode signing work.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It does not display, record or retain aircraft movements, tracks or aircraft identities. The HTML/CSV report formats preserve this boundary.

## iPhone state

The iPhone application currently provides Map, Stations, Favourites, Report, Settings and Help functionality. The Report summarises the current station dataset by displayed status and PilotAware version and shares a responsive HTML report plus station-level CSV through the standard iOS share sheet.

The HTML includes horizontal bar graphs and exact count tables. The CSV includes station name, displayed status, PilotAware version, station observation timestamps and latitude/longitude. No aircraft fields are present.

The first-attempt share-sheet timing defect was corrected by presenting the activity controller from a populated share payload. The user confirmed the corrected report/share behaviour is good on the physical iPhone on 17 September 2026.

## Xcode signing

`ios/project.yml` now declares automatic signing with Development Team `VNQTGCW476` for the application and UI-test targets. The user regenerated the Xcode project and confirmed that the recurring manual Signing → Team selection problem is fixed.

`project.yml` is the authoritative XcodeGen source. A locally regenerated `ATOMMonitor.xcodeproj` should be committed if it differs from the repository copy so the generated artefact remains synchronized.

## Simulator automation

`ios/ATOMMonitorUITests/ATOMMonitorDemoUITests.swift` has been updated to:

- expect the current compact `Stations` navigation title;
- visit the Report area;
- verify Total stations, Status and PilotAware versions summary labels;
- verify the Share report control exists.

The updated Simulator tour is **not yet rerun** at this checkpoint. Run `./scripts/record-demo.sh` after pulling this checkpoint and commit the resulting meaningful `.log`/`.mp4` milestone artefacts if the run succeeds.

## Android state

Android source has been advanced toward the current report/navigation behaviour. The source now includes:

- Map, Stations, Favourites, Report, Settings and Help navigation;
- compact `Stations` heading and station count in refresh/network status;
- Report totals and counts by displayed status and PilotAware version;
- responsive HTML horizontal bar graphs and exact count tables;
- station-level CSV export;
- native Android `ACTION_SEND_MULTIPLE` share chooser;
- `FileProvider` and cache-path configuration for safe temporary HTML/CSV sharing;
- local Help text describing Report and the station-only scope.

The Android implementation remains **Implemented — build pending**. It has not yet had a confirmed Gradle build or emulator/device runtime test. Do not call Android report parity Tested until that evidence exists.

## Required verification to close this as a solid tested checkpoint

### iOS Simulator

```sh
cd ~/Documents/Xcode/ATOMMonitor
git pull
./scripts/record-demo.sh
```

Expected: the UI test reaches Map, Stations, Favourites, Report, Settings and Help without assertion failure, and the Report summary/share control checks pass.

### Android

```sh
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew clean
./gradlew assembleDebug
```

Then install/run on an emulator or device and verify Report totals/status/version counts, first-attempt share chooser, HTML bar graphs, CSV contents, and station-only scope.

If the Gradle wrapper has not yet been generated locally, generate and commit the wrapper first using the Gradle version accepted by Android Studio for the current AGP configuration.

## Known engineering work deliberately not hidden by this checkpoint

The following remain open roadmap work rather than checkpoint blockers for the already-working iPhone report feature: refresh serialization, stale-packet overwrite protection, public API write-boundary hardening, server-specific cache ownership, automated Synology database backup/recovery, Android clustering/colour parity and authoritative station bootstrap/cadence validation.

## Checkpoint rule

This document records implementation state and known verification gaps; it does not upgrade untested work to Tested. `docs/FEATURE-STATUS.md` remains authoritative for feature status.
