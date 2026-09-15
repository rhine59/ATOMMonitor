# Research Notes

## 2026-09-15 — Initial concept

Goal established: native iPhone application to inspect PilotAware ATOM ground-station status/details.

Initial PilotAware Groundstation Playback example demonstrated a station-oriented web data source with query parameters including station, receiver type, ICAO and time range. The page loads results dynamically, so the underlying request would need separate investigation before programmatic use.

## APRS/OGN direction

The project considered conventional APRS/APRS.fi, then narrowed the focus to the Open Glider Network APRS infrastructure because OGN explicitly carries receiver status and OGN implementations parse receiver-status beacons.

Current research indicates OGN software commonly uses TCP port 14580 and server-side APRS filtering. Existing OGN code demonstrates receiver-status fields including status/version/CPU/RF/temperature, with packet contents varying by receiver/software.

This makes OGN APRS a strong candidate for live ATOM health, subject to validation against real ATOM stations and current upstream rules/documentation.

## PWMalham

`PWMalham` was selected as the initial reference station. Research via OGN/KTrax-associated data showed it as a ground receiver and demonstrated the type of station-level metadata/history we want to reproduce from underlying sources rather than depending on a third-party UI.

Do not treat previously observed PWMalham numeric values as permanent station facts; they were time-specific observations.

## Key discovery: live discovery is insufficient

A health monitor cannot build its map solely from stations currently transmitting. A station that was already down when the collector started would never appear. Therefore the project needs both:

1. a persistent/bootstrapped ATOM station registry; and
2. live health observations that update that registry.

Finding a reliable complete bootstrap source is currently one of the highest-priority research tasks.

## Questions still open

- What exact receiver/status packets does PWMalham currently emit?
- What is the normal status/heartbeat interval?
- How consistent are health fields across ATOM software versions?
- Does every PilotAware ATOM use a `PW...` station identifier, and is that convention sufficient to classify stations?
- Is there a PilotAware-published complete station list/map data endpoint suitable for use?
- Can an OGN receiver-list endpoint provide a bootstrap registry including inactive receivers?
- What server-side APRS filter gives the smallest receiver-status-only stream?
- What upstream usage/login requirements should the production collector follow?
- Which health thresholds are meaningful after observing real data?

## Research discipline

Separate three categories in future notes:

- **Confirmed:** supported by current source documentation or captured live packets.
- **Observed:** seen at a particular time/station but not guaranteed universally.
- **Hypothesis:** architectural assumption requiring validation.
