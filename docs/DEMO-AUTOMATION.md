# ATOM Monitor automated simulator demonstration and recorder

## Purpose
ATOM Monitor includes a repeatable XCUITest-driven Simulator demonstration that records an MP4 while exercising the app. Demo mode is deterministic and independent of the live OGN/Synology service.

## Scope
The recording contains ATOM ground-station health/status only: no aircraft identities, positions, tracks, speeds or movements.

## Components
- `scripts/prepare-ios-demo-fixture.py` — downloads and selects 100 real geolocated stations immediately before recording.
- `ios/ATOMMonitor/Resources/demo-stations-live.json` — generated ignored snapshot bundled into that recording build.
- `--demo-mode` — selects fixture data instead of the production API.
- `ios/ATOMMonitorUITests/ATOMMonitorDemoUITests.swift` — XCUITest feature tour.
- `ios/project.yml` — defines both app/UI-test targets **and the shared ATOMMonitor scheme test action**.
- `scripts/record-demo.sh` — XcodeGen, Simulator boot, XCUITest, screen recording, logging and MP4 processing.
- `artifacts/` — ignored generated outputs.

## Requirements
Xcode/Xcode command-line tools, XcodeGen and at least one installed iPhone Simulator are required. FFmpeg is optional. `drawtext` is optional even when FFmpeg is installed; the recorder detects it and falls back safely.

## Run

    cd ~/Documents/Xcode/ATOMMonitor
    git pull
    chmod +x scripts/record-demo.sh
    ./scripts/record-demo.sh

The script regenerates the Xcode project, selects an available modern iPhone (preferring iPhone 17 Pro), boots it, starts `simctl recordVideo`, and runs `ATOMMonitorDemoUITests.testRecordedFeatureTour` with `xcodebuild test`.

Force another device with:

    DEVICE="iPhone 17 Pro Max" ./scripts/record-demo.sh

## XcodeGen scheme requirement
Defining a `bundle.ui-testing` target is not sufficient by itself. The generated `ATOMMonitor` scheme must explicitly contain a test action. `project.yml` therefore has a top-level `schemes: ATOMMonitor:` declaration whose build action includes the app and UI-test bundle and whose test action names `ATOMMonitorUITests`.

After `xcodegen generate`, this can be sanity-checked with:

    cd ios
    xcodebuild -project ATOMMonitor.xcodeproj -scheme ATOMMonitor -showdestinations

and the recorder's `xcodebuild test` command must no longer report `Scheme ATOMMonitor is not currently configured for the test action`.

## Automated tour
The UI test demonstrates Map refresh/layers/Home, Stations search/refresh/detail/favourite, Favourites, Report category drill-down and HTML/CSV share sheet, Settings and back-level highlighting, alphabetic More navigation, the complete colour legend, deterministic Admin container inventory and guarded scale 2→3, Help, Feedback controls, About/licensing, and return to Map. Major phases emit `ATOM_DEMO_STEP` activities into the log. Demo data and Admin scaling are simulated locally and never depend on or mutate the production Synology service.

## Outputs

    artifacts/ATOMMonitor-Demo-<timestamp>-raw.mp4
    artifacts/ATOMMonitor-Demo-<timestamp>.mp4
    artifacts/ATOMMonitor-Demo-<timestamp>-test.log
    artifacts/ATOMMonitor-Demo-<timestamp>.xcresult
    /tmp/ATOMMonitor-DerivedData/

If FFmpeg has `drawtext`, the final H.264 MP4 receives a title overlay. Without it, a web-compatible H.264 MP4 is still generated. If post-processing fails, the raw recording is preserved/copied rather than discarded.

## Recorded failures and fixes — 16 September 2026
The first XCUITest recorder run produced a valid 1206×2622 H.264 recording of only 2.87 seconds. Two independent failures were identified.

**FFmpeg:** `No such filter: 'drawtext'`. The recorder now probes the filter and falls back without text.

**Xcode test launch:** the test log reported:

    xcodebuild: error: Scheme ATOMMonitor is not currently configured for the test action.

The UI-test target existed, but the XcodeGen-generated app scheme had no test action. `ios/project.yml` now explicitly defines the `ATOMMonitor` scheme and includes `ATOMMonitorUITests` in its test action. This explains the 2.87-second recording: Xcode never launched the UI test.

## Diagnosing later failures
The recorder preserves the video/log and returns non-zero when XCUITest fails. Inspect:

    grep -E 'ATOM_DEMO_STEP|error:|failed|Assertion|Test Case' artifacts/ATOMMonitor-Demo-test.log | tail -100

or:

    tail -150 artifacts/ATOMMonitor-Demo-test.log

## Test layers
Demo/XCUITest complements server/parser tests, Synology live OGN/API integration and physical-iPhone testing. Successful demo mode does not prove production DNS/HTTPS reachability.

## Version control
Commit fixtures, tests, scripts, annotation definitions, build/test instructions and meaningful failure diagnoses. Do not commit generated MP4s, DerivedData or disposable build products. `artifacts/` remains ignored.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe current server acceptance mechanism is the committed Phase 1–4 plus service/API suite, which has passed on the Synology. Demo automation remains supplementary presentation/testing material and must not be treated as a substitute for the acceptance runners. See `CHECKPOINT-2026-09-18.md`.\n

## Complete current-function tour — 3 October 2026

The recorder now assigns a timestamp automatically, retains the Xcode result bundle, and covers the full current navigation/function set. Admin uses an explicit `--demo-mode` fixture containing PostgreSQL, Nginx, collector, two API replicas and both Admin services. The scale demonstration changes only this in-memory fixture. Camera QR capture, Face ID, external Maps links, live feedback delivery and real Docker mutation remain physical-device/live-service acceptance items rather than Simulator recording actions.


## 100-station live snapshot

By default the recorder downloads the current public station endpoint and selects exactly 100 real geolocated stations, evenly sampled after geographic sorting. Their real names, coordinates, health, software versions, timestamps and telemetry are retained. The generated JSON is ignored by Git and frozen for the duration of the build/recording, so the dataset cannot change midway through the tour.

Use a different count or endpoint with `ATOM_DEMO_STATION_COUNT` and `ATOM_DEMO_STATIONS_URL`. Set `ATOM_DEMO_USE_EXISTING_FIXTURE=1` only when intentionally reusing an already generated snapshot.


The live endpoint contains ground-station operational data only. The snapshot generator rejects non-array responses and requires the requested number of geolocated station records.
