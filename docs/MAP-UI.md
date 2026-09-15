# Map UI Specification

## Home screen

ATOM Monitor opens directly to the station map. The map is the application canvas and should use essentially all available display area rather than being placed inside a fixed-size panel.

Markers represent ground stations only.

## Full-screen and adaptive layout policy

The map expands to the complete available iPhone display and may extend beneath the navigation chrome/safe-area edges where appropriate. Interactive controls and station information remain safe-area aware.

No view should assume a particular iPhone width or height. Layout adapts using available geometry, SwiftUI size classes and `ViewThatFits`. Compact phones use tighter card padding and allow health/name content to stack; larger phones use the extra width without artificially constraining the map. The station card has a sensible maximum readable width on very wide displays while the map remains edge-to-edge.

Dynamic Type, landscape orientation, display zoom and current small/standard/Max iPhone sizes must remain usable. Fixed-width rows should be avoided.

## Annotation state

Initial visual mapping:

- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Marker design should remain legible in light/dark appearance and should not rely solely on colour for accessibility. A glyph/border/state label supplements colour.

## Selection flow

A single tap selects the station and presents a compact material summary card while retaining maximum map context. The card adapts to the available width and sits above the bottom safe area/tab bar.

`View Details` navigates to the full station-health view.

## Search

Search supports full and partial station names. The search interface is navigation chrome rather than permanent map-consuming content. A later iteration will make selecting a search result centre/zoom the map, select the annotation and open its summary.

## Clustering

When zoomed out, dense annotations should cluster to keep the map readable. On zooming in, clusters separate into stations. We should evaluate whether cluster appearance should communicate worst health, proportions by health state, or simply station count; no decision yet.

## Station detail layout

Sections:

1. Health — state, reason, last heartbeat, age.
2. Location — coordinates and altitude.
3. System — software, platform, CPU, RAM, temperature, uptime.
4. Time — NTP offset/correction.
5. Radio — available RF calibration/quality values.
6. History — links/charts for supported telemetry.

Only fields supported by real source data are displayed. Unknown fields are `Not reported` rather than synthetic values.

## Device location

Location is optional. If permission is granted, a standard map-location control can centre on the device and a later feature can list nearest ATOM stations. Core map browsing must work without location permission.
