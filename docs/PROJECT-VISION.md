# Project Vision

## Vision

ATOM Monitor should make the health of the PilotAware ATOM ground-station network understandable at a glance on an iPhone.

The map is the product's home screen and principal navigation mechanism. Every known ATOM station should have a persistent geographic presence. The user can navigate around the map, search for a station, tap a marker, see a concise health summary, and drill into the technical detail reported by that station.

## Scope

ATOM Monitor monitors **ground-station health and station details only**.

In scope:

- ATOM station identity and persistent registry.
- Station coordinates and altitude/elevation when available.
- Last receiver/status heartbeat and age.
- Receiver software/version information.
- CPU, memory, temperature and uptime when reported.
- NTP/time-synchronisation health when reported.
- RF calibration/quality/status fields when reported.
- Current derived station-health state.
- Historical health observations and trends.
- Map navigation, clustering, station search, favourites and station details.
- Optional future notifications about favourite-station health.

Explicitly out of scope:

- Aircraft tracking.
- Aircraft position display.
- Flight playback.
- Recording aircraft identities or trajectories.
- Counting or profiling aircraft as an app feature.
- Collision/traffic awareness.
- Any implication that this app is a flight-safety or certified operational-status system.

The collector should discard aircraft position traffic rather than persist it.

## User experience principles

1. **Map first.** The user should see the network geographically immediately.
2. **Failures remain visible.** A station that stops reporting remains in the registry and on the map.
3. **No false precision.** A missing telemetry field is shown as `Not reported`, not zero.
4. **No false certainty.** Lack of a heartbeat is labelled `No recent heartbeat`, not necessarily `Offline`.
5. **Progressive detail.** Map marker -> summary card -> detailed health page -> historical charts.
6. **Useful on every iPhone size.** Layouts should use adaptive SwiftUI design rather than fixed dimensions.
7. **Data provenance matters.** The server should retain the source and observation time for health data where useful.

## Reference station

`PWMalham` is the initial development/reference ATOM station. It gives us a concrete target for validating station identity, coordinates, heartbeat/status packets, health fields, and stale-state behaviour.

## Long-term result

A user should be able to open ATOM Monitor, see the ATOM network as a health map, navigate to any known station, and answer: **Where is it? Is it reporting? When did it last report? What technical state is it reporting? Has that state changed over time?**
