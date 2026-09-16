# ATOM Monitor User Guide

## What ATOM Monitor does
ATOM Monitor is an iPhone application for viewing the operational health and technical status of PilotAware ATOM ground stations. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen
The application has Map, Stations, Favourites, Settings and Help tabs.

## Map
The map uses the complete available iPhone display dynamically and adapts to different screen sizes. Clusters separate as the map is zoomed. Tapping a station opens its complete detail directly. Marker colour represents derived health: green Healthy, amber Warning, red No recent heartbeat and grey Unknown.

The initial map view centres on the Home station selected in Settings, or uses the default wider UK view.

## Stations
Stations shows the complete persistent station registry rather than only transmitters heard at that instant. Selecting a station opens its detailed status.

## Favourites
Favourites provides a quick operational-health view of selected stations. Favourites are an iPhone-side view/filter and do not change server collection.

## Settings

### Server
The server address can be edited and saved in Settings. **Test Connection** checks the configured service before it is relied upon. Normal remote operation should use the public HTTPS DNS address rather than the Synology LAN IP.

### Data refresh
ATOM Monitor fetches the station registry **once immediately when the app starts**. It then automatically fetches fresh data at the configured interval.

The default interval is **1 minute**. In **Settings → Data refresh**, use **Refresh interval** to choose any whole-minute value from **1 to 10 minutes**. The selected interval is stored on the iPhone and used on later launches.

Changing the interval restarts the refresh schedule and performs an immediate refresh, so the user does not have to wait for the previous timer to expire. A longer interval reduces network/API activity; a shorter interval provides more current station status. The permitted range deliberately prevents sub-minute polling.

Automatic refresh is an in-app foreground refresh mechanism. iOS may suspend application execution while ATOM Monitor is in the background; the setting does not promise exact background polling every N minutes.

### Home station
Choose **Home station** to define where the Map initially centres and zooms. Choose **Default UK view** to remove the preference.

### Favourite stations
Favourite stations are stored locally on the iPhone and can be removed in Settings after being added from Map or Stations.

## Help
Help contains an **Open User Guide** link to this maintained guide.

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
