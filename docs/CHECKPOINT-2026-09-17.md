# ATOM Monitor checkpoint — 17 September 2026

## Purpose

This checkpoint consolidates the current iPhone, Android, Simulator, documentation and build-tooling state after station reporting/sharing and persistent Xcode signing work. It is the recovery point for continuing development from the state reached on 17 September 2026.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It does not display, record or retain aircraft movements, tracks or aircraft identities. The HTML/CSV report formats preserve this boundary.

## iPhone state

The iPhone application currently provides Map, Stations, Favourites, Report, Settings and Help functionality. The Report summarises the current station dataset by displayed status and PilotAware version and shares a responsive HTML report plus station-level CSV through the standard iOS share sheet.

The HTML includes horizontal bar graphs and exact count tables. The CSV includes station name, displayed status, PilotAware version, station observation timestamps and latitude/longitude. No aircraft fields are present.

The first-attempt share-sheet timing defect was corrected by presenting the activity controller from a populated share payload. The user confirmed the corrected report/share behaviour is good on the physical iPhone on 17 September 2026.

## Xcode signing

`ios/project.yml` declares automatic signing with Development Team `VNQTGCW476` for the application and UI-test targets. The user regenerated the Xcode project and confirmed that the recurring manual Signing → Team selection problem is fixed.

`project.yml` is the authoritative XcodeGen source.

## Simulator automation

`ios/ATOMMonitorUITests/ATOMMonitorDemoUITests.swift` now covers the current navigation and Report functionality. Two automation issues were found and corrected during checkpoint testing: the refresh-button selector was made resilient, and compact-width iPhone `TabView` behaviour is handled by selecting Settings and Help through **More** when they are not direct tab-bar buttons.

The user reran `./scripts/record-demo.sh` after those corrections on 17 September 2026. The script completed with:

```text
PASS: automated ATOM Monitor feature tour completed.
```

The successful run generated:

```text
artifacts/ATOMMonitor-Demo.mp4
artifacts/ATOMMonitor-Demo-test.log
```

The intermediate raw recording is `artifacts/ATOMMonitor-Demo-raw.mp4`. The final MP4 and UI-test log are the meaningful milestone evidence. Simulator Report coverage is **Tested** in `docs/FEATURE-STATUS.md`.

## Android state

Android source has been advanced toward the current report/navigation behaviour. The source includes:

- Map, Stations, Favourites, Report, Settings and Help navigation;
- compact `Stations` heading and station count in refresh/network status;
- Report totals and counts by displayed status and PilotAware version;
- responsive HTML horizontal bar graphs and exact count tables;
- station-level CSV export;
- native Android `ACTION_SEND_MULTIPLE` share chooser;
- `FileProvider` and cache-path configuration for safe temporary HTML/CSV sharing;
- local Help text describing Report and the station-only scope.

The Android implementation remains **Implemented — build pending**. It has not yet had a confirmed Gradle build or emulator/device runtime test. This checkpoint deliberately records that gap rather than treating Android parity as Tested.

## Checkpoint verification state

### Passed

- iOS source/build checkpoint for the current feature set.
- Persistent XcodeGen signing configuration verified by regeneration.
- Physical-iPhone Report and native sharing accepted, including first-attempt sharing and HTML bar graphs.
- Automated iOS Simulator feature tour passed after refresh-selector and More-tab corrections.
- Feature/status and build/test documentation synchronized with the successful Simulator result.

### Still pending after this checkpoint

Android requires its first clean Gradle build and emulator/device runtime test:

```sh
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew clean
./gradlew assembleDebug
```

Then verify Report totals/status/version counts, first-attempt share chooser, HTML bar graphs, CSV contents, station-only scope, navigation and cache/favourites behaviour. If the Gradle wrapper is not present locally, generate it using the Gradle version accepted by Android Studio for the current AGP configuration and commit the wrapper artefacts.

## Known engineering work

The following remain open roadmap work and are intentionally visible at this checkpoint: refresh serialization, stale-packet overwrite protection, public API write-boundary hardening, server-specific cache ownership, automated Synology database backup/recovery, Android clustering/colour parity and authoritative station bootstrap/cadence validation.

## Resume point

When development resumes from this checkpoint:

1. Pull the current `main` branch.
2. Treat `docs/FEATURE-STATUS.md` as the authoritative feature/status register.
3. Treat `docs/BUILD-AND-TEST.md` as the reproducible verification record.
4. Begin with the Android clean build/runtime checkpoint unless a higher-priority server correctness/security item is deliberately selected.
5. Preserve the project scope invariant: ground-station operational health only; no aircraft movement, tracking or identity data.

## Checkpoint rule

This is a solid source/documentation/iOS checkpoint and a safe recovery point. It does **not** upgrade Android's unbuilt implementation to Tested. Future changes must continue to update feature objective/status, affected documentation and build/test evidence in Git in the same development cycle.
