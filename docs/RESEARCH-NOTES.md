# Research Notes

## 2026-09-15 — Initial concept

Goal established: native iPhone application to inspect PilotAware ATOM ground-station status/details.

Initial PilotAware Groundstation Playback example demonstrated a station-oriented web data source with query parameters including station, receiver type, ICAO and time range. The page loads results dynamically, so the underlying request would need separate investigation before programmatic use.

## APRS/OGN direction

The project considered conventional APRS/APRS.fi, then narrowed the focus to the Open Glider Network APRS infrastructure because OGN explicitly carries receiver status and OGN implementations parse receiver-status beacons.

OGN APRS uses TCP port 14580 with server-side APRS filtering. Receiver-status fields include status/version/CPU/RF/temperature, with packet contents varying by receiver/software.

## 2026-09-16 — Live ATOM feed confirmed

A live Synology probe connected successfully to `aprs.glidernet.org:14580` as the receive-only/unverified client `ATOMMON`. With no server-side filter, only APRS server keepalive/comment lines arrived. Adding the APRS prefix filter `p/PW` immediately produced live `PW...` source packets.

Observed candidate stations included `PWNesclif`, `PWEDRPACP`, `PWRankins`, `PWFirefly`, `PWEGBS` and `PWAachen`.

Three useful packet types/patterns were observed:

1. `OGNSDR` position packets containing APRS latitude/longitude and `/A=` altitude.
2. `OGNSDR` technical-health packets containing fields such as receiver software version, CPU load, RAM usage, NTP offset/correction, temperature, EGM96 offset and RF metrics.
3. A separate `APRS` status/heartbeat packet with a body of the form `v20260707 OGN-R/PilotAware`.

`OGN-R/PilotAware` is direct evidence in the live packet body that the source is running PilotAware OGN-R software. This is a substantially stronger ATOM classification signal than the `PW` prefix alone. The `PW` prefix remains useful as a server-side discovery filter, but application-level classification should use the PilotAware marker where available.

The live sample also shows that a station can emit a PilotAware heartbeat via destination `APRS` while its lower-level OGN receiver telemetry is sent separately via destination `OGNSDR`. The production model should therefore merge observations by station/source callsign rather than expect one packet to contain all health data.

### Example fields confirmed live

A live `PWEDRPACP` OGNSDR status observation contained software `v0.3.2.ARM`, CPU, RAM, NTP, temperature, EGM96 and multiple RF measurements. A live `PWEGBS` observation showed the same general structure with different values. These confirm that the technical fields targeted by the ATOM Monitor data model are genuinely available for at least some live `PW` receivers.

Aircraft-count fragments such as `Acfts[1h]` may occur inside receiver-health packets. ATOM Monitor does not need aircraft identity, position or movement data; these aggregate receiver-health fragments are not used to build aircraft tracking functionality.

## 2026-09-16 — PWFirefly cadence measurement

A dedicated `b/PWFirefly` APRS server filter was observed continuously for more than eleven minutes. It produced a highly regular pair of station reports.

The `OGNSDR` position packet timestamps were `11:30:15`, `11:35:15` and `11:40:15` UTC: exactly **300 seconds (5 minutes)** apart in this sample.

The PilotAware heartbeat timestamps were `11:31:58`, `11:36:49` and `11:41:40` UTC: exactly **291 seconds (4 minutes 51 seconds)** apart in both measured intervals. Each heartbeat contained `v20260707 OGN-R/PilotAware`.

PWFirefly's observed position was `50°47.70 N, 003°11.98 W` with `/A=000525` (525 ft). No detailed CPU/RAM/NTP/RF technical-status packet was seen from PWFirefly during this observation window, so absence of those fields must not by itself imply a station fault.

This measurement is strong evidence that a healthy ATOM can have an approximately five-minute reporting cadence. It is still only one station/sample, so final health thresholds should be validated against several ATOM stations before being frozen. A threshold below five minutes would clearly risk false warnings for stations behaving like PWFirefly.

## PWMalham

`PWMalham` remains an earlier reference station. Research via OGN/KTrax-associated data showed it as a ground receiver and demonstrated the type of station-level metadata/history we want to reproduce from underlying sources rather than depending on a third-party UI.

Do not treat previously observed PWMalham numeric values as permanent station facts; they were time-specific observations.

## Key discovery: live discovery is insufficient

A health monitor cannot build its map solely from stations currently transmitting. A station that was already down when the collector started would never appear. Therefore the project needs both:

1. a persistent/bootstrapped ATOM station registry; and
2. live health observations that update that registry.

Finding a reliable complete bootstrap source remains a high-priority research task.

## Questions still open

- Is the approximately five-minute reporting cadence seen at PWFirefly representative across current ATOM stations?
- Does every current PilotAware ATOM emit the exact `OGN-R/PilotAware` marker?
- Does every PilotAware ATOM use a `PW...` station identifier? The prefix must not yet be treated as authoritative.
- How consistent are OGNSDR health fields across ATOM hardware/software versions?
- How often are detailed CPU/RAM/NTP/RF status packets emitted, and do all ATOM stations emit them?
- Is there a PilotAware-published complete station list/map data endpoint suitable for registry bootstrap?
- Can an OGN receiver-list endpoint provide inactive receivers for registry bootstrap?
- What is the best production server-side filter while retaining all ATOM stations and excluding unnecessary traffic?
- Which health thresholds are meaningful after observing several real stations?

## Research discipline

Separate three categories in future notes:

- **Confirmed:** supported by current source documentation or captured live packets.
- **Observed:** seen at a particular time/station but not guaranteed universally.
- **Hypothesis:** architectural assumption requiring validation.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe current tested implementation uses the station-only OGN/APRS collector, PostgreSQL persistence and two stateless APIs behind Nginx. Research notes remain background evidence; current runtime truth is captured in the architecture, runbook and 18 September checkpoint. See `CHECKPOINT-2026-09-18.md`.\n