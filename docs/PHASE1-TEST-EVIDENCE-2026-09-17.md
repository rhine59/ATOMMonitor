# Phase 1 resilience test evidence — 17 September 2026

This file records runtime evidence for the ATOM Monitor Synology deployment. No secrets or aircraft data are recorded here.

## Public API and ingestion boundary

- Public HTTPS endpoint and TLS validation passed for `/health`, `/ready`, and station reads.
- `/ready` reported the persistent confirmed PilotAware station registry successfully.
- The authenticated internal OGN collector continued to receive HTTP 202 from `POST /api/v1/observations`.
- An unauthenticated public HTTPS POST to `/api/v1/observations` returned HTTP 401.
- The ingestion token is held in local `server/.env`; the token value is not committed.
- Physical iPhone Test Connection using `/ready` passed, and Stations/Map loaded normally.

## Docker resilience

Controlled API restart passed: readiness returned, the persistent station registry remained intact, and the collector resumed accepted station-only observations.

Gunicorn runtime passed with two workers/two threads, readiness and station reads operational, and collector ingestion continuing.

Two normal-operation `docker stats --no-stream` samples showed stable, low resource use:

| Container | Sample 1 CPU | Sample 1 memory | Sample 2 CPU | Sample 2 memory |
|---|---:|---:|---:|---:|
| atommonitor-api | 1.27% | 84.11 MiB | 0.87% | 83.95 MiB |
| atommonitor-ogn-probe | 0.49% | 23.06 MiB | 0.16% | 23.21 MiB |

Host memory limit reported by Docker was 15.48 GiB. The two samples do not indicate memory growth. Tight arbitrary container memory/CPU limits were therefore not introduced at this checkpoint; resource usage remains an operational monitoring item.

## Stale-observation protection — pre-deployment unit test

The stale-observation implementation was committed in `f3058c1` and tests in `89f066e`.

Tests were run on the Synology using the rebuilt Compose API image with a temporary SQLite database, not the live registry:

```text
python -m unittest -v test_app.py

test_categories_are_ordered_independently ... ok
test_newer_packet_updates_same_category ... ok
test_older_position_does_not_replace_newer_position ... ok
test_older_status_does_not_replace_newer_status_fields ... ok

Ran 4 tests in 1.013s
OK
```

This proves the unit-test cases for independent category ordering, acceptance of newer packets, and rejection of older position/status replacement. Live deployment verification is still required before stale-observation protection is marked Tested.
