# ATOM Monitor User Guide

## What ATOM Monitor does
ATOM Monitor is an iPhone and Android application for viewing the operational health and technical status of PilotAware ATOM ground stations. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main navigation
The main application areas are Map, Stations, Favourites, Report, Settings, Help, Feedback and About. Feedback and About are first-class navigation areas at the same level as Settings and Help. Android is being kept to the same functional areas; current Feedback/About Android changes still await build/runtime verification.

## Map
Tapping a station opens its detail. On iPhone the default individual marker colours are **green Healthy, purple Back-level PilotAware software, blue No recent heartbeat, red Inactive, orange Warning and grey Unknown**. These colours are configurable in Settings and can be restored to defaults. Operational health takes precedence over the back-level-software presentation.

On the clustered iPhone map, an aggregate containing **No recent heartbeat** is yellow by default; mixed Healthy + Inactive aggregates are also yellow. Android clustering remains parity work.

### Inactive stations
ATOM Monitor derives an additional **Inactive** display state from the station's latest `lastSeen` record. In **Settings → Station status**, **Inactive after** controls the threshold. The default is **2 days** and the current supported range is 1–30 days.

When `lastSeen` is at least the configured number of days old, the station is displayed and filtered as **Inactive**, overriding its server-supplied health state for presentation. The original server record remains unchanged. A station without a `lastSeen` timestamp retains its server-supplied health because there is no timestamp from which to prove inactivity.

Changing the threshold immediately recalculates displayed status and the available Status filter choices; it does not require changing the server database.

### Filtering Map and Stations
Map and Stations share Status and PilotAware version filters. Status choices are generated from display states actually present after applying the inactivity threshold, so **Inactive** appears when applicable. PilotAware version choices are generated dynamically from values already collected. Multiple selections are supported; empty selection means all values, and Status/version/search conditions combine.

## Stations
Stations shows the persistent station registry subject to Find/status/version filters. The row displays the derived status, including Inactive where applicable. The Map and Stations headings use the compact title **Stations**. The refresh/status line includes the current station count; cached data remains visible if a current request fails.

## Favourites
Favourites are stored locally and provide a quick operational-health view. Derived Inactive status is also used there on iPhone.

## Report
Report summarises the current station dataset with the total number of stations, counts by displayed operational status and counts by reported PilotAware software version.

**Share report** creates two files and opens the platform's standard sharing interface:

- a responsive, formatted **HTML report** containing status and PilotAware-version horizontal bar graphs plus exact count tables;
- a **CSV station-data attachment** containing station name, displayed status, PilotAware version, station observation timestamps and latitude/longitude.

The iPhone first-presentation share-sheet timing issue found during testing on 17 September 2026 has been corrected and verified on the physical phone. Android uses the standard Android share chooser and FileProvider-backed temporary report files; Android build/runtime verification is still pending.

The report contains ATOM ground-station operational information only. It contains no aircraft identities, positions, movements or tracks.

## Settings
Normal remote operation uses the public HTTPS server. Data refresh defaults to 5 minutes with a supported 1–10 minute range. **Station status → Inactive after** defaults to 2 days. On iPhone the map-icon colours are configurable and persistent.

The iOS XcodeGen project uses automatic signing with the configured development team, so regenerating the Xcode project should not require manually selecting the Team again on the development Mac.

## Station cache
The latest successful station snapshot remains visible after a temporary network/server failure. Inactive is calculated from the cached station's `lastSeen`, so a cached record can naturally become Inactive as it ages. The cache is not a history database and contains no aircraft data.

## Station details
Record date & time uses `lastSeen` as an absolute local date/time. Other observation ages remain relative. Missing values display **Not reported**.

## Feedback and About
Feedback accepts a 1–5 star rating plus comments or suggestions and submits them privately to Richard Hine through the ATOM Monitor server. The destination email address is held only in server configuration and is not displayed by the app. Feedback includes app version, platform and OS version to help diagnose suggestions or problems.

**Feedback email delivery is currently deferred:** the user interface is present, but the Synology SMTP relay has not yet been configured/tested. Until that deployment work is completed, Send Feedback may report that feedback could not be sent.

About identifies **Richard Hine** as the creator and displays **Version**, **Build** and **Platform/OS** separately. It links to the official PilotAware ATOM information page and includes the product copyright, PilotAware trademark/non-affiliation statement and distribution/licence notices. The redundant combined Version / Build line is deliberately not shown.

ATOM Monitor is currently proprietary software: **© 2026 Richard Hine. All rights reserved.** iPhone distribution uses the applicable Apple terms/Standard EULA unless a custom EULA is later adopted. Android About separately identifies applicable third-party/open-source notices; those notices do not make ATOM Monitor itself open source.

## Help\nThe application contains a local User Guide so core operating instructions remain available without opening an external web page.

## Data and privacy scope
Aircraft traffic remains outside project scope and must not be stored as tracks, identities or movement history.
