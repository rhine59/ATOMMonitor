# ATOM Monitor integrated checkpoint — 16 September 2026

This checkpoint records the simulator/build, iPhone application, documentation, Docker server and newly verified public DNS/TLS state.

## Scope invariant
ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It does not display, record or retain aircraft movements, tracks or identities. This applies to collector, database, API, diagnostics and iPhone UI.

## Public deployment
The established public endpoint is `https://granvillehouse.synology.me:8445/`.

```text
OGN/APRS receiver/status
        -> Synology Docker ATOM collector/API
        -> container :8080
        -> Synology host :8088 (internal/LAN)
        -> DSM reverse proxy
        -> HTTPS granvillehouse.synology.me:8445
        -> iPhone ATOM Monitor
```

DSM terminates TLS and forwards to `http://localhost:8088`. Curl testing on 16 September 2026 confirmed DNS resolution, TCP connectivity, TLS 1.3 and successful certificate validation for `granvillehouse.synology.me`. The reverse-proxy source hostname was corrected during setup and the public path then tested successfully. Port 8088 remains internal/LAN diagnostic access and should not be directly Internet-forwarded.

## Docker/server
Server source is under `server/` with `Dockerfile`, `docker-compose.yml`, Flask API/SQLite implementation and diagnostics. Synology deployment is `/volume1/docker/ATOMMonitor`. Docker/Compose commands on Synology use `sudo`; Git commands do not. Runtime SQLite files remain excluded from Git. `scripts/synology-build-test.sh` is the repeatable server build/test workflow.

The persistent station registry is live and has contained roughly 300 stations. PWFirefly cadence measured on 16 September was approximately 300 seconds for position and 291 seconds for heartbeat. Health thresholds remain provisional pending wider cadence validation.

## iPhone app
The SwiftUI app targets iOS 17+ and has Map, Stations, Favourites, Settings and Help. Map is adaptive/full-screen with clustering, Find, direct detail, map layers, Home and manual refresh. `Last updated` is plain text below the title/button row and above Find; a failed current server request replaces it with red `No Network` while cached data remains visible.

Automatic station refresh occurs at startup and then every 1–10 minutes, default 5 minutes. Help contains a local native SwiftUI User Guide and does not depend on GitHub/Safari. The 1024x1024 opaque atom artwork is configured as `AppIcon`.

The app currently still needs its compiled default endpoint changed from the LAN address to the verified public endpoint above; this checkpoint deliberately records that as the next implementation change rather than claiming it is already done.

## Simulator/build
The icon-enabled app has completed a successful command-line Simulator build: `** BUILD SUCCEEDED **`.

Generate and build with DerivedData outside Documents/File Provider storage:

```bash
cd ~/Documents/Xcode/ATOMMonitor/ios
xcodegen generate
rm -rf /tmp/ATOMMonitor-DerivedData
xcodebuild build \
  -project ATOMMonitor.xcodeproj \
  -scheme ATOMMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/ATOMMonitor-DerivedData
```

The repository contains the UI-test target, deterministic demo resources, `scripts/record-demo.sh`, retained test logs and finished `artifacts/ATOMMonitor-Demo.mp4`. Raw recordings and DerivedData are ignored. This checkpoint records a successful Simulator build; it does not claim a new complete automated UI tour was run after every latest UI change.

## Documentation
The documentation set covers project vision and requirements, architecture, API/data model, OGN/APRS/data sources, map UI, local User Guide, public server setup, live integration tests, build/test, demo automation, research notes and design decisions. User-facing changes must continue to update both repository documentation and the local in-app User Guide.

## Next engineering work
1. Make `https://granvillehouse.synology.me:8445/` the compiled default server and ensure changing server settings really reconfigures `StationStore`'s repository.
2. Re-key or clear the local station cache when the configured server changes.
3. Serialize refreshes and expose a separate refresh-in-progress state.
4. Separate successful network fetches from local cache-write failures.
5. Rerun the full Simulator UI regression and physical-iPhone regression after the public-endpoint change.
6. Prevent stale server packets overwriting newer telemetry by comparing packet timestamps during upsert.
7. Restrict/authenticate any observation-ingestion endpoint before treating the public service as hardened production exposure; externally expose only intended read functionality.
8. Continue cadence validation and authoritative ATOM registry/bootstrap work.

## Resume point
Public DNS, TLS and DSM reverse proxy are working; the Docker service is live; the app builds successfully for Simulator and has current map/help functionality. Resume by changing the app default to the verified public HTTPS endpoint, rebuilding/testing the Simulator, testing the physical iPhone off Wi-Fi, then rebuilding/testing the Synology Docker deployment.