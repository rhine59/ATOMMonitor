# ATOM Monitor User Guide

## What ATOM Monitor does
ATOM Monitor is an iPhone and Android application for viewing the operational health and technical status of PilotAware ATOM ground stations. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen
The application has Map, Stations, Favourites, Settings and Help tabs.

## Map
The map adapts to the available phone display. Tapping a station opens its complete detail. On iPhone, clusters separate as the map is zoomed and marker colour represents derived health: green Healthy, amber Warning, red No recent heartbeat and grey Unknown.

The initial map view centres on the Home station selected in Settings, or uses the default wider UK view. The status shows the last successful update time. If the current server request fails, this is replaced by **No Network** while cached station data remains visible.

### Filtering Map and Stations
Map and Stations share the same station filters. Tap the **Filter** control to filter the currently collected station registry by:

- **Status** — the chooser contains only health states actually present in the collected station data, such as Healthy, Warning, No recent heartbeat and Unknown;
- **PilotAware version** — the chooser is populated dynamically from the distinct `pilotAwareVersion` values already reported by collected stations.

Multiple statuses and multiple PilotAware versions can be selected. With nothing selected in a filter section, that section accepts all values. When both sections contain selections, a station must match a selected Status **and** a selected PilotAware version. The Find/search text is also combined with these filters.

The active filter applies to both Map and Stations, so switching between those tabs preserves the same working subset. An active-filter indicator and the number of displayed versus collected stations are shown, and **Clear filters** returns to the complete registry. Stations with no reported PilotAware version remain visible when the version filter is unrestricted, but do not match a specific version selection.

Filter choices come from the station data already collected by ATOM Monitor; version values are not hard-coded into either mobile application.

## Stations
Stations shows the complete persistent station registry rather than only transmitters heard at that instant, subject to any active Find/status/version filters. Selecting a station opens its detailed status.

## Favourites
Favourites provides a quick operational-health view of selected stations. Favourites are a phone-side view and do not change server collection. Shared station filters also constrain the displayed favourites on Android; platform parity for this behaviour should be maintained as the clients evolve.

## Settings

### Server
The server address can be edited and saved in Settings. Normal remote operation uses the public HTTPS DNS address rather than the Synology LAN IP.

### Data refresh
ATOM Monitor fetches the station registry once immediately when the app starts and then automatically at the configured interval. The default interval is **5 minutes** and the supported range is **1 to 10 minutes**. Automatic refresh is foreground/lifecycle dependent and may be suspended while the app is backgrounded.

## Station cache
Every successful server refresh is retained locally as the latest station snapshot. Cached data remains visible while a new request is in progress and after a temporary network/server failure. The cache is a latest-snapshot cache, not a history database, and contains no aircraft data.

### Home station
Choose **Home station** to define the preferred map location. Home means an ATOM ground station, not the phone's GPS position; normal operation does not require device-location permission.

### Favourite stations
Favourite stations are stored locally on the phone and can be selected from the station views.

## Help and local User Guide
The Help tab contains the User Guide inside ATOM Monitor itself and is intended to remain available without an Internet connection. User-facing changes should be reflected in the local in-app guide on both platforms.

## Station details
Depending on source data, details may include station name, coordinates/altitude, observation and heartbeat times, software versions, CPU load/temperature, RAM, NTP timing, RF information, uptime and supply voltage. Unsupported data displays **Not reported** rather than a synthetic zero.

The Health section also shows **Record date & time**, using the station's latest `lastSeen` timestamp as an absolute local date and time. Last heartbeat, Last seen, Last position and Last technical status remain relative-time indicators.

## PilotAware identification
Live OGN/APRS testing has shown PilotAware station heartbeats containing `OGN-R/PilotAware`. The `PW` prefix is useful for discovery but is not by itself the final authoritative classification.

## Data and privacy scope
The server consumes ground-receiver/status information required to monitor ATOM stations. Aircraft traffic is outside project scope and must not be stored as aircraft tracks, identities or movement history.

## Troubleshooting
A safe broad discovery command on the Synology server is:

```bash
cd /volume1/docker/ATOMMonitor/server/diagnostic
python3 ogn_station_probe.py --prefix PW --discovery
```

To display and save diagnostic output simultaneously:

```bash
python3 ogn_station_probe.py --prefix PW --discovery 2>&1 | tee atom_discovery.log
```

The diagnostic collector deliberately does not dump general aircraft traffic.
