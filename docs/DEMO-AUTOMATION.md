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
Xcode/Xcode command-line tools, XcodeGen and at least one installed iPhone Simulator are required. FFmpeg is optional for MP4 annotation/post-processing:

    brew install xcodegen
    brew install ffmpeg

## Run
From the repository root:

    cd ~/Documents/Xcode/ATOMMonitor
    git pull
    chmod +x scripts/record-demo.sh
    ./scripts/record-demo.sh

The script regenerates the Xcode project, selects an available modern iPhone (preferring iPhone 17 Pro), boots it and waits for readiness, starts `simctl recordVideo`, then runs only `ATOMMonitorDemoUITests.testRecordedFeatureTour` with `xcodebuild test`. The recording is stopped even on test failure and is retained for diagnosis.

Force another installed device with:

    DEVICE="iPhone 17 Pro Max" ./scripts/record-demo.sh

List devices with:

    xcrun simctl list devices available | grep "iPhone"

## Automated tour
The current UI test demonstrates Map, Stations/search, adding a favourite, full station health/technical detail, Favourites, Settings, editable server address and Test Connection, Help, and return to Map. Each major phase emits an `ATOM_DEMO_STEP` activity into the test log. The server test deliberately uses a documentation-only HTTPS hostname in demo mode; a failed connection is a valid demonstration of connection diagnostics and does not affect deterministic station data.

The test launches with `--demo-mode` so it never depends on the production Synology API. The production app continues to use the saved/configured server URL.

## Outputs

    artifacts/ATOMMonitor-Demo-raw.mp4
    artifacts/ATOMMonitor-Demo.mp4
    artifacts/ATOMMonitor-Demo-test.log
    artifacts/DerivedData/

The raw file is the direct Simulator capture. When FFmpeg is installed, the final MP4 receives the automated-demo title overlay and H.264 web-compatible encoding. The test log captures the Xcode/XCUITest result and named feature-tour activities.

## Failure handling
A UI-test failure returns a non-zero exit code but the video and log are retained. This is intentional: the recording can show exactly where the interaction stopped. Inspect:

    tail -100 artifacts/ATOMMonitor-Demo-test.log

and search steps with:

    grep 'ATOM_DEMO_STEP' artifacts/ATOMMonitor-Demo-test.log

## Simulator selection history
The original recorder assumed `iPhone 16 Pro`, which was not installed on the Xcode 26 development Mac. The script now discovers available devices dynamically, preferring iPhone 17 Pro, iPhone 17, iPhone 16e, iPhone Air and iPhone 17 Pro Max before falling back to the first available iPhone. Duplicate model names across installed runtimes are handled by selecting the first matching UDID.

## Test layers
The demo/XCUITest complements rather than replaces server parser/unit tests, Synology live OGN/API integration tests and physical-iPhone testing. In particular, successful demo mode does not prove production DNS/HTTPS reachability, while successful production API tests do not prove all UI interactions.

## Version control
Commit fixtures, UI tests, scripts, annotation definitions, build/test instructions and meaningful failure diagnoses. Do not commit generated MP4s, DerivedData or other disposable build products. The `artifacts/` directory remains ignored.
