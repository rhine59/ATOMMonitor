# Map UI Specification

## Home screen
ATOM Monitor opens directly to the station map. The map is the application canvas and must fill the complete native iPhone display. Markers represent ground stations only.

## Full-screen and adaptive layout policy
The Map tab is not embedded in a NavigationStack. It owns its compact title/search overlay and MapKit extends edge-to-edge behind the status area and bottom tab bar. Other tabs retain NavigationStack where conventional navigation is appropriate. The map uses GeometryReader and runtime dimensions; no fixed iPhone screen dimensions are used.

## Map chrome and status area
`ATOM Stations`, map-layer selector, Home button and manual refresh occupy the top control row. A plain-text connection/update status line sits immediately below that row and immediately above the compact `Find` field. It has no capsule, material or other separate overlay treatment. Controls use compact adaptive sizing so the header can be regression-tested across small, standard, Pro and Max iPhones.

### Map layers
The layers button (`square.3.layers.3d`) switches the Apple MapKit base map without changing station annotations, health colours, clustering, search or selection:

- **Standard** — Apple standard map with realistic elevation; default.
- **Satellite + Labels** — hybrid imagery with labels and realistic elevation.
- **Satellite** — imagery without the normal label overlay, with realistic elevation.

The selected layer persists in `@AppStorage` as `stationMapLayer`.

### Home station control
The Map header includes a Home button (`house.fill`). The configured home station is selected in Settings and is a ground station, not the iPhone's physical location. Tapping Home animates the map to that station using the normal home zoom level.

If no home station is configured, tapping Home displays exactly `No home station set`. If the selected station exists but has no reported coordinates, it displays `Home station location not reported`. The feature therefore does not require iPhone location permission.

### Manual refresh, Last updated and network failure
The refresh button immediately requests a fresh station snapshot. `Last updated: HH:MM` records the last successful snapshot refresh, not the latest attempted request. Cached startup data shows its saved time and a successful refresh advances it.

The status is plain text immediately below `ATOM Stations`/the top button row and immediately above `Find`. When the current server refresh fails, the timestamp is replaced with `No Network` in red. Cached station data remains visible while disconnected. There is no bottom-of-map Last updated overlay.

## Annotation state
- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Markers remain legible in light/dark appearance and do not rely solely on colour.

## Selection, search and clustering
A station tap opens full station detail directly in a draggable sheet. A cluster tap zooms in. Search supports full and partial station names through `Find`. Dense annotations cluster when zoomed out and separate as the user zooms in.

### Station detail timestamps
The station detail Health section shows **Record date & time** using the latest station `lastSeen` value formatted as an absolute local date and time. The existing Last heartbeat, Last seen, Last position and Last technical status rows remain relative-time displays. If an exact record timestamp is unavailable, the absolute field displays `Not reported` consistently with other missing telemetry.

## Simulator and physical-device regression
The recorded UI tour is required to exercise manual Map refresh, all three map layers, the Home button with no home configured and the exact `No home station set` message, setting a home station, returning to Map and using Home successfully, Stations refresh/pull-to-refresh, station search/detail/favourite, **Record date & time** in station detail, refresh interval, Help, cached snapshot, Last updated and the `No Network` state.

Physical-device testing should additionally verify the Map header on small, standard, Pro and Max display widths, confirm no collision with status-area content, and verify the station record timestamp uses the device's local date/time presentation.

## Device location
Location is optional. Core map browsing and the Home station control work without location permission.
