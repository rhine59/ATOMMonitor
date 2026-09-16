# Changelog

## 2026-09-16 — Live station pipeline

- Added persistent SQLite station registry in the Synology API container.
- Added REST endpoints for API health, all confirmed ATOM stations, individual stations and collector observations.
- Added explicit `OGN-R/PilotAware` heartbeat parsing; this marker confirms a discovered source as PilotAware/ATOM rather than relying on the `PW` prefix alone.
- Kept position, heartbeat and technical-status timestamps separate.
- Connected the OGN collector container to the API container through Docker Compose.
- Registry retains discovered state across container restarts using `server/data`.
- iPhone now reads station data from the Synology at `192.168.1.99:8080`, caches the station response and keeps a durable favourites cache.
- Stations without a position report remain available in Stations/Favourites but are omitted from the map until coordinates are known.
- Added Map/Stations favourite controls and Settings removal.
- Aircraft packets remain outside the accepted parser/database model and are not stored.
- Initial heartbeat health thresholds remain conservative/provisional while multi-station cadence measurements continue.

## 2026-09-15 — Project primed

- Established ATOM Monitor project scope.
- Defined map-first iPhone experience.
- Explicitly excluded aircraft tracking and aircraft-position persistence.
- Selected OGN APRS receiver/status data as the primary live-health candidate pending live validation.
- Proposed Synology/Docker collector + REST API + SwiftUI/MapKit architecture.
- Defined persistent station registry so silent stations remain visible.
- Defined initial health states: Healthy, Warning, No recent heartbeat, Unknown.
- Selected PWMalham as the initial reference/test station.
- Added project vision, requirements, architecture, data-source, OGN APRS, health, map UI, data-model, API, research, decision-log and roadmap documentation.
