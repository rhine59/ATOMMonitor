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
curl http://localhost:8088/api/v1/stations
sudo docker compose logs --tail=100 atom-api ogn-station-probe
```

From another machine on the LAN:

```sh
curl http://192.168.1.99:8088/health
curl http://192.168.1.99:8088/api/v1/stations
```

Public-path checks:

```sh
curl -v https://granvillehouse.synology.me:8445/health
curl -v https://granvillehouse.synology.me:8445/api/v1/stations
```

The public test must validate the certificate normally; do not use `-k` as a production workaround.

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
3. Confirm stations with coordinates appear on Map and clustering works.
4. Confirm Map manual refresh works and Last updated advances only after a successful snapshot.
5. Exercise Standard, Satellite + Labels and Satellite map layers.
6. With no home station configured, tap Home and confirm `No home station set`; then configure a home station and confirm Home returns the map to it.
7. Open a station detail and confirm **Record date & time** displays an absolute local date/time for `lastSeen`; confirm Last heartbeat, Last seen, Last position and Last technical status remain relative-age values. For a missing timestamp, confirm `Not reported`.
8. Add a station to Favourites from Map and from Stations.
9. Disconnect the server/network temporarily and relaunch/refresh; the last station cache should remain available and Map should report `No Network` for the failed current request.
10. Confirm favourite records remain available from the durable local favourites cache after a successful server refresh.
11. Restore connectivity and verify fresh server data replaces the general cache.
12. Remove a favourite in Settings and verify the preference is retained.
13. Open Help → User Guide and verify the station timestamp behaviour is documented locally/offline.
14. Confirm no aircraft movement/identity UI or data appears anywhere.

## What constitutes an end-to-end pass

An end-to-end pass requires: collector unit tests passing; both Docker services running; `/health` returning success on host port 8088; `/api/v1/stations` returning PilotAware-confirmed persistent station records; public HTTPS access through `granvillehouse.synology.me:8445`; iPhone decoding/displaying those records including the absolute station record timestamp; and local caching/favourites behaviour working as described above.

Runtime logs are evidence of a particular build, not source code. Commit a `build-test.log` when a milestone or fault investigation needs a permanent record; routine repeated logs need not be committed indefinitely.
