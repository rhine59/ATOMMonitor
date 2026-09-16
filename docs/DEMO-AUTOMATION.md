# ATOM Monitor automated simulator demonstration and recorder

## Purpose
ATOM Monitor includes a repeatable XCUITest-driven Simulator demonstration that records an MP4 while exercising the app. Demo mode is deterministic and independent of the live OGN/Synology service.

## Scope
The recording contains ATOM ground-station health/status only: no aircraft identities, positions, tracks, speeds or movements.

## Components
- `ios/ATOMMonitor/Resources/demo-stations.json` — deterministic Healthy, Warning, No recent heartbeat, Unknown, missing-telemetry and missing-position examples.
- `--demo-mode` — selects fixture data instead of the production API.
- `ios/ATOMMonitorUITests/ATOMMonitorDemoUITests.swift` — XCUITest feature tour.
- `scripts/record-demo.sh` — XcodeGen, Simulator selection/boot, XCUITest execution, screen recording, logging and MP4 post-processing.
- `artifacts/` — ignored generated video, test log and DerivedData.

## Requirements
Xcode/Xcode command-line tools, XcodeGen and at least one installed iPhone Simulator are required. FFmpeg is optional for MP4 post-processing:

    brew install xcodegen
    brew install ffmpeg

`drawtext` is an optional FFmpeg filter and is not present in every Homebrew/build configuration. The recorder now detects it rather than assuming it exists.

## Run
From the repository root:

    cd ~/Documents/Xcode/ATOMMonitor
    git pull
    chmod +x scripts/record-demo.sh
    ./scripts/record-demo.sh

The script regenerates the Xcode project, selects an available modern iPhone (preferring iPhone 17 Pro), boots it and waits for readiness, starts `simctl recordVideo`, then runs only `ATOMMonitorDemoUITests.testRecordedFeatureTour` with `xcodebuild test`. The recording is stopped even on test failure and is retained for diagnosis.

Force another installed device with:

    DEVICE="iPhone 17 Pro Max" ./scripts/record-demo.sh

## Automated tour
The current UI test demonstrates Map, Stations/search, adding a favourite, full station health/technical detail, Favourites, Settings, editable server address and Test Connection, Help, and return to Map. Each major phase emits an `ATOM_DEMO_STEP` activity into the test log. The server test deliberately uses a documentation-only HTTPS hostname in demo mode; a failed connection is a valid demonstration of connection diagnostics and does not affect deterministic station data.

## Outputs

    artifacts/ATOMMonitor-Demo-raw.mp4
    artifacts/ATOMMonitor-Demo.mp4
    artifacts/ATOMMonitor-Demo-test.log
    artifacts/DerivedData/

The raw file is direct Simulator capture. If FFmpeg includes `drawtext`, the final H.264 MP4 receives the automated-tour title overlay. If FFmpeg is installed without `drawtext`, the script creates the web-compatible H.264 MP4 without the text overlay. If FFmpeg transcoding itself fails, or FFmpeg is absent, the valid raw recording is copied to the final MP4 path. Presentation post-processing must never discard a successful Simulator recording.

## Recorded failure: FFmpeg `drawtext` unavailable
On 16 September 2026 the first XCUITest recorder run produced a valid 1206×2622 H.264 Simulator recording but FFmpeg terminated with:

    No such filter: 'drawtext'
    Error opening output file .../ATOMMonitor-Demo.mp4

The raw recording was only 2.87 seconds long, which also indicates that the UI test itself stopped very early; that is a separate issue to diagnose from `ATOMMonitor-Demo-test.log`. The recorder was hardened so missing `drawtext` can no longer mask the underlying UI-test result or prevent a final MP4 being preserved.

## Diagnosing UI-test failures
A UI-test failure returns a non-zero exit code but video and log remain. Inspect:

    tail -120 artifacts/ATOMMonitor-Demo-test.log

and:

    grep -E 'ATOM_DEMO_STEP|error:|failed|Assertion' artifacts/ATOMMonitor-Demo-test.log

A recording of only a few seconds normally means XCUITest failed during launch or its first interaction; the FFmpeg stage happens after recording and cannot itself explain the short raw capture.

## Simulator selection history
The original recorder assumed `iPhone 16 Pro`, which was not installed on the Xcode 26 development Mac. The script now discovers available devices dynamically, preferring iPhone 17 Pro, iPhone 17, iPhone 16e, iPhone Air and iPhone 17 Pro Max before falling back to the first available iPhone.

## Test layers
Demo/XCUITest complements server parser/unit tests, Synology live OGN/API integration tests and physical-iPhone testing. Successful demo mode does not prove production DNS/HTTPS reachability, and successful production API tests do not prove every UI interaction.

## Version control
Commit fixtures, UI tests, scripts, annotation definitions, build/test instructions and meaningful failure diagnoses. Do not commit generated MP4s, DerivedData or disposable build products. `artifacts/` remains ignored.
