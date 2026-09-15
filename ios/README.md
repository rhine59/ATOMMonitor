# ATOM Monitor iOS

Native SwiftUI iPhone client for browsing PilotAware ATOM ground-station health.

## Prototype 0.1

Implemented:

- SwiftUI application shell and tab navigation.
- MapKit map as the home screen.
- Health-coded station markers with symbols as well as colour.
- Map station selection and summary card.
- Search by station name.
- Searchable station list.
- Detailed Health, Location, System, Time and Radio sections.
- `Not reported` handling for absent telemetry.
- Async observable station store with loading/error state.
- Replaceable `StationRepository` abstraction.
- Bundled JSON fixture provider for development before the REST API is live.

No aircraft map, aircraft tracking, traffic display or flight playback belongs in this application.

## Requirements

- Xcode 26 or compatible current Xcode.
- iOS 17.0+ deployment target.
- XcodeGen to generate the `.xcodeproj` from `project.yml`.
- No third-party iOS runtime libraries.

Install XcodeGen with Homebrew if necessary:

```bash
brew install xcodegen
```

Then:

```bash
git clone https://github.com/rhine59/ATOMMonitor.git
cd ATOMMonitor/ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

Select an iPhone simulator or signing team/device and build normally.

## Structure

```text
ATOMMonitor/
├── ATOMMonitorApp.swift
├── Models/
│   └── ATOMStation.swift
├── Services/
│   └── StationRepository.swift
├── ViewModels/
│   └── StationStore.swift
├── Views/
│   ├── ContentView.swift
│   ├── StationMapView.swift
│   ├── StationListView.swift
│   └── StationDetailView.swift
└── Resources/
    └── stations.json
```

## Fixture-data warning

`stations.json` exists to exercise the application architecture. PWMalham uses the limited reference information established during project research. Other fixture station coordinates are development placeholders and their health is intentionally `Unknown`; they are not an authoritative ATOM registry.

## Next integration

Implement `APIStationRepository` against the planned ATOMMonitor REST API without changing the views. The production server will supply the persistent station registry and current health snapshots.

## UI principles

The map remains the primary navigation surface. Stations must remain visible when their heartbeat disappears. Health must never depend on colour alone, missing telemetry is `Not reported`, Dynamic Type and safe areas should be respected, and device location remains optional.
