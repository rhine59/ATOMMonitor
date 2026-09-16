# ATOM Monitor — Live Integration Tests

This file records measured end-to-end tests of the live ATOM Monitor data path. It is deliberately separate from design assumptions and provisional thresholds.

## 16 September 2026 — first Synology live integration run

### Scope

The test exercised the live server path:

```text
OGN APRS
  -> ATOM Monitor OGN collector
  -> PilotAware/ATOM classification
  -> REST observation endpoint
  -> SQLite persistent station registry
  -> REST station/health endpoints
```

The project processes ATOM ground-station health/status only. Aircraft identities, aircraft positions, movements and tracks are not stored by this pipeline.

### Deployment findings

Two deployment prerequisites were discovered and fixed during the run:

1. Synology DSM nginx was already listening on host TCP port 8080. ATOM Monitor was therefore moved to host port **8088**, while the API continues to listen on port 8080 inside the Docker network.
2. The persistent bind-mount directory `server/data` did not initially exist. The repository now contains `server/data/.gitkeep`, and the build/test script creates the directory before starting Docker.

After those fixes, both containers started successfully. The API was published as `0.0.0.0:8088->8080/tcp`. The automated build/test completed with its PASS result. An initial curl connection reset occurred while Flask was starting; the retry immediately succeeded and `/health` returned HTTP success.

### Initial API result

Immediately after container startup:

```text
confirmedStations: 0
station_count: 0
```

This was expected at that instant because the collector had only just started and confirmation requires a recognised PilotAware heartbeat.

### First live populated snapshot

After allowing the collector to receive live traffic:

```text
Total confirmed stations:       301
Health:
  healthy:                      301
With position:                   65
With PilotAware version:        301
With technical status:          254
```

Coverage at this snapshot:

- position: 65 / 301 = **21.6%**
- PilotAware version: 301 / 301 = **100%**
- technical status: 254 / 301 = **84.4%**

The 301/301 PilotAware-version result is consistent with the explicit PilotAware heartbeat being the confirmation signal used by the API registry.

### Later snapshot

After a further collection interval:

```text
Total confirmed stations:       301
Health:
  healthy:                      299
  warning:                        2
With position:                  199
With PilotAware version:        301
With technical status:          258
```

Coverage at this snapshot:

- position: 199 / 301 = **66.1%**
- PilotAware version: 301 / 301 = **100%**
- technical status: 258 / 301 = **85.7%**

### Conclusions supported by this run

The live OGN-to-API pipeline is operational. The collector is receiving live traffic, recognised PilotAware stations are being confirmed, observations are reaching the API, and confirmed station state is being persisted and returned by the station API.

Position coverage increased from 65 to 199 records without changing the registry size, demonstrating that the persistent records are being enriched as additional packet types arrive. This is important because station heartbeat, position and technical-status packets do not necessarily arrive together.

The health distribution changed from 301 healthy to 299 healthy / 2 warning. This is useful evidence that health is being recalculated from heartbeat age rather than permanently fixed at the state assigned on discovery. It is not, by itself, sufficient evidence that the current heartbeat thresholds are optimal.

Detailed technical-status coverage was already high (84.4%) and increased to 85.7%. Missing optional technical telemetry must continue to be represented as not reported rather than automatically treated as a station fault.

### Items still under test

The following remain validation tasks rather than established conclusions:

- Observe stations long enough to confirm transitions through warning and `noRecentHeartbeat`, including recovery after a later heartbeat.
- Measure heartbeat cadence across multiple stations before freezing production health thresholds.
- Determine the eventual saturation level of station coordinates. At the later snapshot 102 of 301 confirmed stations still had no position in the registry.
- Verify persistence and health calculation across a collector/API container restart and a full Synology reboot.
- Exercise the iPhone client against the live 8088 API, including decoding, map display, station detail, favourites and offline cache behaviour.

## Reproducing the station coverage snapshot

On the Synology:

```sh
curl -s http://localhost:8088/api/v1/stations | \
python3 -c 'import sys,json; d=json.load(sys.stdin); from collections import Counter; print("Total:",len(d)); print("Health:",Counter(x["health"] for x in d)); print("With position:",sum(x.get("latitude") is not None and x.get("longitude") is not None for x in d)); print("With PilotAware version:",sum(x.get("pilotAwareVersion") is not None for x in d)); print("With technical status:",sum(x.get("lastTechnicalStatus") is not None for x in d))'
```

This command intentionally reports aggregate ground-station registry coverage only.
