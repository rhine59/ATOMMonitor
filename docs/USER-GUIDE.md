# ATOM Monitor User Guide

## What ATOM Monitor does

ATOM Monitor is an iPhone application for viewing the operational health and technical status of PilotAware ATOM ground stations.

It is a ground-station monitor only. It does **not** display, record or retain aircraft movements, tracks or aircraft identities.

## Main screen

The application uses four buttons/tabs at the bottom of the iPhone screen:

- **Map** — displays ATOM stations geographically and provides station search.
- **Stations** — displays the available ATOM stations as a list and provides access to station details.
- **Settings** — selects the home ATOM station used for the initial map position.
- **Help** — displays application help and a hyperlink to this User Guide.

The navigation title is **ATOM Stations**.

## Map

The map uses the available iPhone display area between the navigation title and bottom tab bar and adapts to different iPhone screen sizes and orientations.

Use the search field to filter stations by name. Selecting an individual station marker displays a compact summary and a link to the station detail screen.

### Station clustering

When multiple stations would overlap at the current map scale, ATOM Monitor combines them into a single circular cluster marker showing the number of stations in that area. The clustering grid scales with the visible map region, so clusters break into smaller clusters and then individual station markers as the map is zoomed in.

Tap a numbered cluster marker to zoom further into that group. Normal pinch-to-zoom and pan gestures can also be used. Zooming out causes nearby station markers to combine again.

### Home station

The Map tab initially centres and zooms around the **Home station** selected in Settings. The selection is stored locally on the iPhone. If no home station is selected, the application uses its default wider UK map view.

Changing the home station causes the map to move to the newly selected station when the Map view applies the setting.

Station marker colour represents the derived health state:

- **Green — Healthy**: a recent heartbeat has been received and no known health condition currently raises a warning.
- **Amber — Warning**: telemetry is stale or a monitored technical value is abnormal.
- **Red — No recent heartbeat**: the station has not reported within the configured heartbeat threshold.
- **Grey — Unknown**: insufficient information is available to determine health.

Health thresholds remain under development while actual ATOM reporting cadence is measured.

## Stations

The Stations tab provides a non-map view of the station registry. Selecting a station opens its detailed status.

The production registry is intended to retain known ATOM stations even when they stop reporting. A failed or silent station must therefore remain visible rather than disappearing merely because no live packet is being received.

## Settings

Open **Settings** from the bottom tab bar and choose **Home station**. The picker lists the stations currently available to the app. Choose **Default UK view** to remove the home-station preference.

The home-station preference is an iPhone display setting; it does not alter the ATOM station itself or the server data.

## Help

The Help tab gives a short description of ATOM Monitor and an **Open User Guide** hyperlink to this maintained project guide.

## Station details

Depending on what a station reports, details may include station name; latitude, longitude and altitude; most recent position/status report; most recent PilotAware heartbeat; software version; CPU load and temperature; RAM usage; NTP timing; RF frequency correction and signal-quality information; and uptime or supply voltage when supplied by the station.

A field that the station does not provide should be shown as **Not reported** rather than as zero.

## PilotAware identification

Live OGN/APRS testing has shown PilotAware stations transmitting heartbeat messages containing the marker:

```text
OGN-R/PilotAware
```

The current discovery process also uses station names beginning `PW`, but the `PW` prefix alone is not treated as the final authoritative definition of a PilotAware ATOM station.

## Data and privacy scope

ATOM Monitor's server consumes ground-receiver/status information required to monitor ATOM stations. Aircraft traffic is outside the project's scope and must not be stored as aircraft tracks, identities or movement history.

## Current development status

The iPhone application currently contains development/fixture station data while the Synology collector and persistent ATOM station registry are being developed. Live OGN/APRS receiver data has been successfully received from PilotAware stations, and the next server stage is to merge station position, PilotAware heartbeat and technical-health observations into persistent station records exposed to the iPhone application through the API.

## Troubleshooting

The safe discovery command currently used for PilotAware investigation is:

```bash
cd /volume1/docker/ATOMMonitor/server/diagnostic
python3 ogn_station_probe.py --prefix PW --discovery
```

For a specific known station, for example PWFirefly:

```bash
python3 ogn_station_probe.py --station PWFirefly --discovery
```

The diagnostic collector deliberately does not dump general aircraft traffic.
