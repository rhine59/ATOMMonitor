# ATOM Monitor

ATOM Monitor is an iPhone application and supporting server for monitoring the operational health and technical details of PilotAware ATOM ground stations.

## Project goal

The primary user experience is a map containing all known PilotAware ATOM stations. A user can pan, zoom, search for, and select a station, then open a detail view showing the station's current health and available technical information.

The application is deliberately **not an aircraft tracker**. It will not display, persist, or analyse aircraft positions. Aircraft traffic received by an ATOM station is outside the scope of this project.

## Prototype 0.1

A native SwiftUI/MapKit prototype now lives under `ios/`. It implements the map-first experience, station markers with textual/symbol health cues, station search, a station list, summary card, detailed health/location/system/time/RF views, loading/error states, and a replaceable `StationRepository` data layer.

The prototype currently uses bundled fixture JSON. PWMalham contains the limited reference data established during research; other fixture stations are deliberately `Unknown` where live health data has not been established. Fixture coordinates other than PWMalham are development placeholders and must not be treated as authoritative station-registry data.

Generate the Xcode project with XcodeGen:

```bash
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

The deployment target is iOS 17.0. No third-party iOS runtime dependencies are required.

## Core behaviour

- Open directly to a map of known ATOM stations.
- Keep stations on the map even when they stop reporting; an unhealthy station must not simply disappear.
- Use clear health states: Healthy, Warning, No recent heartbeat, and Unknown.
- Tap a map marker for a compact station summary, then navigate to full details.
- Search for a station by name.
- Show location, altitude, heartbeat/status age, software/system, timing/NTP, and RF information when reported.
- Store historical station-health observations later so trends can be investigated.
- Treat missing values as `Not reported`; never reinterpret absent telemetry as zero.
- Use PWMalham as the initial reference station during development.

## Proposed production architecture

```text
OGN APRS receiver-status feed
            |
            v
   Synology Docker host
   +-------------------+
   | OGN collector     |
   | ATOM classifier   |
   | health parser     |
   | station registry  |
   | history database  |
   | REST API          |
   +---------+---------+
             |
          HTTPS/JSON
             |
             v
       iPhone / SwiftUI
```

The preferred candidate live source is the OGN APRS receiver/status stream. PilotAware sources may supplement PilotAware-specific metadata where appropriate. The server will maintain a persistent station registry so a station remains visible when its heartbeat disappears.

## Repository documentation

The `docs/` directory records project vision, requirements, architecture, data-source research, OGN/APRS work, station-health semantics, map UI, data model, API design, research notes, design decisions and roadmap. Documentation is part of the implementation and should be updated with material project changes.

## Current milestone

Prototype 0.1 establishes the iPhone architecture and interaction model. The next data milestone is to capture and parse real OGN receiver-status packets for PWMalham and representative ATOM stations, establish authoritative station coordinates/identity, and replace the fixture provider with the server REST provider.

## Important terminology

A missing heartbeat is evidence that no recent status report has been observed; it is not by itself proof that the physical ATOM installation is powered off. The UI therefore uses **No recent heartbeat** rather than claiming **Offline** unless a future authoritative source provides an explicit operational state.
