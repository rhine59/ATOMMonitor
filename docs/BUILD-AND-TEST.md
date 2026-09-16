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

### iPhone acceptance test

1. Confirm the phone is on a network that can reach `192.168.1.99:8088`.
2. Launch ATOM Monitor and permit local-network access if iOS asks.
3. Confirm Stations loads server-provided stations rather than fixture data.
4. Confirm stations with coordinates appear on Map and clustering works.
5. Add a station to Favourites from Map and from Stations.
6. Disconnect the Synology/network temporarily and relaunch/refresh; the last station cache should remain available.
7. Confirm favourite records remain available from the durable local favourites cache after a successful server refresh.
8. Restore connectivity and verify fresh server data replaces the general cache.
9. Remove a favourite in Settings and verify the preference is retained.
10. Confirm no aircraft movement/identity UI or data appears anywhere.

## What constitutes an end-to-end pass

An end-to-end pass requires: collector unit tests passing; both Docker services running; `/health` returning success on host port 8088; `/api/v1/stations` returning PilotAware-confirmed persistent station records; LAN access to port 8088; iPhone decoding and displaying those records; and local caching/favourites behaviour working as described above.

Runtime logs are evidence of a particular build, not source code. Commit a `build-test.log` when a milestone or fault investigation needs a permanent record; routine repeated logs need not be committed indefinitely.
