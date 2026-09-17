# ATOM Monitor — iOS → Android Parity Audit

Date: 17 September 2026

## Objective

Bring the Android client to user-visible functional parity with the current iPhone client while preserving native platform implementation choices and the station-only scope invariant.

This audit uses the committed `main` branch as the authority. It distinguishes features already present in Android from features that are missing, incomplete, or not yet runtime-verified.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It must not display, record or retain aircraft movements, tracks or aircraft identities.

## Executive finding

Android has the same six primary areas — Map, Stations, Favourites, Report, Settings and Help — and already implements the core station API, cache, health/version filters, configurable inactive threshold, favourites, station detail, HTML/CSV sharing and the new responsive map layout. It is nevertheless materially behind the iPhone client in map behaviour, settings, presentation configuration and user guidance.

The highest-priority parity gap is Settings/Map configuration. The iPhone client exposes Home station behaviour, map-layer selection and persistent map/status colours; Android currently exposes server, refresh interval and inactive threshold only. Android also lacks iPhone-equivalent clustering, mixed-health cluster presentation, Home navigation/filter focus and configurable marker colours.

## Parity matrix

| Area | iPhone behaviour | Android state | Required Android work | Priority |
| --- | --- | --- | --- | --- |
| Primary navigation | Map, Stations, Favourites, Report, Settings, Help | Present; responsive six-item navigation runtime-tested on Pixel 10a | Retain | Complete |
| Responsive map layout | Map dominates available screen; controls overlay map | New responsive Android launcher runtime-tested on Pixel 10a | Retain and regression-test other dimensions/orientations | Complete for current checkpoint |
| Live station retrieval | Configured HTTPS service, cached fallback | Present; 305-station live retrieval verified | Retain | Complete |
| Connection status | Last successful update/count; cached No Network state | Present, but responsive header currently simplifies successful state to station count | Restore iPhone-equivalent last-updated presentation without sacrificing compact layout | High |
| Test Connection | `/ready` readiness/database check reports confirmed station count | Android `Save & Test` currently saves server and calls normal station refresh rather than the dedicated readiness test | Add explicit Test Connection using `/ready`, report success/count or error | High |
| Refresh interval | 1–10 minutes, persisted, foreground automatic refresh | Present, 1–10 minutes | Verify interaction/persistence | Medium |
| Refresh serialization | Prevent overlapping refreshes | Android `refreshing` guard present | Regression-test startup/manual/periodic overlap behaviour | Medium |
| Inactive threshold | 1–30 days, default 2, persisted | Present | Verify interaction and map/list recalculation | Medium |
| Home station setting | Persist selected Home ATOM station | Storage property exists (`home`) but Settings does not expose a Home selector | Add searchable/usable Home station selection in Settings | High |
| Home map control | Map Home button centres on configured Home station | Missing | Add Home control to responsive map chrome | High |
| Home initial focus | Initial map can focus configured Home | Missing | Apply configured Home after station data is available | High |
| Filter-relative map focus | With filters active, focus nearest matching station to Home; UK fallback | Missing | Implement nearest matching station calculation and UK fallback | High |
| Map layers | Standard, Satellite + Labels, Satellite; persisted | Missing; Android fixed to osmdroid MAPNIK | Add persistent layer selection appropriate to Android/osmdroid, matching the three user-visible choices where technically supported | High |
| Status/version filters | Shared Map/Stations filters | Present | Runtime-test filter interactions and clear behaviour | Medium |
| Filtered-count feedback | Shows filtered count and clear-filter action when filters active | Android filter dialog exists but responsive map chrome does not show filtered-count feedback | Add compact filtered-count/clear presentation | Medium |
| Search | Find by station name | Present | Retain | Complete |
| Clustering | Dynamic station clusters | Missing | Add Android clustering | High |
| Mixed-health clusters | Cluster colour flags degraded/mixed health | Missing | Add health-aware cluster colour logic | High |
| Configurable marker colours | Healthy, back-level, no heartbeat, inactive, warning, unknown; persisted | Missing; Android marker/detail colours are hard-coded | Add persistent colour preferences and Settings controls; use them consistently on map/detail/cluster presentation | High |
| Back-level software | Healthy station can be separately identified as back-level | Detail logic present; broader map/list presentation incomplete | Apply configured back-level presentation consistently | High |
| Inactive map presentation | Inactive visually distinct, red by default | Current Android map icon maps inactive and no-recent-heartbeat to the same platform drawable | Give Inactive its own configurable presentation | High |
| Station list | Shared filters/search; station status/version | Present | Runtime-test | Medium |
| Favourites | Persist locally; add/remove from Station Detail | Present | Runtime-test persistence | Medium |
| Station Detail status icon/explanation | Effective icon/colour plus explanation | Present in Android | Runtime-test | Medium |
| Station Detail timestamps | Absolute record date/time plus relative ages | Present in Android | Runtime-test | Medium |
| Station Detail telemetry cleanup | Do not show unreliable uptime/supply voltage/frequency correction; RF correction remains | Android detail currently omits those unreliable fields | Runtime-test | Medium |
| Google Maps satellite location | Exact coordinate pin, satellite, zoom 18 | Present in Android | Runtime-test intent | Medium |
| Report summary | Status and PilotAware version summary | Present | Runtime-test | Medium |
| Report bar graphs | Responsive horizontal graphs plus exact tables | Android generated HTML contains bar graphs/tables; in-app report itself is count rows | Verify shared output parity | Medium |
| Native report sharing | HTML + station CSV via native share UI | Present | Runtime-test | Medium |
| Persistent station cache | Latest successful station snapshot retained | Present | Test offline/no-network restart path | Medium |
| User Guide | Detailed explanation of Map/Home/filters/status/detail/favourites/report/settings/privacy | Android Help is currently a single compressed paragraph | Replace with structured Android guide aligned to iPhone functionality and Android terminology | High |
| Scope/privacy wording | Explicit station-only scope; no aircraft movements/identities | Present | Retain in UI/report/docs | Complete |
| Deprecated Android icons | No equivalent issue on iOS | Android build has deprecated `Icons.Filled.List` / `Help` warnings | Replace with AutoMirrored equivalents during parity work | Low |

## Implementation sequence

### P1 — Settings and map controls

1. Add dedicated `/ready` Test Connection with confirmed station count.
2. Add Home station selection and persistence.
3. Add Home map button, startup Home focus and filtered-nearest-to-Home behaviour with UK fallback.
4. Add persistent map-layer selection.
5. Restore compact last-updated status and filtered-count feedback to the responsive map chrome.

### P2 — Map presentation parity

1. Add persistent map/status colour preferences for Healthy, back-level, No recent heartbeat, Inactive, Warning and Unknown.
2. Apply those colours consistently to station markers and Station Detail.
3. Make Inactive visually distinct from No recent heartbeat.
4. Add Android station clustering.
5. Add mixed/degraded cluster presentation and cluster zoom-in behaviour.

### P3 — Existing-feature runtime regression

Verify filters, inactive threshold, favourites persistence, Station Detail, Google Maps intent, report/share output, cache/no-network behaviour, refresh serialization, Settings persistence and all six navigation areas on Android.

### P4 — Guide, warnings and device-size regression

1. Replace Android Help with a structured local User Guide aligned to implemented Android behaviour.
2. Replace deprecated directional List/Help icon APIs with AutoMirrored equivalents.
3. Test responsive layout on Pixel 10a plus at least one narrower/smaller phone and landscape orientation.
4. Update build/test evidence and feature statuses after each verified checkpoint.

## Definition of Android parity

Android parity is reached when every user-visible iPhone feature above either:

- has equivalent Android behaviour and has passed Android build/runtime verification; or
- has an explicit documented platform-specific reason for a native difference while preserving the same user objective.

A source implementation or successful compile alone is not sufficient to mark parity Tested.
