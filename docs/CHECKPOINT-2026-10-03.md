# ATOM Monitor Full Checkpoint — 3 October 2026

## Checkpoint status

All source, platform guides, architecture, deployment instructions, rebuild scripts, acceptance procedures and user documentation are synchronized on `main`.

This checkpoint records implementation and observed runtime evidence separately. It does not mark Android or the newest mobile build as tested without a build/device pass.

## Server and Docker

Current services:

| Service | Role | Health/inventory | Mutable from phone |
|---|---|---|---|
| `postgres` | Persistent station registry | Reported | No |
| `atom-api` | Stateless REST API replicas | Reported per replica | Scale 1–4 |
| `atom-lb` | Nginx routing/load balancing | Reported | No |
| `ogn-station-probe` | OGN/APRS station collector | Reported; activity healthcheck implemented | No |
| `atom-admin-monitor` | External authenticated Admin API/read-only Docker metrics | Reported | No |
| `atom-admin-control` | Internal bounded scaling/audit boundary | Reported | No |

The collector now has a meaningful Docker healthcheck. A heartbeat file is refreshed on APRS connection/activity; activity older than 120 seconds becomes unhealthy. This replaces the former state where the process was running but had no Docker health classification.

The Admin inventory includes every service above. The mutation allow-list remains restricted to `atom-api`.

## Administrator access

- Pairing is allowed only from configured trusted networks.
- QR and manual pairing codes expire after five minutes and work once.
- Pending pairing challenges persist in the Admin data volume.
- Device credentials are individually revocable; only hashes persist server-side.
- iOS uses Keychain plus Face ID/device passcode.
- Android uses Android Keystore.
- Shared Admin/control secrets are never entered on phones.
- The live iPhone pairing flow has passed.

Scaling waits for healthy replicas with ordered timeouts:

| Layer | Timeout |
|---|---:|
| Controller readiness | 90 seconds |
| Monitor to controller | 100 seconds |
| Nginx Admin route | 105 seconds |
| Mobile clients | 120 seconds |

## iOS

Current source version: **1.0 (4)**.

Implemented:

- Report counts drill into filtered Stations lists.
- Back-level software highlighting defaults Off.
- More includes alphabetically ordered About, Admin, Feedback, Help, Legend and Settings.
- Legend follows configured station colours.
- Direct Admin QR scan, manual fallback, secure credential storage, unlock, revocation and API scaling.
- Generic container rendering includes both Admin services without hard-coded client service names.

The pairing flow has physical-iPhone evidence. The complete build 4 regression and TestFlight upload remain pending.

## Android

Current source version: **1.0, version code 4**.

Implemented source parity includes:

- Report drill-down.
- Default-Off back-level highlighting.
- Five primary destinations: Map, Stations, Favourites, Report and More.
- Alphabetic More list and station legend.
- Google code scanner, manual pairing fallback, Android Keystore credential protection and bounded API scaling.
- Generic Admin container rendering.

Android build and device-runtime acceptance remain pending and must not be inferred from source completion.

## Rebuild

On the Synology:

```bash
cd /volume1/docker/ATOMMonitor
git pull --ff-only
sh scripts/build-all-containers.sh
sh scripts/all-phases-acceptance.sh
```

The full container build order is PostgreSQL, API, collector, Admin and final Nginx recreation. It ends with pairing/exchange/authentication/revocation acceptance.

For guarded scaling acceptance, export the server-side `ATOM_ADMIN_TOKEN` and run:

```bash
sh scripts/admin-scaling-acceptance.sh
```

This verifies 2→3→2 API scaling, public-read continuity, audit evidence and unchanged healthy singleton counts, including both Admin services.

## Next release gates

1. Deploy the current collector image and confirm `ogn-station-probe` becomes Docker healthy.
2. Run the full Synology build and acceptance suites.
3. Build iOS 1.0 (4), perform the physical-device regression and upload only after it passes.
4. Build Android version code 4 and complete QR pairing, persistence, revocation, scaling, report drill-down and legend tests on a Google Play-enabled device.
