# Requirements

## Functional requirements

### Map

- The application opens to a MapKit map.
- All known ATOM stations with usable coordinates are represented.
- Stations remain represented after they stop reporting.
- Markers visually communicate current health state.
- Dense areas should use clustering where practical.
- The user can pan, zoom and select markers using standard MapKit interactions.
- A selected marker presents a compact station summary without immediately leaving the map.
- The user can navigate from the summary to the full station-detail view.

### Search and navigation

- Search by full or partial station name.
- Selecting a search result centres/selects the station on the map.
- A future favourites facility should provide fast access to important stations.
- Device location may optionally centre the map or support nearest-station display, but location permission must not be required for basic use.

### Station details

Display when available:

- station name/identifier;
- latitude and longitude;
- altitude/elevation;
- last heartbeat/status timestamp;
- age of latest status;
- software/version/platform;
- CPU load;
- RAM usage/total;
- CPU/system temperature;
- uptime;
- NTP offset and frequency correction;
- RF/frequency correction and other receiver-health fields;
- data-source/provenance information where useful.

Missing fields must be represented as `Not reported`.

### Health

Initial states:

- Healthy
- Warning
- No recent heartbeat
- Unknown

Thresholds must be configurable in server configuration and should be validated against observed real reporting intervals before being considered stable.

### History

- Persist station health/status observations.
- Support at least 24-hour, 7-day and 30-day views eventually.
- Candidate graph series: temperature, CPU, memory, NTP offset/correction and RF correction/quality.

### Data collection

- Maintain one long-lived OGN APRS connection on the server rather than one per iPhone.
- Parse receiver/status messages relevant to ground-station health.
- Do not persist aircraft positions, tracks or identities.
- Maintain a persistent ATOM station registry independent of current live status.

## Non-functional requirements

- Native SwiftUI iPhone application.
- Adaptive layouts across supported iPhone screen sizes.
- MapKit for mapping.
- Server deployable in Docker/Compose on a Synology NAS.
- HTTPS/JSON interface between server and app.
- Reconnection/backoff for OGN feed interruption.
- Database migrations/versioning once implementation begins.
- Clearly distinguish observed telemetry from derived health state.
- Avoid presenting ATOM Monitor as a certified, safety-critical, or authoritative aviation operational-status service.

## Data-source requirements

The system must be designed so data providers can be replaced or supplemented. OGN APRS is currently the preferred live receiver-status source; PilotAware Playback/other PilotAware endpoints are candidates for supplementary metadata. No undocumented source should be treated as permanently guaranteed.
