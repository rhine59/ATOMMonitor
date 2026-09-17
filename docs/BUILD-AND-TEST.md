# ATOM Monitor — Build and Test

This document is the reproducible build/test record for the Synology server and iPhone application. The project intentionally handles ATOM ground-station health only; aircraft identity, position, movement and track data are excluded.

## Synology server

Repository location on the DS918: `/volume1/docker/ATOMMonitor`.

Git commands are run as the normal user. Docker/Compose commands on this Synology are run with `sudo`. The complete clean-install, backup, reverse-proxy and recovery procedure is in `SYNOLOGY-HOSTING-RUNBOOK.md`.

### Network ports

Synology DSM nginx already listens on host TCP port 8080. ATOM Monitor therefore publishes its REST API on **host port 8088**. Inside the Docker network the API continues to listen on port 8080, so the collector posts to `http://atom-api:8080/api/v1/observations`.

Port 8088 is internal/LAN diagnostic access. Normal remote access is HTTPS through DSM Reverse Proxy at:

```text
https://granvillehouse.synology.me:8445/
```

DSM forwards that HTTPS service internally to `http://localhost:8088`. Do not directly Internet-forward port 8088.

### Automated server build/test

From the repository root:

```sh
cd /volume1/docker/ATOMMonitor
git pull
chmod +x scripts/synology-build-test.sh
./scripts/synology-build-test.sh 2>&1 | tee server/diagnostic/build-test.log
```

The script records the UTC time and Git revision, runs the collector unit tests, rebuilds both Docker services without cache, starts the stack, displays container state, waits for the API health endpoint on host port 8088, queries the station API, prints a station sample and captures recent container logs.

A successful run ends with `PASS: unit tests, Docker build/start and local REST API checks completed.`

To preserve a particular test run in Git:

```sh
git add server/diagnostic/build-test.log
git commit -m "Record Synology build and test"
git push
```

Do not use `sudo` for those Git commands.

### Individual checks

```sh
cd /volume1/docker/ATOMMonitor/server/diagnostic
python3 -m unittest -v

cd ..
sudo docker compose build --no-cache
sudo docker compose up -d
sudo docker compose ps
curl http://localhost:8088/health
curl http://localhost:8088/ready
curl http://localhost:8088/api/v1/stations
sudo docker compose logs --tail=100 atom-api ogn-station-probe
```

From another machine on the LAN:

```sh
curl http://192.168.1.99:8088/health
curl http://192.168.1.99:8088/ready
curl http://192.168.1.99:8088/api/v1/stations
```

Public-path checks:

```sh
curl -v https://granvillehouse.synology.me:8445/health
curl -v https://granvillehouse.synology.me:8445/ready
curl -v https://granvillehouse.synology.me:8445/api/v1/stations
```

The public test must validate the certificate normally; do not use `-k` as a production workaround.

### Server resilience checkpoints

**17 September 2026 — Phase 1 health/readiness and restart checkpoint:** the rebuilt Compose deployment reported the API healthy, `/ready` successfully checked SQLite, the persistent registry contained 305 confirmed stations, and the collector resumed accepted ground-station observations after API restart. The registry remained at 305 across the controlled container replacement/restart, confirming persistence outside the API container.

**17 September 2026 — production WSGI checkpoint:** the API image was rebuilt without cache and the running container was replaced. `docker inspect` confirmed the container command is Gunicorn with two workers and two threads; the container reported Gunicorn 23.0.0. Gunicorn logged `Starting gunicorn 23.0.0`, bound to `0.0.0.0:8080`, selected the gthread worker and booted two worker processes. `/ready` returned database `ok` with 305 confirmed stations, `/api/v1/stations` returned 305 stations, and live collector POSTs continued receiving HTTP 202. This replaces Flask's development server while retaining the same SQLite registry and Compose health model. Public HTTPS-path validation remains required before Phase 1 is marked Tested.

## iPhone application

Local Mac repository: `~/Documents/Xcode/ATOMMonitor`.

```sh
cd ~/Documents/Xcode/ATOMMonitor
git pull
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

Build in Xcode and install on the iPhone. The verified normal remote service is `https://granvillehouse.synology.me:8445/`. Until the compiled default is changed and regression-tested, Settings can be used to configure/test that endpoint. The LAN address `http://192.168.1.99:8088/` is retained as a diagnostic route only.

### Build checkpoints

**17 September 2026 — Simulator feature-tour pass:** after the initial refresh-selector failure was corrected and a second failure exposed compact-width `TabView` behaviour (Settings and Help moved under **More**), commit `6158901` updated the tour to select tabs either directly or through More. The user reran `./scripts/record-demo.sh` and reported `PASS: automated ATOM Monitor feature tour completed.` The run generated `artifacts/ATOMMonitor-Demo.mp4` and `artifacts/ATOMMonitor-Demo-test.log`; the raw recording remains `artifacts/ATOMMonitor-Demo-raw.mp4` and is not intended as the retained milestone artifact. Simulator Report coverage is therefore **Tested**. This is automated Simulator evidence, not a substitute for the remaining physical-iPhone/network acceptance checks.

**17 September 2026 — Report feature corrective build:** the first Report build failed while compiling `ReportView.swift`. After corrective commit `3850e99`, the user reran the iOS build and confirmed `** BUILD SUCCEEDED **`. The Report feature was subsequently exercised on the physical iPhone and confirmed good, including first-attempt native sharing and the HTML bar-graph enhancement.

**17 September 2026 — map/status source checkpoint:** user confirmed the build run was good after the configurable map-icon colours, back-level PilotAware-version presentation, compact Stations headings/station-count status line, connection-test station count, and yellow No-recent-heartbeat aggregate changes were committed. This advances the affected iOS features to **Build passed — runtime test pending**. It does not by itself prove map colour/cluster behaviour, Settings persistence, network behaviour or other runtime acceptance checks.

### Automated Simulator feature tour

From the repository root:

```sh
cd ~/Documents/Xcode/ATOMMonitor
git pull
./scripts/record-demo.sh
```

The script generates the Xcode project, selects an available iPhone Simulator, runs `ATOMMonitorDemoUITests/testRecordedFeatureTour`, records the Simulator and retains the UI-test log under `artifacts/`.

**DerivedData must not be written beneath this repository's `~/Documents` path on the current Mac.** During the 16 September 2026 regression run, an app built under `artifacts/DerivedData` acquired File Provider metadata and Xcode failed CodeSign with `resource fork, Finder information, or similar detritus not allowed`. Rebuilding with DerivedData at `/tmp/ATOMMonitor-DerivedData` succeeded, with a clean app bundle and valid code signature.

`record-demo.sh` therefore defaults to `/tmp/ATOMMonitor-DerivedData` and removes that directory before each automated tour. To use another clean location:

```sh
ATOM_DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/ATOMMonitor-Demo" ./scripts/record-demo.sh
```

### iPhone acceptance test

1. Configure/test `https://granvillehouse.synology.me:8445/`; for a true external-path test disable Wi-Fi and use cellular data.
2. Launch ATOM Monitor and confirm Stations loads server-provided stations rather than fixture data.
3. Confirm stations with coordinates appear on Map and clustering works. Confirm individual defaults: Healthy green, Back-level software purple, No recent heartbeat blue, Inactive red, Warning orange and Unknown grey. Confirm an aggregate containing No recent heartbeat is yellow by default, and a Healthy + Inactive aggregate is yellow.
4. In Settings → Map icon colours, change representative colours, return to Map and confirm the individual markers change; relaunch and confirm the choices persist; use Restore default colours and confirm the documented defaults return.
5. Confirm Map manual refresh works and Last updated advances only after a successful snapshot, with the station count shown on the same status line.
6. Confirm the Map and Stations headings read `Stations` rather than `ATOM Stations`.
7. In Settings, run Test Connection and confirm a successful response shows `OK — <count> stations`.
8. Exercise Standard, Satellite + Labels and Satellite map layers.
9. With no home station configured, tap Home and confirm `No home station set`; then configure a home station and confirm Home returns the map to it.
10. Open a station detail and confirm **Record date & time** displays an absolute local date/time for `lastSeen`; confirm Last heartbeat, Last seen, Last position and Last technical status remain relative-age values. For a missing timestamp, confirm `Not reported`.
11. Open Report and confirm Total stations equals the loaded station count; verify the Status counts sum to the total and the PilotAware-version counts sum to the total including `Not reported` where applicable.
12. Tap **Share report** on a physical iPhone. Confirm the standard iOS share sheet appears and offers installed capabilities such as Mail, Messages, AirDrop and Files as available.
13. Share/save the generated HTML and CSV. Open the HTML and confirm the formatted summary, status counts, version counts, generation time and data-update time are readable on phone and desktop. Open the CSV and confirm station name, displayed status, PilotAware version, station timestamps and latitude/longitude are correctly escaped and represented. Confirm neither output contains aircraft identities, positions, movements or tracks.
14. Add a station to Favourites from Map and from Stations.
15. Disconnect the server/network temporarily and relaunch/refresh; the last station cache should remain available and Map should report `No Network` for the failed current request, including the cached station count.
16. Confirm favourite records remain available from the durable local favourites cache after a successful server refresh.
17. Restore connectivity and verify fresh server data replaces the general cache.
18. Remove a favourite in Settings and verify the preference is retained.
19. Open Help → User Guide and verify the current station status, timestamp, map-colour and Report behaviour is documented locally/offline.
20. Confirm no aircraft movement/identity UI or data appears anywhere.

## What constitutes an end-to-end pass

An end-to-end pass requires: collector unit tests passing; both Docker services running; `/health` returning success on host port 8088; `/ready` confirming its database dependency; `/api/v1/stations` returning PilotAware-confirmed persistent station records; public HTTPS access through `granvillehouse.synology.me:8445`; iPhone decoding/displaying those records including the absolute station record timestamp; and local caching/favourites behaviour working as described above.

Runtime logs are evidence of a particular build, not source code. Commit a `build-test.log` when a milestone or fault investigation needs a permanent record; routine repeated logs need not be committed indefinitely.
