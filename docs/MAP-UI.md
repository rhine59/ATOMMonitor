# Map UI Specification

## Home screen

ATOM Monitor opens directly to the station map. The map is the application canvas and must fill the complete native iPhone display. Markers represent ground stations only.

## Full-screen and adaptive layout policy

The Map tab is not embedded in a NavigationStack. It owns its compact title/search overlay and MapKit extends edge-to-edge behind the status area and bottom tab bar. Other tabs retain NavigationStack where conventional navigation is appropriate.

Physical-device testing exposed a fundamental cause of the original large black bands above and below the application: native modern-iPhone launch geometry must be declared. The XcodeGen project therefore generates the iOS launch screen and declares the iPhone app full-screen. The map uses GeometryReader and explicitly consumes the complete runtime width and height, ignoring container safe-area edges for its background.

No fixed iPhone screen dimensions are used. The layout is intended to support small, standard, Pro and Max-sized iPhones without letterboxing or unused black space.

## Map chrome and status area

The map does not devote a separate panel to its title. `ATOM Stations` and the compact `Find` field float over the map while MapKit continues behind them and behind system chrome.

The physical-device full-screen test on 16 September 2026 confirmed that the black top/bottom bands had been eliminated. That test also exposed a separate overlay issue: because the outer GeometryReader itself ignores the safe area, `geometry.safeAreaInsets.top` can be zero even though the physical iPhone has an occupied status/Dynamic-Island region. The title then collided with the clock/status icons.

The map chrome therefore uses the reported top inset when available but also enforces a conservative 50-point status-area floor before adding the title/search stack. This does **not** shrink or inset the map itself; it moves only interactive/text chrome down while the map remains edge-to-edge. The title is single-line with a minimum scale factor for narrower displays. Horizontal padding remains adaptive.

## Annotation state

- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Markers must remain legible in light/dark appearance and not rely solely on colour.

## Selection flow

A single tap on an individual station opens the full station detail view directly in a draggable sheet. There is no intermediate summary card. Tapping a cluster zooms into that cluster.

## Search

Search supports full and partial station names through the compact `Find` overlay and does not consume a permanent map region.

## Clustering

Dense annotations cluster when zoomed out and separate as the user zooms in. Cluster circles currently show station count.

## Station detail layout

The direct detail sheet includes health and observation times, station identity/software versions, location/altitude, CPU/RAM/temperature, uptime/voltage, NTP and RF information. Missing source fields display `Not reported`.

## Physical-device verification

Full-screen behaviour must be verified on a physical iPhone as well as Simulator. Acceptance criteria are:

- no black/unused band above the map;
- no black/unused band below the map;
- MapKit background reaches every display edge;
- status bar/Dynamic Island appears over map content;
- bottom tab bar appears over map content;
- title and `Find` remain below/clear of status-area content;
- changing iPhone screen size does not require source-code screen dimensions.

**Physical-device result, 16 September 2026:** edge-to-edge map coverage passed. A follow-up fix moved the title/search chrome below the status area after the screenshot revealed title/status collision. This follow-up must be rechecked on the physical device and subsequently covered by the multi-device Simulator demonstration/regression suite.

After changing launch-screen/full-screen Info.plist generation, regenerate the Xcode project and perform a clean reinstall on the physical iPhone so the new application metadata is definitely installed.

## Device location

Location is optional. Core map browsing works without location permission.
