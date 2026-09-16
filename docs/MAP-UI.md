# Map UI Specification

## Home screen
ATOM Monitor opens directly to the station map. The map is the application canvas and must fill the complete native iPhone display. Markers represent ground stations only.

## Full-screen and adaptive layout policy
The Map tab is not embedded in a NavigationStack. It owns its compact title/search overlay and MapKit extends edge-to-edge behind the status area and bottom tab bar. Other tabs retain NavigationStack where conventional navigation is appropriate.

Physical-device testing exposed a fundamental cause of the original large black bands above and below the application: native modern-iPhone launch geometry must be declared. The XcodeGen project therefore generates the iOS launch screen and declares the iPhone app full-screen. The map uses GeometryReader and consumes the runtime width/height, ignoring container safe-area edges for its background.

No fixed iPhone screen dimensions are used.

## Map chrome and status area
The map does not devote a separate panel to its title. `ATOM Stations`, the last-update indicator and compact `Find` field float over the map while MapKit continues behind them and system chrome.

The physical-device full-screen test on 16 September 2026 confirmed that the black top/bottom bands had been eliminated. Because the outer GeometryReader ignores the safe area, the overlay uses the reported top inset when available and a conservative 50-point status-area floor. This moves only the chrome, not the map.

### Last updated
The map header shows `Last updated: HH:MM` beside `ATOM Stations`. This value is the timestamp of the **last successful station snapshot refresh**, not the time of the most recent attempted request. Before any cached or network snapshot has been loaded it displays `Last updated: —`.

When a persistent iPhone cache is loaded at startup, the indicator initially shows the time that cached snapshot was saved. When the startup request or a scheduled refresh succeeds, the timestamp advances to the new successful refresh time. If a server/DNS/network refresh fails, the timestamp deliberately remains unchanged so the user can see the age of the station data still being displayed.

The indicator uses compact secondary text, remains single-line and can scale down on narrow displays so it does not require a taller map header.

## Annotation state
- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Markers must remain legible in light/dark appearance and not rely solely on colour.

## Selection flow
A single tap on an individual station opens full station detail directly in a draggable sheet. There is no intermediate summary card. Tapping a cluster zooms into it.

## Search
Search supports full and partial station names through the compact `Find` overlay.

## Clustering
Dense annotations cluster when zoomed out and separate as the user zooms in. Cluster circles show station count.

## Station detail layout
The detail sheet includes health/observation times, identity/software, location/altitude, CPU/RAM/temperature, uptime/voltage, NTP and RF information. Missing source fields display `Not reported`.

## Physical-device verification
Full-screen behaviour must be verified on physical iPhone and Simulator. Acceptance criteria include no black bands, edge-to-edge MapKit, system chrome over map content, title/last-updated/search clear of status content, and adaptation without source-code screen dimensions.

**Physical-device result, 16 September 2026:** edge-to-edge map coverage passed. A follow-up moved title/search chrome below the status area. The `Last updated` addition should be included in the next physical-device and multi-device Simulator regression recording.

## Device location
Location is optional. Core map browsing works without location permission.
