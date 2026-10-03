# Checkpoint — Administrator Control Plane — 3 October 2026

## Outcome

The ATOM Monitor Docker control plane, iOS Admin implementation and cross-platform source contract are synchronized.

The live iPhone flow has demonstrated LAN QR pairing, one-time exchange, Keychain storage and authenticated Admin access. Scaling initially exposed a 15-second Nginx timeout; the timeout chain is now ordered around a 90-second Docker-health readiness window. The Admin inventory now reports the monitoring and control containers themselves.

## Current Docker topology

| Service | Admin inventory | Mobile mutation |
|---|---:|---:|
| `postgres` | Yes | No |
| `atom-api` | Yes, every replica | Scale 1–4 only |
| `atom-lb` | Yes | No |
| `ogn-station-probe` | Yes | No |
| `atom-admin-monitor` | Yes | No |
| `atom-admin-control` | Yes | No |

`atom-admin-monitor` exposes the authenticated external Admin API and has read-only Docker access. `atom-admin-control` is internal-only, has writable Docker access and accepts only bounded API scaling and audit reads. The public station API has no Docker socket.

## Authentication

- Pairing page is limited to `ATOM_ADMIN_PAIRING_NETWORKS`.
- Pairing codes are random, five-minute and single-use.
- Pending challenge hashes persist in `/data/admin-pairings.json`.
- Device credential hashes persist in `/data/admin-devices.json`.
- iOS stores the device credential in Keychain and uses device authentication.
- Android stores it with Android Keystore; runtime device acceptance is pending.
- Shared server Admin/control secrets are not entered on phones.

## Scaling timeout chain

| Layer | Timeout |
|---|---:|
| Control readiness | 90 seconds |
| Monitor → control | 100 seconds |
| Nginx Admin route | 105 seconds |
| iOS/Android client | 120 seconds |

This order ensures the controller returns success or failure before an outer layer terminates the request.

## Mobile contract

Both apps decode/iterate the generic `containers` array. Adding the two Admin services to the server allow-list therefore needs no platform-specific service enumeration.

Both apps provide confirmed 1–4 API scaling only. Neither exposes generic Docker commands or controls for singleton services.

Navigation is synchronized:

- Primary: Map, Stations, Favourites, Report, More.
- More, alphabetically: About, Admin, Feedback, Help, Legend, Settings.
- Legend covers all operational icon colours and shows Back-level software only when that setting is enabled.

## Repeatable rebuild and acceptance

```bash
cd /volume1/docker/ATOMMonitor
git pull --ff-only
sh scripts/build-all-containers.sh
sh scripts/all-phases-acceptance.sh
```

For the scaling acceptance, export the server-side `ATOM_ADMIN_TOKEN` in the shell and run:

```bash
sh scripts/admin-scaling-acceptance.sh
```

Acceptance requires 2→3→2 healthy API replicas, uninterrupted public station reads, audit events, and unchanged healthy singleton counts for PostgreSQL, Nginx, collector and both Admin services.

## Verification status

- Server pairing and physical-iPhone pairing: live-tested.
- Admin timeout and self-monitoring changes: deployed behaviour reported good; repeatable Synology acceptance remains the release gate.
- iOS build 1.0 (4): source checkpoint; rebuild/regression required before TestFlight upload.
- Android version code 4: source parity; build and device-runtime verification pending.
