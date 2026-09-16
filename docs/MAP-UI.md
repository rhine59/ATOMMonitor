# Map UI Specification

## Home screen
ATOM Monitor opens directly to the station map. The map is the application canvas and must fill the complete native iPhone display. Markers represent ground stations only.

## Full-screen and adaptive layout policy
The Map tab is not embedded in a NavigationStack. It owns its compact title/search overlay and MapKit extends edge-to-edge behind the status area and bottom tab bar. Other tabs retain NavigationStack where conventional navigation is appropriate.

Physical-device testing exposed a fundamental cause of the original large black bands above and below the application: native modern-iPhone launch geometry must be declared. The XcodeGen project therefore generates the iOS launch screen and declares the iPhone app full-screen. The map uses GeometryReader and consumes the runtime width/height, ignoring container safe-area edges for its background. No fixed iPhone screen dimensions are used.

## Map chrome and status area
The map does not devote a separate panel to its title. `ATOM Stations`, last-update indicator, map-layer selector, manual refresh and compact `Find` field float over the map while MapKit continues behind them and system chrome.

The overlay uses the reported top inset when available and a conservative 50-point status-area floor. This moves only the chrome, not the map.

### Map layers
A layers button (`square.3.layers.3d`) is available in the Map header. It switches the Apple MapKit base map without changing station annotations, health colours, clustering, search or selection. The choices are:

- **Standard** — Apple standard map with realistic elevation; default.
- **Satellite + Labels** — hybrid imagery with map labels and realistic elevation.
- **Satellite** — imagery without the normal map-label overlay, with realistic elevation.

The selected layer is persisted with `@AppStorage` under `stationMapLayer`, so it survives app restarts. Layer selection is purely a presentation preference and does not change ATOM station data or cause aircraft data to be displayed or stored.

### Last updated
The map header shows `Last updated: HH:MM`. This is the timestamp of the last successful station snapshot refresh, not the latest attempted request. Before any cached/network snapshot it displays `Last updated: —`. A cached snapshot shows its saved time; successful refresh advances it; failed refresh leaves it unchanged.

## Annotation state
- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Markers must remain legible in light/dark appearance and not rely solely on colour.

## Selection flow
A single tap on an individual station opens full station detail directly in a draggable sheet. Tapping a cluster zooms into it.

## Search
Search supports full and partial station names through the compact `Find` overlay.

## Clustering
Dense annotations cluster when zoomed out and separate as the user zooms in. Cluster circles show station count.

## Physical-device verification
Full-screen behaviour must be verified on physical iPhone and Simulator. The regression tour should exercise all three map layers as well as manual refresh, Last updated, station selection and search. Verify the header controls fit small, standard, Pro and Max displays without colliding with status-area content.

## Device location
Location is optional. Core map browsing works without location permission.
