# ATOM Monitor — Build and Test

This document is the reproducible build/test record for the Synology server and iPhone application. The project intentionally handles ATOM ground-station health only; aircraft identity, position, movement and track data are excluded.

## Synology server

Repository location on the DS918: `/volume1/docker/ATOMMonitor`.

Git commands are run as the normal user. Docker/Compose commands on this Synology are run with `sudo`.

### Network ports

Synology DSM nginx already listens on host TCP port 8080. ATOM Monitor therefore publishes its REST API on **host port 8088**. Inside the Docker network the API continues to listen on port 8080, so the collector posts to `http://atom-api:8080/api/v1/observations`. LAN/iPhone clients use `http://192.168.1.99:8088/`.

The port decision was made after a Synology build reported `listen tcp4 0.0.0.0:8080: listen: address already in use`; `sudo netstat -tulpn | grep ':8080'` identified Synology nginx as the listener. The DSM nginx service is left untouched.

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

## iPhone application

Local Mac repository: `~/Documents/Xcode/ATOMMonitor`.

```sh
cd ~/Documents/Xcode/ATOMMonitor
git pull
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

Build in Xcode and install on the iPhone. The default API endpoint is `http://192.168.1.99:8088/`. The app has a local-network usage description and local-network HTTP allowance for this LAN service.

### Automated Simulator feature tour

From the repository root:

```sh
cd ~/Documents/Xcode/ATOMMonitor
git pull
./scripts/record-demo.sh
```

The script generates the Xcode project, selects an available iPhone Simulator, runs `ATOMMonitorDemoUITests/testRecordedFeatureTour`, records the Simulator and retains the UI-test log under `artifacts/`.

**DerivedData must not be written beneath this repository's `~/Documents` path on the current Mac.** During the 16 September 2026 regression run, an app built under `artifacts/DerivedData` acquired `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P` metadata on the generated `ATOMMonitor.app` directory. Xcode then failed CodeSign with `resource fork, Finder information, or similar detritus not allowed`. The source resources themselves had no extended attributes.

The diagnosis was confirmed by rebuilding the same project with DerivedData at `/tmp/ATOMMonitor-DerivedData`: Xcode reported `** BUILD SUCCEEDED **`, `xattr -lr` on the generated app returned no extended attributes, and `codesign --verify --verbose=4` reported `valid on disk` and `satisfies its Designated Requirement`.

`record-demo.sh` therefore defaults to:

```text
/tmp/ATOMMonitor-DerivedData
```

and removes that directory before each automated tour. This keeps generated app bundles outside File Provider-managed `Documents` storage. To use another clean location, set `ATOM_DERIVED_DATA`, for example:

```sh
ATOM_DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/ATOMMonitor-Demo" ./scripts/record-demo.sh
```

Do not revert the recorder to `artifacts/DerivedData` unless the filesystem metadata issue has been independently shown to be resolved.

### iPhone acceptance test

1. Confirm the phone is on a network that can reach `192.168.1.99:8088`.
2. Launch ATOM Monitor and permit local-network access if iOS asks.
3. Confirm Stations loads server-provided stations rather than fixture data.
4. Confirm stations with coordinates appear on Map and clustering works.
5. Confirm Map manual refresh works and Last updated advances only after a successful snapshot.
6. Exercise Standard, Satellite + Labels and Satellite map layers.
7. With no home station configured, tap Home and confirm `No home station set`; then configure a home station and confirm Home returns the map to it.
8. Add a station to Favourites from Map and from Stations.
9. Disconnect the Synology/network temporarily and relaunch/refresh; the last station cache should remain available.
10. Confirm favourite records remain available from the durable local favourites cache after a successful server refresh.
11. Restore connectivity and verify fresh server data replaces the general cache.
12. Remove a favourite in Settings and verify the preference is retained.
13. Confirm no aircraft movement/identity UI or data appears anywhere.

## What constitutes an end-to-end pass

An end-to-end pass requires: collector unit tests passing; both Docker services running; `/health` returning success on host port 8088; `/api/v1/stations` returning PilotAware-confirmed persistent station records; LAN access to port 8088; iPhone decoding and displaying those records; and local caching/favourites behaviour working as described above.

Runtime logs are evidence of a particular build, not source code. Commit a `build-test.log` when a milestone or fault investigation needs a permanent record; routine repeated logs need not be committed indefinitely.
