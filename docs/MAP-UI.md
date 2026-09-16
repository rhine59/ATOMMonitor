# Map UI Specification

## Home screen

ATOM Monitor opens directly to the station map. The map is the application canvas and should use essentially the complete iPhone display rather than being placed inside a fixed-size panel. Markers represent ground stations only.

## Full-screen and adaptive layout policy

The Map tab is intentionally **not embedded in a NavigationStack**. A NavigationStack/navigation bar reserves vertical layout space even when its background is hidden; hiding toolbar chrome is not equivalent to removing that layout inset. This caused the large unused black band visible above the map on a physical iPhone during September 2026 testing.

The Map tab therefore owns its own compact title/search overlay and MapKit extends behind the status-area and bottom tab-bar safe areas. Interactive controls remain positioned safely over the map. The other tabs continue to use NavigationStack because conventional navigation is appropriate there.

No view should assume a particular iPhone width or height. Layout must remain usable on current small, standard and Max iPhones, Dynamic Type, landscape and display zoom. Fixed-width rows should be avoided.

## Map chrome

The map should not devote a permanent large header to the application title. Search is a compact material overlay with the placeholder `Find`. The objective is maximum useful map area while retaining obvious station search and the standard bottom tabs.

## Annotation state

- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Marker design should remain legible in light/dark appearance and should not rely solely on colour for accessibility.

## Selection flow

A single tap on an individual station opens the **full station detail view directly** in a draggable sheet. There is no intermediate summary card or second `View Details` action. The detail view exposes all available ground-station telemetry and displays unsupported/missing fields as `Not reported`.

Tapping a cluster zooms further into that cluster rather than presenting station details.

## Search

Search supports full and partial station names through the compact `Find` overlay. Search must not consume a large permanent region of the map.

## Clustering

When zoomed out, dense annotations cluster to keep the map readable. On zooming in, clusters separate into stations. Cluster circles currently display station count.

## Station detail layout

The direct station detail sheet includes health and heartbeat/observation times, station identity and software versions, location/altitude, system CPU/RAM/temperature, uptime and voltage, NTP data and RF information. Only fields supported by real source data are displayed; unknown fields are `Not reported` rather than synthetic values.

## Device location

Location is optional. Core map browsing must work without location permission.

## Physical-device verification

Full-screen behaviour must be checked on a physical iPhone as well as Simulator. A screenshot from the physical device is the authoritative check for wasted top/bottom layout space because navigation/safe-area behaviour can be visually obvious even when the SwiftUI hierarchy appears nominally edge-to-edge in source.
