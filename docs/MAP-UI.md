# Map UI Specification

## Home screen

ATOM Monitor opens directly to the station map.

```text
+--------------------------------------+
| ATOM Monitor                   Search|
|                                      |
|       green          green           |
|                           amber      |
|   green                              |
|              green                   |
|                         red          |
|                                      |
| Healthy  Warning  No heartbeat       |
+--------------------------------------+
```

Markers represent ground stations only.

## Annotation state

Initial visual mapping:

- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Marker design should remain legible in light/dark appearance and should not rely solely on colour for accessibility. A glyph/border/state label can supplement colour.

## Selection flow

A single tap selects the station and presents a compact summary card/sheet while retaining map context:

```text
PWMalham                         Healthy
54.002 N, 2.142 W                147 m
Last heartbeat                 32 sec ago
Software                      v20260707
                         View Details >
```

`View Details` navigates to the full station-health view.

## Search

Search supports full and partial station names. Selecting a result:

1. centres/zooms the map appropriately;
2. selects the annotation;
3. opens the station summary.

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

## iPhone adaptability

Use SwiftUI adaptive layout, Dynamic Type and safe-area-aware presentation. Avoid fixed-width rows that only fit large iPhones. The map should consume the available screen while controls use compact overlays/toolbars.

## Device location

Location is optional. If permission is granted, a standard map-location control can centre on the device and a later feature can list nearest ATOM stations. Core map browsing must work without location permission.
