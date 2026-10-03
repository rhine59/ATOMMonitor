# ATOM Monitor Server

The server collects ground-receiver health/status observations, maintains a persistent ATOM station registry/history, derives health states, and will expose HTTPS/JSON to the iPhone app.

For the complete Mac, GitHub, Synology, Docker and diagnostic setup procedure, see [`../docs/SETUP.md`](../docs/SETUP.md).

## Diagnostic collector now implemented

`diagnostic/ogn_station_probe.py` is the first live-data component. It opens a read-only TCP connection to `aprs.glidernet.org:14580`, logs in with passcode `-1`, parses known OGN receiver position/status formats, and discards unrelated/aircraft packets before normal output.

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

The original live test connected successfully but returned no parsed `PW` observations. This is not evidence that PWMalham is offline: it may indicate that the live packet format or station-identification assumption differs from the initial parser.

### Safe discovery mode

Use:

```bash
python3 ogn_station_probe.py --prefix PW --discovery
```

Discovery mode prints APRS server messages, aggregate packet/destination statistics, and raw candidate packets only when the source callsign matches the requested station/prefix. It does not dump general aircraft traffic.

Typical diagnostic output includes `SERVER`, `STATS`, and, when found, `CANDIDATE` lines. This lets us identify the real ATOM receiver format without turning ATOM Monitor into an aircraft feed logger.

### Synology / Docker Compose

On the established Synology setup, **Git commands do not use `sudo` and Docker commands do**.

Update the repository:

```bash
cd /volume1/docker/ATOMMonitor
git pull
```

Start/rebuild the collector:

```bash
cd server
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose logs -f ogn-station-probe
```

Stop it with:

```bash
sudo docker compose down
```

The Synology host must be able to make outbound TCP connections to port 14580.

## Parser coverage

The diagnostic parser currently understands the initial documented receiver formats under investigation:

- `OGNSDR` receiver position/status, including software, CPU, RAM, NTP, temperature and RF values where present;
- `OGNSXR`/OGNbase receiver position/status, including software, voltage, time-sync state and uptime where present.

Discovery mode exists specifically because live ATOM packets may require additional parsing/classification rules.

The parser does not interpret or retain aircraft-count fields even when a receiver status line includes them.

## Strict scope rule

The server is not an aircraft tracker. Aircraft position/identity messages must not be persisted. Normal diagnostic output contains station observations only, and discovery output is restricted to aggregate statistics/server messages plus packets whose source callsign matches the explicitly requested station/prefix.

## Important limitations

A `PW` callsign prefix is currently only a discovery hypothesis for PilotAware ATOM stations, not an authoritative classifier. Likewise, receiving a heartbeat does not by itself prove every ATOM subsystem is healthy. We will derive health thresholds only after observing real reporting intervals and fields.

## Next milestone

1. Run the safe discovery probe against the live feed long enough to observe PWMalham and other candidate `PW*` receiver messages.
2. Save only representative receiver-status fixtures (never an aircraft-traffic archive) as parser tests.
3. Determine reliable ATOM identification and station registry bootstrap data.
4. Implement persistent station/current-health storage and FastAPI endpoints.
5. Replace the iOS fixture repository with `APIStationRepository`.


## Admin self-monitoring

The restricted Admin summary/container endpoints include `atom-admin-monitor` and `atom-admin-control` in their Compose-project allow-list. They are visible health/resource entries only. The private scaling mutation remains restricted to `atom-api`.
