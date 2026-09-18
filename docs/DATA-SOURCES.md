# Data Sources

## Source strategy

ATOM Monitor should combine a persistent station registry with live technical observations. A live feed alone is insufficient because a failed station must remain visible after it stops transmitting.

## OGN APRS

Current preferred live source.

The Open Glider Network operates APRS infrastructure carrying ground-receiver status as well as other network data. Public OGN software demonstrates connections to `aprs.glidernet.org`/regional OGN APRS servers on TCP port `14580` with server-side filtering. OGN receiver-status parsing implementations expose fields such as receiver status, version, CPU, RF and temperature.

Relevant upstream references:

- OGN project: https://www.glidernet.org/
- OGN APRS protocol: https://github.com/glidernet/ogn-aprs-protocol
- Python OGN client: https://github.com/Meisterschueler/python-ogn-client
- OGN software examples: https://github.com/glidernet/

These links are research references; exact packet formats and acceptable connection/filter behaviour must be validated against current upstream documentation and live data before production use.

## PilotAware Playback

PilotAware Groundstation Playback is a potentially useful supplementary source. It accepts parameters such as station, receiver/transmission type, ICAO and time range and dynamically loads results. Its underlying data request still needs to be characterised before it is used programmatically.

Reference:

- https://playback.pilotaware.com/playback/groundstations/

Do not make the application dependent on an undocumented web endpoint without considering stability and permission/terms.

## KTrax

KTrax has proved useful for research because station-health pages expose useful receiver metadata and history for stations such as `PWMalham`. It should not currently be the primary production dependency because automated API access has its own access/subscription requirements.

Reference:

- https://ktrax.kisstech.ch/

## APRS.fi

Conventional APRS services were considered, but the relevant station-health path appears to be the OGN APRS infrastructure rather than assuming PilotAware station identifiers are conventional amateur APRS callsigns. APRS.fi therefore is not the preferred v1 source.

## Source-of-truth policy

Each canonical field should eventually have a documented source priority. Example:

- station identity/location: persistent registry, refreshed from authoritative/current observations;
- last heartbeat: OGN receiver/status observation;
- system/RF telemetry: OGN receiver/status observation;
- PilotAware-specific metadata: future PilotAware adapter if validated;
- derived health: ATOM Monitor server, based on observed timestamps/telemetry.

## Open problem: complete station bootstrap

The major unresolved data question is how to obtain a complete, reliable list of PilotAware ATOM stations and their last known coordinates. Waiting for live discovery alone is not enough: an already-failed station would never be discovered by a new installation.

Possible approaches to investigate:

1. an OGN receiver-list endpoint/feed;
2. a PilotAware-published ATOM station registry/map data source;
3. initial import from an appropriate public receiver registry followed by live OGN updates;
4. maintaining a project registry built from multiple validated sources.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe authoritative current server state is PostgreSQL plus two stateless APIs behind Nginx with a single-active station-only OGN/APRS collector. The complete Phase 1–4 plus service/API acceptance suite passed. Earlier source-research material remains useful background but does not supersede the tested runtime checkpoint. See `CHECKPOINT-2026-09-18.md`.\n