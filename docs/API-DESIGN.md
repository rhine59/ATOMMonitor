# REST API Design

Draft interface between the Synology-hosted service and the iPhone app.

## Principles

- HTTPS JSON.
- iPhone does not parse APRS.
- Map request is compact and fast.
- Detailed/history data is fetched on demand.
- API distinguishes observed fields from derived health state.

## Candidate endpoints

### `GET /api/v1/stations`

Returns enough data for the map and search.

```json
[
  {
    "id": "PWMalham",
    "name": "PWMalham",
    "latitude": 54.002,
    "longitude": -2.142,
    "altitude_m": 147,
    "health": "healthy",
    "health_reason": null,
    "last_heartbeat_at": "2026-09-15T18:30:00Z"
  }
]
```

Values above are illustrative; live values must come from the server.

### `GET /api/v1/stations/{id}`

Returns full current details including optional system/time/RF telemetry.

### `GET /api/v1/stations/{id}/history?range=24h`

Returns time-series observations suitable for charting. Candidate ranges: `24h`, `7d`, `30d`.

### `GET /api/v1/health`

Service health, upstream OGN connection state, last upstream message/status observation and database connectivity. This is important so the iPhone can distinguish `the collector cannot see OGN` from `a particular ATOM has stopped reporting`.

## Versioning

Start at `/api/v1`. Avoid exposing database structure directly so server persistence can evolve independently of the iOS app.

## Caching

Station map data can use conditional requests/ETags or a short cache interval. Historical series can be cached more aggressively than latest health.
