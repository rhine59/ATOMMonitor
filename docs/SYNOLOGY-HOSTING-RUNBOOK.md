# ATOM Monitor — Synology Docker Hosting Runbook

This is the authoritative rebuild, deployment, networking and diagnostic runbook for hosting the ATOM Monitor server on the Synology NAS.

## 1. Scope and safety invariant

ATOM Monitor collects and serves **PilotAware ATOM ground-station operational health and technical status only**. It must not store or expose aircraft identities, aircraft positions, tracks or movement history.

The server consists of two Docker Compose services:

- `atommonitor-api` — persistent SQLite station registry and REST API.
- `atommonitor-ogn-probe` — OGN/APRS ground-station collector/classifier feeding receiver/status observations to the API.

The current Compose file maps Synology host port `8088` to API container port `8080`, mounts `./data` at `/data`, stores SQLite at `/data/atommonitor.sqlite3`, and runs both containers with `restart: unless-stopped`.

## 2. Production topology

```text
OGN/APRS receiver/status feed
        |
        v
Synology NAS
  /volume1/docker/ATOMMonitor
        |
        +-- Docker: atommonitor-ogn-probe
        |       |
        |       +--> http://atom-api:8080/api/v1/observations
        |
        +-- Docker: atommonitor-api :8080
                |
                +--> ./server/data/atommonitor.sqlite3
                |
                v
          Synology host :8088
                |
                v
DSM Reverse Proxy
HTTPS granvillehouse.synology.me:8445
                |
                v
ATOM Monitor iPhone app
```

`8088` is an internal/LAN service port. **Do not forward TCP 8088 from the Internet.** Public clients use HTTPS on `granvillehouse.synology.me:8445`.

## 3. Synology prerequisites

The NAS needs:

- DSM with Container Manager/Docker and Docker Compose support.
- Git and SSH/terminal access for deployment and diagnostics.
- A persistent shared-volume location under `/volume1/docker`.
- Synology DDNS hostname `granvillehouse.synology.me`.
- A valid TLS certificate covering `granvillehouse.synology.me`.
- DSM Reverse Proxy access under Control Panel / Login Portal / Advanced.

Project convention: **Docker/Compose commands on Synology use `sudo`; Git commands do not use `sudo`.** This avoids changing repository ownership to root.

## 4. Repository location

The live repository is expected at:

```bash
/volume1/docker/ATOMMonitor
```

From SSH:

```bash
cd /volume1/docker/ATOMMonitor
git status
git remote -v
git branch --show-current
```

The normal branch is `main`.

For an existing deployment, update without sudo:

```bash
cd /volume1/docker/ATOMMonitor
git pull origin main
```

For a clean rebuild, clone the private `rhine59/ATOMMonitor` repository into `/volume1/docker/ATOMMonitor` using the Synology user's configured GitHub authentication. Do not clone as root.

## 5. Persistent data

The Compose file uses:

```text
./server/data  ->  /data
ATOM_DB=/data/atommonitor.sqlite3
```

Therefore the live database is expected at:

```text
/volume1/docker/ATOMMonitor/server/data/atommonitor.sqlite3
```

The runtime database, journal, WAL and SHM files are deliberately ignored by Git. They are operational data, not source code.

Before destructive server work, back up `server/data/` separately from Git. A source-code checkout alone does **not** restore the station registry.

A simple stopped-service backup is:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose down
cp -a data "data-backup-$(date +%Y%m%d-%H%M%S)"
sudo docker compose up -d
```

For routine NAS backups, include `/volume1/docker/ATOMMonitor/server/data` in the Synology backup policy.

## 6. Build and start the containers

From the server directory:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose build
sudo docker compose up -d
sudo docker compose ps
```

For a clean rebuild:

```bash
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d
sudo docker compose ps
```

Expected containers:

```text
atommonitor-api
atommonitor-ogn-probe
```

Both are configured `restart: unless-stopped`, so they should restart automatically after a NAS/Docker restart unless deliberately stopped.

## 7. Repeatable build/test runner

The repository includes:

```text
scripts/synology-build-test.sh
```

Run from the repository root:

```bash
cd /volume1/docker/ATOMMonitor
sh scripts/synology-build-test.sh
```

It performs collector unit tests, creates/checks persistent storage, stops and rebuilds the Compose stack without cache, starts it, shows container state, waits for `/health`, samples/counts `/api/v1/stations`, prints recent logs and reports PASS only after those checks complete.

## 8. Local API verification

On the Synology itself:

```bash
curl -v http://localhost:8088/health
curl -v http://localhost:8088/api/v1/stations
```

From another machine on the LAN, where the NAS is currently `192.168.1.99`:

```bash
curl -v http://192.168.1.99:8088/health
curl -v http://192.168.1.99:8088/api/v1/stations
```

The LAN IP is a diagnostic detail, not the normal public app endpoint.

## 9. Public DNS and TLS

ATOM Monitor uses the existing Synology DDNS name:

```text
granvillehouse.synology.me
```

The verified public ATOM endpoint is:

```text
https://granvillehouse.synology.me:8445/
```

On 16 September 2026, curl confirmed DNS resolution, TCP connection, TLS 1.3 and successful certificate validation for `granvillehouse.synology.me`.

Other services already use HTTPS ports `8443` and `8444`; ATOM Monitor therefore uses `8445`.

## 10. DSM Reverse Proxy rule

In DSM:

```text
Control Panel
  -> Login Portal
  -> Advanced
  -> Reverse Proxy
```

Create/edit the rule as:

```text
Reverse Proxy Name: ATOMMonitor

SOURCE
Protocol: HTTPS
Hostname: granvillehouse.synology.me
Port:     8445
HSTS:     enabled
Access control profile: Not configured

DESTINATION
Protocol: HTTP
Hostname: localhost
Port:     8088
```

The source hostname must be **exactly** `granvillehouse.synology.me`. During initial setup a different Synology hostname was accidentally entered; TCP/TLS then worked but nginx returned `404 Not Found` because the Host header did not match the reverse-proxy rule. Correcting the source hostname fixed routing.

WebSocket support is not required for the current REST API.

## 11. Certificate

DSM must assign a valid certificate for:

```text
granvillehouse.synology.me
```

The certificate tested on 16 September 2026 was accepted by curl without `-k`. Normal public testing must not suppress certificate validation.

Useful test:

```bash
curl -v https://granvillehouse.synology.me:8445/health
```

Look for:

```text
subjectAltName: host "granvillehouse.synology.me" matched
SSL certificate verify ok
```

## 12. Router port forwarding

The router forwards only the public HTTPS service port to the NAS:

```text
Protocol:          TCP
External/WAN port: 8445
Internal host:     192.168.1.99
Internal port:     8445
```

Do **not** forward port `8088`.

If the NAS LAN address is changed, update the router rule or preferably reserve the NAS address in DHCP so the forwarding target remains stable.

## 13. Public end-to-end tests

Test health:

```bash
curl -v https://granvillehouse.synology.me:8445/health
```

Test the station API:

```bash
curl -v https://granvillehouse.synology.me:8445/api/v1/stations
```

A true external iPhone test should be made with Wi-Fi disabled, using cellular data. The app's server should be:

```text
https://granvillehouse.synology.me:8445/
```

If public curl fails but local `localhost:8088` succeeds, investigate reverse proxy, certificate, router forwarding and DSM firewall before touching Docker.

## 14. Diagnostic decision tree

### A. Nothing works locally

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose ps
sudo docker compose logs --tail=100 atom-api
sudo docker compose logs --tail=100 ogn-station-probe
curl -v http://localhost:8088/health
```

If containers are absent/stopped, rebuild/start Compose. If API is running but health fails, inspect API logs and persistent-data permissions.

### B. API works locally but public connection is refused

Check:

1. Router TCP `8445 -> NAS:8445` forwarding.
2. DSM firewall permits the required inbound connection.
3. DSM Reverse Proxy has a source listener on HTTPS 8445.

A refusal happens before the ATOM API is reached.

### C. Public TLS works but nginx returns 404

Check the reverse-proxy **Source Hostname**. It must match the hostname in the request exactly:

```text
granvillehouse.synology.me
```

This was the cause encountered during the original 8445 deployment.

### D. Certificate error

Check DSM certificate assignment and expiry. Do not work around a production certificate error with `-k`; fix the certificate/hostname configuration.

### E. App shows No Network but curl works

Test the exact app endpoint and `/api/v1/stations`, then inspect the configured server URL in the app. Remember that cached station data can remain visible even when the current refresh has failed.

## 15. Logs and live diagnostics

From `/volume1/docker/ATOMMonitor/server`:

```bash
sudo docker compose ps
sudo docker compose logs --tail=100 atom-api ogn-station-probe
sudo docker compose logs -f atom-api
sudo docker compose logs -f ogn-station-probe
```

To capture evidence:

```bash
sudo docker compose logs --no-color atom-api ogn-station-probe > ../artifacts/synology-containers.log 2>&1
```

If committing diagnostic evidence, review it first for secrets or inappropriate data. The project must not add aircraft traffic logs to Git.

## 16. Collector diagnostics

A broad ground-station discovery diagnostic is:

```bash
cd /volume1/docker/ATOMMonitor/server/diagnostic
python3 ogn_station_probe.py --prefix PW --discovery
```

To retain console output:

```bash
python3 ogn_station_probe.py --prefix PW --discovery 2>&1 | tee atom_discovery.log
```

`PW` is a useful discovery prefix, not an authoritative complete registry/classifier. `OGN-R/PilotAware` in receiver status is stronger PilotAware evidence. Diagnostics must remain receiver/status focused and must not dump/store general aircraft traffic.

## 17. Upgrade/redeploy procedure

Normal deployment after a source change:

```bash
cd /volume1/docker/ATOMMonitor
git status
git pull origin main
sh scripts/synology-build-test.sh
```

Then verify public access:

```bash
curl -fsS https://granvillehouse.synology.me:8445/health
curl -fsS https://granvillehouse.synology.me:8445/api/v1/stations >/dev/null
```

Finally test the iPhone over cellular data for a real Internet-path check.

## 18. Recovery from a clean NAS/container installation

1. Install/enable Container Manager/Docker and Git/SSH support.
2. Restore or clone `rhine59/ATOMMonitor` to `/volume1/docker/ATOMMonitor` as the normal Synology user.
3. Restore `server/data/` from backup if retaining the existing station registry.
4. Run `sh scripts/synology-build-test.sh`.
5. Recreate/verify the DSM `ATOMMonitor` reverse-proxy rule on HTTPS 8445 to `localhost:8088`.
6. Assign/verify the `granvillehouse.synology.me` TLS certificate.
7. Recreate/verify router TCP forwarding `8445 -> NAS:8445`.
8. Verify local `/health` and `/api/v1/stations`.
9. Verify public HTTPS endpoints with certificate checking enabled.
10. Verify the iPhone using cellular data.

## 19. Security notes and outstanding hardening

The public reverse proxy must expose only what ATOM Monitor needs. The current server also has an observation-ingestion path used internally by the collector. Before treating the Internet-facing deployment as fully hardened production service, restrict or authenticate ingestion so an external client cannot submit arbitrary observations. Public access should be limited to intended read endpoints wherever practical.

Keep DSM, Container Manager/Docker and images patched. Do not place credentials, tokens or private keys in Git. Do not expose Docker's management socket or the SQLite database over the network.

## 20. Known server engineering work

The following are not deployment blockers but remain tracked engineering work:

- compare incoming packet timestamps before upsert so stale technical packets cannot overwrite newer values;
- continue multi-station cadence validation before finalising health thresholds;
- establish an authoritative complete ATOM registry/bootstrap mechanism rather than treating the `PW` prefix as complete;
- harden public/private API separation for observation ingestion.

## 21. Quick operational checklist

```bash
cd /volume1/docker/ATOMMonitor
git status
cd server
sudo docker compose ps
curl -fsS http://localhost:8088/health
curl -fsS http://localhost:8088/api/v1/stations >/dev/null
curl -fsS https://granvillehouse.synology.me:8445/health
sudo docker compose logs --tail=30 atom-api ogn-station-probe
```

If all checks pass, the Synology Docker host, persistent registry, LAN API, public DNS/TLS reverse proxy and collector are operational.