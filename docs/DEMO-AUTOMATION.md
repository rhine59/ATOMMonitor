# ATOM Monitor automated simulator demonstration

This harness produces a repeatable Simulator recording without depending on the live OGN feed or Synology server.

## Safety and scope

Demo mode contains ATOM ground-station health/status records only. It contains no aircraft identities, positions, tracks or movements.

## Demo mode

Launch argument `--demo-mode` selects `demo-stations.json` instead of the production REST API. The fixture deliberately includes Healthy, Warning, No recent heartbeat, Unknown, missing technical telemetry, and a station with no coordinates.

Normal app launches remain unchanged and use the configured Synology API.

## Record

Requirements: Xcode/Xcode command-line tools, XcodeGen, an installed iPhone Simulator. FFmpeg is optional but required for annotation rendering.

Run from repository root:

    ./scripts/record-demo.sh

Override the default simulator if required:

    DEVICE="iPhone 15 Pro" ./scripts/record-demo.sh

Outputs are written to `artifacts/`:

- `ATOMMonitor-Demo-raw.mp4` — direct Simulator capture.
- `ATOMMonitor-Demo.mp4` — annotated H.264 MP4 when FFmpeg is available.
- `DerivedData/` — disposable build products.

## Automated UI exercise

The recorder is deliberately split into three layers: deterministic fixture data, screen recording, and UI driving. `record-demo.sh` automatically invokes `scripts/run-demo-ui.sh` when that executable exists. This allows the UI driver to evolve independently from video capture.

The intended scripted tour is: launch Map; demonstrate clustering; search; open a healthy station and full telemetry; close; show Warning; show No recent heartbeat; demonstrate Not reported values; Stations; Favourites; Settings/home station; Help; return to Map.

The next UI-driver implementation should use XCUITest accessibility identifiers rather than screen coordinates so it remains reliable across iPhone screen sizes.

## Production regression use

The deterministic fixture is also intended for XCUITest regression tests. Simulator automation complements rather than replaces testing on a physical iPhone.
