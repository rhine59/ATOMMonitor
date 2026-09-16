# ATOM Monitor Server

The server collects ground-receiver health/status observations, maintains a persistent ATOM station registry/history, derives health states, and will expose HTTPS/JSON to the iPhone app.

## Diagnostic collector now implemented

`diagnostic/ogn_station_probe.py` is the first live-data component. It opens a read-only TCP connection to `aprs.glidernet.org:14580`, logs in with passcode `-1`, accepts OGN receiver position/status packets (`OGNSDR` and `OGNSXR`), and discards aircraft packets before output.

It intentionally has no database yet. Its purpose is to establish what PilotAware ATOM stations actually emit before we freeze the production parser/schema.

### Local test

```bash
cd server/diagnostic
python3 -m unittest -v test_ogn_station_probe.py
python3 ogn_station_probe.py --station PWMalham
```

To discover station receiver packets whose names begin with `PW`:

```bash
python3 ogn_station_probe.py --prefix PW
```

The output is newline-delimited JSON containing station observations only. Ctrl-C stops the probe.

### Synology / Docker Compose

The repository compose file defaults to `--prefix PW`:

```bash
cd server
docker compose up -d --build
docker compose logs -f ogn-station-probe
```

Stop it with:

```bash
docker compose down
```

The Synology host must be able to make outbound TCP connections to port 14580.

## Parser coverage

The diagnostic parser currently understands the two receiver formats documented by OGN that matter to initial investigation:

- `OGNSDR` receiver position/status, including software, CPU, RAM, NTP, temperature and RF values where present;
- `OGNSXR`/OGNbase receiver position/status, including software, voltage, time-sync state and uptime where present.

The parser does not interpret or retain aircraft-count fields even when a receiver status line includes them.

## Strict scope rule

The server is not an aircraft tracker. Aircraft position/identity messages must not be persisted. The diagnostic probe parses only receiver packets and prints only those parsed station observations; unrelated/aircraft packets are discarded.

## Important limitations

A `PW` callsign prefix is currently only a discovery hypothesis for PilotAware ATOM stations, not an authoritative classifier. Likewise, receiving a heartbeat does not by itself prove every ATOM subsystem is healthy. We will derive health thresholds only after observing real reporting intervals and fields.

## Next milestone

1. Run the probe against the live feed long enough to observe PWMalham and other candidate `PW*` receiver messages.
2. Save only representative receiver-status fixtures (never aircraft traffic) as parser tests.
3. Determine reliable ATOM identification and station registry bootstrap data.
4. Implement persistent station/current-health storage and FastAPI endpoints.
5. Replace the iOS fixture repository with `APIStationRepository`.
