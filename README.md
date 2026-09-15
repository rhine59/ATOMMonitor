# ATOM Monitor

ATOM Monitor is an iPhone application and supporting server for monitoring the operational health and technical details of PilotAware ATOM ground stations.

## Project goal

The primary user experience is a map containing all known PilotAware ATOM stations. A user can pan, zoom, search for, and select a station, then open a detail view showing the station's current health and available technical information.

The application is deliberately **not an aircraft tracker**. It will not display, persist, or analyse aircraft positions. Aircraft traffic received by an ATOM station is outside the scope of this project.

## Core behaviour

- Open directly to a map of known ATOM stations.
- Keep stations on the map even when they stop reporting; an unhealthy station must not simply disappear.
- Use clear health states: Healthy, Warning, No recent heartbeat, and Unknown.
- Tap a map marker for a compact station summary, then navigate to full details.
- Search for a station by name and navigate the map to it.
- Show location, altitude, heartbeat/status age, software/system, timing/NTP, and RF information when the underlying feed reports those values.
- Store historical station-health observations so trends can be investigated later.
- Treat missing values as `Not reported`; never invent or reinterpret absent telemetry as zero.
- Use PWMalham as the initial reference station during development.

## Proposed architecture

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
   +-------------------+
   | MapKit map        |
   | station search    |
   | station details   |
   | health history    |
   +-------------------+
```

The preferred live source is the OGN APRS receiver/status stream. PilotAware sources such as Playback may later supplement PilotAware-specific metadata where appropriate. The server will maintain a persistent station registry so a station remains visible when its heartbeat disappears.

## Repository layout

- `docs/PROJECT-VISION.md` — scope, principles, and user experience.
- `docs/REQUIREMENTS.md` — functional and non-functional requirements.
- `docs/ARCHITECTURE.md` — proposed iOS/server architecture.
- `docs/DATA-SOURCES.md` — evidence, source strategy, and limitations.
- `docs/OGN-APRS.md` — OGN APRS investigation and parsing plan.
- `docs/STATION-HEALTH.md` — health model and telemetry fields.
- `docs/MAP-UI.md` — map-first UI specification.
- `docs/DATA-MODEL.md` — proposed persistent data model.
- `docs/API-DESIGN.md` — proposed server-to-iPhone REST interface.
- `docs/RESEARCH-NOTES.md` — findings and open investigations.
- `docs/DESIGN-DECISIONS.md` — project decision log.
- `docs/ROADMAP.md` — staged implementation plan.
- `server/README.md` — server/collector plan.
- `ios/README.md` — SwiftUI application plan.

## Status

The project is currently in architecture and data-source validation. The next milestone is to capture and parse real OGN receiver-status packets for PWMalham and a representative sample of other PilotAware ATOM stations, then determine a reliable method for bootstrapping the complete ATOM station registry.

## Important terminology

A missing heartbeat is evidence that no recent status report has been observed; it is not by itself proof that the physical ATOM installation is powered off. The UI therefore uses **No recent heartbeat** rather than claiming **Offline** unless a future authoritative source provides an explicit operational state.
