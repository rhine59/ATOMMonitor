# ATOM Monitor User Guide

## What ATOM Monitor does
ATOM Monitor is an iPhone application for viewing the operational health and technical status of PilotAware ATOM ground stations. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen
The application has Map, Stations, Favourites, Settings and Help tabs.

## Map
The map uses the complete available iPhone display dynamically and adapts to different screen sizes. Clusters separate as the map is zoomed. Tapping a station opens its complete detail directly. Marker colour represents derived health: green Healthy, amber Warning, red No recent heartbeat and grey Unknown.

The initial map view centres on the Home station selected in Settings, or uses the default wider UK view. Immediately below the title/buttons and above Find, the status shows the last successful update time. If the current server request fails, this is replaced by **No Network** while cached station data remains visible.

## Stations
Stations shows the complete persistent station registry rather than only transmitters heard at that instant. Selecting a station opens its detailed status.

## Favourites
Favourites provides a quick operational-health view of selected stations. Favourites are an iPhone-side view/filter and do not change server collection.

## Settings

### Server
The server address can be edited and saved in Settings. **Test Connection** checks the configured service before it is relied upon. Normal remote operation should use the public HTTPS DNS address rather than the Synology LAN IP.

### Data refresh
ATOM Monitor fetches the station registry **once immediately when the app starts**. It then automatically fetches fresh data at the configured interval.

The default interval is **5 minutes**. In **Settings → Data refresh**, use **Refresh interval** to choose any whole-minute value from **1 to 10 minutes**. The selected interval is stored on the iPhone and used on later launches.

Changing the interval restarts the refresh schedule and performs an immediate refresh. Automatic refresh is an in-app foreground mechanism; iOS may suspend execution while the app is backgrounded.

## iPhone station cache
Every successful server refresh is retained in memory for immediate use and also written atomically to a persistent JSON cache in the app's iOS Caches directory. The cache contains the complete decoded ATOM ground-station snapshot and the time of the last successful refresh.

When ATOM Monitor starts, it loads the most recent cached snapshot immediately before attempting the startup server refresh. This means Map, Stations and Favourites can display the previous known data while a new request is in progress rather than starting with an empty interface.

During normal refresh cycles the currently displayed snapshot remains in place until a complete new server response has been received and decoded. A successful response replaces the in-memory data and persistent cache as one snapshot. If the server, DNS, HTTPS connection or network is temporarily unavailable, the failed refresh reports the error but **does not erase the previous station data**.

The cache is deliberately a latest-snapshot cache, not a history database. It does not accumulate old station observations between refreshes and it contains no aircraft data. Because it is stored in the iOS Caches directory, iOS is permitted to purge it when reclaiming storage; the authoritative persistent station registry remains on the server.

### Home station
Choose **Home station** to define where the Map initially centres and zooms. Choose **Default UK view** to remove the preference. The Home button on the map returns to the configured station; if none is configured the app reports **No home station set**.

### Favourite stations
Favourite stations are stored locally on the iPhone and can be removed in Settings after being added from Map or Stations.

## Help and local User Guide
The Help tab contains the User Guide **inside ATOM Monitor itself**. Selecting **User Guide** opens a native SwiftUI guide within the app's NavigationStack. It does not open GitHub, Safari or another external web page and remains available without an Internet connection.

This Markdown file remains the repository-maintained documentation source/reference. User-facing help required for normal operation should also be reflected in the local in-app guide when functionality changes.

## Station details
Depending on source data, details may include station name, coordinates/altitude, observation and heartbeat times, software versions, CPU load/temperature, RAM, NTP timing, RF information, uptime and supply voltage. Unsupported data displays **Not reported** rather than a synthetic zero.

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
