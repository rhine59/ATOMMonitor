# ATOM Monitor User Guide

## What ATOM Monitor does

ATOM Monitor is an iPhone application for viewing the operational health and technical status of PilotAware ATOM ground stations.

It is a ground-station monitor only. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen

The application uses five buttons/tabs at the bottom of the iPhone screen:

- **Map** — displays ATOM stations geographically and provides station search.
- **Stations** — displays all ATOM stations known to the station registry and provides access to station details.
- **Favourites** — provides a quick health/status page for stations selected as favourites.
- **Settings** — selects the home ATOM station and defines favourite stations.
- **Help** — displays application help and a hyperlink to this User Guide.

## Map

The map uses the available iPhone display area between the navigation title and bottom tab bar and adapts to different iPhone screen sizes.

When multiple stations overlap at the current map scale, ATOM Monitor combines them into a numbered cluster. Clusters separate into smaller groups and then individual station markers as the map is zoomed in. Tapping a cluster zooms into that group.

The Map tab initially centres and zooms around the **Home station** selected in Settings. If no home station is selected, the application uses its default wider UK view.

Station marker colour represents the derived health state: green Healthy, amber Warning, red No recent heartbeat and grey Unknown. Health thresholds remain under development while actual ATOM reporting cadence is measured.

## Stations

The Stations tab is the complete station view. As the production station registry is populated, **all known ATOM stations are to appear here**, not merely stations that are transmitting at that moment. A station that becomes silent therefore remains in the registry and can change health state rather than disappearing.

Selecting a station opens its detailed status.

## Favourites

The Favourites tab is a quick operational-health view for the subset of ATOM stations that matter most to the user.

Each favourite displays its station name, current derived health state, last heartbeat when available and coordinates. Selecting the row opens the complete Station Details page.

Favourites do not alter server collection. The server continues to collect and maintain all ATOM stations; favourites are simply an iPhone-side view/filter of the complete registry.

If no favourites have been selected, the page directs the user to Settings.

## Settings

### Home station

Choose **Home station** to define where the Map tab initially centres and zooms. Choose **Default UK view** to remove the preference.

### Favourite stations

The **Favourite stations** section lists all stations currently known to the app. Tap the star beside a station to add or remove it from Favourites. A filled star identifies a favourite.

The selections are stored locally on the iPhone. As the live station registry replaces the development fixture data, this Settings list is intended to contain every ATOM station collected by the server.

## Help

The Help tab contains an **Open User Guide** hyperlink to this maintained project guide.

## Station details

Depending on what a station reports, details may include station name; latitude, longitude and altitude; most recent position/status report; most recent PilotAware heartbeat; software version; CPU load and temperature; RAM usage; NTP timing; RF frequency correction and signal-quality information; and uptime or supply voltage when supplied by the station.

A field that the station does not provide should be shown as **Not reported** rather than as zero.

## PilotAware identification

Live OGN/APRS testing has shown PilotAware stations transmitting heartbeat messages containing the marker:

```text
OGN-R/PilotAware
```

The `PW` prefix is useful for discovery but is not treated by itself as the final authoritative definition of a PilotAware ATOM station.

## Data and privacy scope

ATOM Monitor's server consumes ground-receiver/status information required to monitor ATOM stations. Aircraft traffic is outside the project's scope and must not be stored as aircraft tracks, identities or movement history.

## Current development status

The iPhone application currently contains development/fixture station data while the Synology collector and persistent ATOM station registry are being developed. Live OGN/APRS receiver data has been successfully received from PilotAware stations. The server stage will merge station position, PilotAware heartbeat and technical-health observations into persistent station records exposed to the iPhone application through the API.

## Troubleshooting

The safe broad discovery command is:

```bash
cd /volume1/docker/ATOMMonitor/server/diagnostic
python3 ogn_station_probe.py --prefix PW --discovery
```

To display and save the diagnostic output simultaneously:

```bash
python3 ogn_station_probe.py --prefix PW --discovery 2>&1 | tee atom_discovery.log
```

The diagnostic collector deliberately does not dump general aircraft traffic.
