# ATOM Monitor User Guide

## What ATOM Monitor does
ATOM Monitor is an iPhone and Android application for viewing the operational health and technical status of PilotAware ATOM ground stations. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen
The application has Map, Stations, Favourites, Settings and Help tabs.

## Map
Tapping a station opens its detail. Display health is colour-coded: green Healthy, amber Warning, red No recent heartbeat or Inactive, and grey Unknown.

### Inactive stations
ATOM Monitor derives an additional **Inactive** display state from the station's latest `lastSeen` record. In **Settings → Station status**, **Inactive after** controls the threshold. The default is **2 days** and the current supported range is 1–30 days.

When `lastSeen` is at least the configured number of days old, the station is displayed and filtered as **Inactive**, overriding its server-supplied health state for presentation. The original server record remains unchanged. A station without a `lastSeen` timestamp retains its server-supplied health because there is no timestamp from which to prove inactivity.

Inactive stations use a **red map icon**. On the iPhone clustered map, a cluster containing both green Healthy and red Inactive stations is **yellow**, drawing attention to the mixed aggregate. An all-Inactive cluster is red. Android currently displays individual station markers; the same mixed-cluster colour rule is required when Android marker clustering is added.

Changing the threshold immediately recalculates displayed status and the available Status filter choices; it does not require changing the server database.

### Filtering Map and Stations
Map and Stations share Status and PilotAware version filters. Status choices are generated from display states actually present after applying the inactivity threshold, so **Inactive** appears when applicable. PilotAware version choices are generated dynamically from values already collected. Multiple selections are supported; empty selection means all values, and Status/version/search conditions combine.

## Stations
Stations shows the persistent station registry subject to Find/status/version filters. The row displays the derived status, including Inactive where applicable.

## Favourites
Favourites are stored locally and provide a quick operational-health view. Derived Inactive status is also used there on iPhone.

## Settings
Normal remote operation uses the public HTTPS server. Data refresh defaults to 5 minutes with a supported 1–10 minute range. **Station status → Inactive after** defaults to 2 days.

## Station cache
The latest successful station snapshot remains visible after a temporary network/server failure. Inactive is calculated from the cached station's `lastSeen`, so a cached record can naturally become Inactive as it ages. The cache is not a history database and contains no aircraft data.

## Station details
Record date & time uses `lastSeen` as an absolute local date/time. Other observation ages remain relative. Missing values display **Not reported**.

## Data and privacy scope
Aircraft traffic remains outside project scope and must not be stored as tracks, identities or movement history.
