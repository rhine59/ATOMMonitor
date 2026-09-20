# ATOM Monitor Setup and Operations

This document records the development, iPhone, GitHub, Synology and OGN diagnostic setup established for ATOM Monitor so far.

## Project scope

ATOM Monitor is an iPhone application for monitoring the operational health and technical status of PilotAware ATOM ground stations. It does **not** display or record aircraft movements.

The server-side collector follows the same rule: aircraft messages are discarded and must not be persisted or logged as diagnostic output.

## Repository

GitHub repository:

```text
rhine59/ATOMMonitor
```

Default development branch is `main`.

### Mac working copy

The established local project path on the Mac is:

```bash
cd ~/Documents/Xcode/ATOMMonitor
```

Update it with:

```bash
git pull
```

Git commands do not require `sudo`.

## iPhone / Xcode development setup

The iOS project is under:

```text
ios/
```

The project uses SwiftUI, targets iPhone, has an iOS 17 deployment target, and currently has no third-party runtime dependencies.

The Xcode project can be generated from `ios/project.yml` using XcodeGen when required.

Current bundle identifier:

```text
uk.co.rhine59.ATOMMonitor
```

When using a free Apple Personal Team, installation can fail if the iPhone already has the maximum number of apps signed by that free developer profile. That is a provisioning limit rather than an ATOM Monitor build failure.

## Current iOS data state

The iPhone app currently uses bundled fixture station data. PWMalham is the principal reference station. Other fixture coordinates and health states must not be treated as an authoritative live ATOM registry.

The intended next integration is an `APIStationRepository` backed by the Synology service after live receiver formats and the persistent station registry are established.

## Synology prerequisites

The Synology is used to run the server/collector in Docker.

Required facilities:

- SSH access to the Synology;
- Git installed;
- Docker/Container Manager with Docker Compose support;
- outbound TCP access to `aprs.glidernet.org` port `14580`;
- GitHub authentication for the private `rhine59/ATOMMonitor` repository.

### Command convention on Synology

**Git commands are run without `sudo`.**

Examples:

```bash
git status
git pull
git clone ...
```

**Docker and Docker Compose commands are run with `sudo`.**

Examples:

```bash
sudo docker ps
sudo docker compose ps
sudo docker compose up -d --build
sudo docker compose logs -f
```

Do not add `sudo` to Git commands merely because Docker requires it.

## Synology GitHub SSH authentication

SSH into the Synology from the Mac:

```bash
ssh <synology-user>@<synology-ip>
```

Confirm Git is available:

```bash
git --version
```

Create an SSH directory and key on the Synology:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "ATOMMonitor-Synology"
```

The default key path is suitable:

```text
~/.ssh/id_ed25519
```

Display the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Add that public key to the GitHub account under **Settings -> SSH and GPG keys -> New SSH key**. A useful title is `ATOMMonitor Synology`.

Test authentication from the Synology:

```bash
ssh -T git@github.com
```

On the first connection, inspect/accept GitHub's host-key prompt as appropriate. Successful authentication identifies the GitHub account even though GitHub does not provide an interactive shell.

## Clone onto Synology

The working example assumes the Synology Docker shared folder is:

```text
/volume1/docker
```

Clone the private repository using SSH:

```bash
cd /volume1/docker
git clone git@github.com:rhine59/ATOMMonitor.git
cd ATOMMonitor
git status
git remote -v
```

The resulting working tree should contain the project areas such as:

```text
docs/
ios/
server/
README.md
```

If the NAS uses a different volume/share path, substitute the real path rather than creating a second copy unnecessarily.

## Updating the Synology working copy

Git itself remains unprivileged:

```bash
cd /volume1/docker/ATOMMonitor
git pull
```

Then rebuild/restart Docker with `sudo`:

```bash
cd server
sudo docker compose up -d --build
```

Inspect status and logs with:

```bash
sudo docker compose ps
sudo docker compose logs -f ogn-station-probe
```

Ctrl-C stops following the log; it does not stop the running container.

To stop the compose stack:

```bash
sudo docker compose down
```

## OGN diagnostic collector

The diagnostic program is:

```text
server/diagnostic/ogn_station_probe.py
```

It makes a receive-only TCP connection to:

```text
aprs.glidernet.org:14580
```

The APRS login uses passcode `-1`, appropriate for this receive-only diagnostic client.

The diagnostic collector is intentionally not yet the production service or database. Its purpose is to establish the real receiver/status formats emitted by ATOM stations before freezing the parser and schema.

### Parser unit tests

From the repository root:

```bash
cd server/diagnostic
python3 -m unittest -v test_ogn_station_probe.py
```

### Probe the reference station

```bash
python3 ogn_station_probe.py --station PWMalham
```

### Probe the provisional PW prefix

```bash
python3 ogn_station_probe.py --prefix PW
```

`PW` is only a discovery hypothesis. It is not yet an authoritative rule identifying all PilotAware ATOM stations.

## Current diagnostic finding

The initial command:

```bash
python3 ogn_station_probe.py --prefix PW
```

successfully reached the APRS server and displayed:

```text
Connecting to aprs.glidernet.org:14580 …
Connected read-only; aircraft packets will be discarded.
```

but produced no station observations.

This means basic TCP connectivity is working. It does **not** establish that PWMalham is offline. The original parser accepted only specific `OGNSDR`/`OGNSXR` receiver formats, so the absence of parsed output may instead indicate that live ATOM traffic uses a different packet destination/format or that the provisional `PW` assumption is incomplete.

## Safe discovery mode

A discovery mode was therefore added to the probe. It is designed to diagnose the live stream without dumping general aircraft traffic.

After updating the Synology copy:

```bash
cd /volume1/docker/ATOMMonitor
git pull

cd server/diagnostic
python3 ogn_station_probe.py --prefix PW --discovery
```

Discovery mode:

- displays APRS server comment/login messages as `SERVER ...`;
- counts incoming packets without printing general aircraft packets;
- counts destination/TOCALL values;
- reports periodic `STATS ...` lines;
- prints `CANDIDATE ...` only when the source callsign itself matches the requested station/prefix;
- continues to avoid persistence of aircraft traffic.

A typical statistics line has the form:

```text
STATS seconds=30 packets=1234 server_comments=2 matching_sources=5 parsed_receiver_packets=0 top_destinations=[...]
```

A matching source candidate has the form:

```text
CANDIDATE source=PWxxxxx destination=xxxxx packet=...
```

Run discovery for several minutes and retain the `SERVER`, `STATS`, and relevant `CANDIDATE` output for parser development.

## Docker diagnostic collector

The repository contains:

```text
server/docker-compose.yml
server/diagnostic/Dockerfile
```

From the Synology repository:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose logs -f ogn-station-probe
```

The current compose service is the diagnostic probe, not yet the final ATOM Monitor API/database stack.

## Useful Synology diagnostics

Container overview:

```bash
sudo docker ps
sudo docker compose ps
```

Recent compose logs:

```bash
sudo docker compose logs --tail=100
```

Follow logs live:

```bash
sudo docker compose logs -f
```

For the specific probe:

```bash
sudo docker compose logs --tail=100 ogn-station-probe
sudo docker compose logs -f ogn-station-probe
```

Check the checked-out revision and local modifications without `sudo`:

```bash
cd /volume1/docker/ATOMMonitor
git status
git log -1 --oneline
```

## Current development sequence

1. Run the safe discovery probe against the live OGN feed.
2. Capture only representative receiver/station messages required for tests; do not build an aircraft-traffic archive.
3. Determine the actual ATOM receiver packet variants and a reliable station-identification/registry source.
4. Extend parser tests from the verified live receiver formats.
5. Add persistent station/current-health/history storage on the Synology.
6. Add the REST API (`/api/stations`, station detail/history, service health).
7. Replace iOS fixture data with the API repository.
8. Derive health state from measured heartbeat cadence and telemetry rather than hard-coded fixture state.

## Important interpretation rules

- No output from a provisional parser is not proof that a station is offline.
- `PW` is not yet an authoritative ATOM classifier.
- A station must remain in a persistent registry even when silent, otherwise a failed station would simply disappear from the map.
- Missing telemetry should be represented as `Not reported`, not silently converted to zero.
- The UI term for an overdue station is `No recent heartbeat`, not a definitive `Offline` state.
- Aircraft identities, positions, tracks and movement history are outside ATOM Monitor's scope and must not be stored.

## Documentation rule: rebuild from scratch

The repository documentation must be sufficient to recreate the ATOM Monitor environment from a clean machine/NAS rather than merely describe the current running state. Every infrastructure, deployment, database, networking, secret/configuration, build or runtime change must therefore update the relevant setup/runbook documentation in the same development cycle.

The rebuild instructions must be step-by-step and include prerequisites, repository checkout, required directory layout, ignored local configuration and how to generate/populate it without committing secrets, Docker/Compose build and startup, PostgreSQL creation/persistence, load-balancer configuration, collector startup, DSM reverse proxy/TLS/router requirements, health/readiness tests, expected results, persistence/recovery checks and rollback boundaries. Commands must be usable from a clean checkout, with platform-specific assumptions stated explicitly.

A change is not documentation-complete if a future clean rebuild would depend on an undocumented setting that exists only on the current Synology host.
\n\n## Checkpoint synchronization — 18 September 2026\n\nCurrent clean-rebuild target is PostgreSQL persistent named volume, two stateless API replicas, Nginx publishing host port 8088 and one single-active collector posting through Nginx. The complete acceptance suite passed this topology. Recreating an existing registry from scratch still requires a tested PostgreSQL restore procedure; do not substitute the historical SQLite backup path. See `CHECKPOINT-2026-09-18.md`.\n

## Per-container build scripts — 19 September 2026

For routine component-level rebuild/start verification from the repository root, use `scripts/build-postgres.sh`, `build-api.sh`, `build-nginx.sh`, or `build-collector.sh`. Run all four in dependency order with `sh scripts/build-all-containers.sh`. PostgreSQL and Nginx use upstream images and are pulled/started; API and collector are locally built. None of these scripts removes the PostgreSQL named volume or prints `.env`. Full resilience testing remains under the Phase acceptance scripts.


## Admin monitor local configuration

Create a separate administrator secret in `server/.env`:

```text
ATOM_ADMIN_TOKEN=<strong separate local secret>
```

Do not reuse `ATOM_INGEST_TOKEN`. The Compose stack now includes `atom-admin-monitor`, built from `server/Dockerfile.admin`. It is private to the Compose network and reached externally only through Nginx's authenticated `/api/v1/admin/` route. No admin scale endpoint exists in this first slice.
