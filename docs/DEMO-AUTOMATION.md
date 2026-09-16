# ATOM Monitor automated simulator demonstration and recorder

## Purpose

ATOM Monitor includes a repeatable demonstration/test harness for exercising the iPhone user interface in the iOS Simulator and recording the result as an MP4. The design deliberately separates live production data from demonstration data so recordings are repeatable and do not depend on the state of the OGN network or Synology server.

The same deterministic data and, ultimately, the same XCUITest workflows are intended to provide regression testing as the application evolves.

## Scope and data safety

ATOM Monitor monitors PilotAware ATOM **ground-station health and technical status only**. Demo mode follows exactly the same scope. It contains no aircraft identities, aircraft positions, aircraft tracks, packet histories, speeds or movements.

## Architecture

The demonstration system has four layers:

1. **Deterministic station simulator** — `ios/ATOMMonitor/Resources/demo-stations.json`.
2. **Demo launch mode** — application argument `--demo-mode` selects the fixture repository rather than the production REST API.
3. **Simulator recorder** — `scripts/record-demo.sh` builds, installs, launches and records the app.
4. **UI driver / regression layer** — the recorder will invoke `scripts/run-demo-ui.sh` when present. The production implementation should use XCUITest accessibility identifiers rather than screen coordinates.

Normal application launches are unaffected: without `--demo-mode`, the app uses the configured production API (currently the Synology REST service).

## Deterministic station fixture

`demo-stations.json` deliberately contains examples that exercise the important display paths:

- Healthy station with complete technical telemetry.
- Warning station.
- No recent heartbeat station.
- Unknown station.
- Missing optional telemetry so the UI must display `Not reported`.
- Station with no coordinates so list/detail behaviour can be tested independently of Map display.

The fixture includes ground-station fields such as position, altitude, heartbeat/status timestamps, PilotAware and receiver versions, CPU load and temperature, RAM, NTP values, RF corrections/quality, voltage and uptime.

## Requirements

The Mac needs:

- Xcode and Xcode command-line tools.
- At least one installed iPhone Simulator runtime/device.
- XcodeGen (`brew install xcodegen`) if it is not already installed.
- FFmpeg (`brew install ffmpeg`) for annotation rendering. Recording itself can proceed without FFmpeg.

Check available iPhone simulators with:

    xcrun simctl list devices available | grep "iPhone"

## Automatic simulator selection

The first recorder version assumed an `iPhone 16 Pro`. On the development Mac this failed because that simulator was not installed. The installed Xcode 26 simulator set included iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air, iPhone 17, iPhone 16e and iPhone 17e devices, with some models appearing in more than one installed runtime.

`record-demo.sh` was therefore changed to discover the installed Simulator devices dynamically. If `DEVICE` is not supplied it currently prefers, in order:

1. iPhone 17 Pro
2. iPhone 17
3. iPhone 16e
4. iPhone Air
5. iPhone 17 Pro Max
6. otherwise the first available iPhone Simulator

It matches a device name exactly and uses the first available UDID for that name, which makes duplicate models across installed runtimes harmless.

The script prints the selected model and UDID before continuing, for example:

    Using Simulator: iPhone 17 Pro (973A79C9-079E-4B0C-ADEF-00D6D6CB32CA)

A particular simulator can still be requested explicitly:

    DEVICE="iPhone 17 Pro Max" ./scripts/record-demo.sh

If that named simulator is unavailable, the script prints the available iPhones and exits instead of silently using a different model.

## Running the demonstration recorder

From the repository root:

    cd ~/Documents/Xcode/ATOMMonitor
    git pull
    chmod +x scripts/record-demo.sh
    ./scripts/record-demo.sh

The script performs the following sequence:

1. Creates `artifacts/` if necessary.
2. Regenerates `ios/ATOMMonitor.xcodeproj` using XcodeGen.
3. Discovers/selects an available iPhone Simulator.
4. Boots the selected simulator.
5. Opens Simulator.app and waits for boot completion with `simctl bootstatus`.
6. Builds ATOM Monitor for that exact simulator using `xcodebuild`.
7. Locates and installs the generated `ATOMMonitor.app`.
8. Terminates an existing instance if necessary.
9. Starts H.264 screen capture using `xcrun simctl io ... recordVideo`.
10. Launches `uk.co.rhine59.ATOMMonitor` with `--demo-mode`.
11. Invokes `scripts/run-demo-ui.sh` if an executable driver exists; until that driver is implemented, it records a deterministic 20-second demo-mode launch.
12. Stops the recording cleanly.
13. If FFmpeg is installed, renders an annotated H.264 MP4; otherwise it preserves/copies the raw recording.

The script also installs a shell trap while recording so an interrupted run is less likely to leave `recordVideo` running.

## Output files

Generated files are written below `artifacts/`:

    artifacts/
      ATOMMonitor-Demo-raw.mp4
      ATOMMonitor-Demo.mp4
      DerivedData/

`ATOMMonitor-Demo-raw.mp4` is the direct Simulator capture. `ATOMMonitor-Demo.mp4` is the post-processed H.264 output. At the current development stage the annotation layer adds a demonstration title; timed explanatory annotations will be expanded alongside the UI driver.

The complete `artifacts/` directory is intentionally ignored by Git. Generated video and Xcode build products should not bloat the source repository. The scripts, fixtures, tests, annotation definitions and documentation **are** version controlled.

## Intended complete automated tour

The completed XCUITest/UI driver should exercise the user-visible application in a repeatable order: Map launch/loading and clustering; cluster zoom; `Find` search; direct selection of a healthy station; full station telemetry; Warning and No recent heartbeat states; missing fields displayed as `Not reported`; Stations list; adding and viewing Favourites; Settings and home-station selection; Help; and return to Map.

Each phase should have a timed annotation explaining what the viewer is seeing. UI interaction must be driven through accessibility identifiers/XCUITest rather than hard-coded screen coordinates so the demonstration remains reliable on different iPhone screen sizes.

## Relationship to production testing

Demo mode is not a replacement for the live integration tests against the Synology/OGN collector. It tests deterministic iPhone presentation and interaction. The project therefore has complementary test layers:

- server/parser/unit tests for data handling;
- Synology live integration tests for the OGN-to-registry/API pipeline;
- deterministic Simulator/XCUITest for iPhone behaviour;
- physical-iPhone testing for real device networking, layout and permissions.

A successful demo-mode recording does not prove that the production API or OGN feed is reachable; likewise a healthy production API does not prove every iPhone UI path works.

## Troubleshooting

### `Simulator 'iPhone 16 Pro' not found`

This was the failure produced by the original recorder on the Xcode 26 development Mac. Pull the current script: it no longer assumes iPhone 16 Pro.

    cd ~/Documents/Xcode/ATOMMonitor
    git pull
    ./scripts/record-demo.sh

### No simulator is found

Run:

    xcrun simctl list devices available | grep "iPhone"

If no iPhones are shown, install an iOS Simulator runtime/device through Xcode.

### Force a known device

    DEVICE="iPhone 17 Pro" ./scripts/record-demo.sh

### XcodeGen is missing

    brew install xcodegen

### FFmpeg is missing

    brew install ffmpeg

Without FFmpeg, the raw recording is still retained but the full annotation/post-processing stage is not available.

### Recording is static after launch

At the current milestone this is expected if `scripts/run-demo-ui.sh` has not yet been implemented. The recorder intentionally detects that condition and records a 20-second deterministic launch. The next milestone is the XCUITest/accessibility-driven UI exerciser.

## Version-control policy

All meaningful changes to this facility are committed with the rest of ATOM Monitor. In particular, keep the following in Git:

- demo fixtures;
- demo-mode application code;
- recorder and UI-driver scripts;
- XCUITest code and accessibility identifiers;
- annotation definitions/timelines;
- build/test instructions;
- meaningful failure diagnoses and design decisions.

Do not commit generated MP4s, DerivedData, or other disposable build products.
