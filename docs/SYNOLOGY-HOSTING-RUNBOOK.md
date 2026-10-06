# ATOM Monitor — Synology Docker Hosting Runbook

This is the authoritative rebuild, deployment, networking and diagnostic runbook for hosting the ATOM Monitor server on the Synology NAS. It must remain sufficient to recreate the environment from a clean NAS/checkout, not merely operate the existing host.

## 1. Scope and safety invariant

ATOM Monitor collects and serves **PilotAware ATOM ground-station operational health and technical status only**. It must not store or expose aircraft identities, aircraft positions, tracks or movement history.

The current server stack consists of PostgreSQL, two stateless API replicas, one Nginx load balancer and one single-active OGN/APRS ground-station collector. PostgreSQL is the active station-registry backend. Nginx alone publishes Synology host port `8088`; the API replicas and PostgreSQL remain private to the Compose network. The collector submits observations through Nginx rather than directly to an API replica.

## 2. Current hosted topology

```text
OGN/APRS receiver/status feed
        |
        v
single-active atommonitor-ogn-probe
        |
        v
atommonitor-lb (Nginx) :8080
        |
        +--> atom-api replica 1 --+
        +--> atom-api replica 2 --+--> PostgreSQL
        |
        v
Synology host :8088
        |
        v
DSM Reverse Proxy
HTTPS granvillehouse.synology.me:8445
        |
        v
ATOM Monitor phone clients
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

The active runtime database is PostgreSQL. Compose stores it in the named Docker volume `atommonitor-postgres-data`. A Git checkout does not contain or restore this database.

The legacy `server/data/atommonitor.sqlite3` file is retained only as the tested Phase 3 rollback boundary and is ignored by Git. The older SQLite backup procedure in Section 22 is historical/rollback material; it is **not** a backup of the active PostgreSQL service.

Do not remove `atommonitor-postgres-data` during routine rebuilds, API recreation, scaling or Phase 4 rollback. A PostgreSQL backup/restore policy remains an outstanding operational requirement and must be documented/tested before the database is treated as fully protected.

## 6. Build and start the containers

From the server directory:

```bash
cd /volume1/docker/ATOMMonitor/server
sudo docker compose config --quiet
sudo docker compose up -d --build --scale atom-api=2
sudo docker compose ps
```

For a clean image rebuild, add `--no-cache` to the build step if required, then start with `--scale atom-api=2`. Expected runtime containers are `atommonitor-postgres`, `atommonitor-lb`, `atommonitor-ogn-probe`, and two Compose-managed API replicas `atommonitor-atom-api-1` and `atommonitor-atom-api-2`. PostgreSQL, Nginx and both API replicas should become healthy; the collector should be running.

### One-time container-name migration

Compose is explicitly named `atommonitor`, so every container starts with the lowercase Git repository name. Existing deployments were labelled as Compose project `server`, which caused scaled API replicas to be named `server-atom-api-*`. After pulling the commit that introduces the new project name, run:

```bash
cd /volume1/docker/ATOMMonitor
sh scripts/migrate-container-names.sh
```

The script validates configuration, stops/removes the legacy `server` project containers, rebuilds the stack, starts two API replicas and checks that all seven containers are healthy and named `atommonitor-*`. It deliberately does not delete volumes. The Compose file pins the existing Docker volume names `server_atommonitor-postgres-data`, `server_atommonitor-admin-audit`, and `server_atommonitor-admin-devices`, preserving PostgreSQL data, audit history and paired devices across the project rename. Do not run `docker compose down -v` during this migration.

Afterwards, use the repository rebuild scripts; each explicitly supplies `-p atommonitor`, so a stale `COMPOSE_PROJECT_NAME` value cannot restore the old prefix. For manual commands, use `sudo docker compose -p atommonitor ...`. Verify the convention at any time with `sh scripts/check-container-names.sh`.

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

Use the authoritative clean-rebuild procedure in Section 25. In summary: install the prerequisites; clone the repository as the normal Synology user; create ignored `server/.env` from `.env.example`; restore PostgreSQL from a tested backup if existing registry data must be retained; validate Compose; start with two API replicas; verify PostgreSQL/Nginx/API/collector health; recreate DSM reverse proxy, TLS and router configuration; then verify local and public endpoints. Do not restore the legacy SQLite file as though it were the active PostgreSQL database.

## 19. Security notes and outstanding hardening

The public reverse proxy must expose only what ATOM Monitor needs. The current server also has an observation-ingestion path used internally by the collector. Before treating the Internet-facing deployment as fully hardened production service, restrict or authenticate ingestion so an external client cannot submit arbitrary observations. Public access should be limited to intended read endpoints wherever practical.

Keep DSM, Container Manager/Docker and images patched. Do not place credentials, tokens or private keys in Git. Do not expose Docker's management socket, PostgreSQL port 5432, API replica ports, or legacy SQLite files over the network.

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

If all checks pass, the Synology Docker host, PostgreSQL registry, replicated API behind Nginx, LAN/public DNS/TLS path and collector are operational.

## 22. Phase 2 SQLite backup/recovery checkpoint — 18 September 2026

The repository contains `scripts/atom-db-backup.py` for online SQLite backup, SHA-256 sidecars, integrity checking, retention and controlled restore verification. Live backup and verification passed with 307 station records / 305 confirmed PilotAware stations. Retention was demonstrated with `--keep 2`; a third backup pruned the oldest database and matching checksum.

The intended backup directory is outside the Git checkout:

```text
/volume1/docker/ATOMMonitor-backups
```

A DSM Task Scheduler job named **ATOMMonitor Database Backup** has been created for daily 02:00 execution. At this checkpoint the scheduled execution has **not yet been verified**, so do not treat scheduling as Tested. Before relying on the job, confirm the Synology's absolute Python 3 path and then manually run the task and inspect `backup.log`. A naturally scheduled run should subsequently be observed. The backup directory must also be included in the NAS backup policy.

Before a live recovery drill, review the restore path for stale SQLite `-wal`, `-shm` or `-journal` sidecars. The current recovery drill remains outstanding; do not overwrite the live database merely to satisfy a documentation checkpoint.

## 23. Feedback mail relay deployment — deferred

The API source contains `POST /api/v1/feedback`. It validates a 1–5 rating and bounded comments and relays mail through SMTP. The private destination and SMTP settings are supplied only through ignored server environment configuration; they must not be placed in source, Compose defaults containing secrets, logs or phone clients.

Feedback delivery is deliberately **deferred at this checkpoint**. The phone UI may report that feedback could not be sent until the server is configured. When this work resumes, configure the private recipient and SMTP credentials locally, rebuild/redeploy the API, test the endpoint, and confirm receipt without committing the destination address or credentials. Review abuse/rate-limiting protection before treating a public mail-relay endpoint as production-ready.

## 24. Clean-rebuild documentation requirement

Every server/infrastructure change must keep this runbook executable from scratch. In particular, Phase 3/4 work must document PostgreSQL, ignored local `server/.env` creation, persistent Docker volumes, API replicas, load balancer, the single-active collector, DSM reverse proxy/TLS/router configuration, validation commands and rollback. Secrets must never be committed; the runbook must instead state which variables are required and how to create/provide them.

Before a major architecture phase is marked Tested, review this runbook against a hypothetical clean Synology installation and ensure no required host-only knowledge is missing. Where older sections still describe SQLite or a single API as current topology, they must be brought forward to the tested PostgreSQL/replicated architecture as that phase is completed.

### Phase 4 Nginx/Docker DNS requirement

For the replicated API topology, Nginx performs runtime discovery of the Compose `atom-api` service. Its committed configuration therefore explicitly declares Docker's embedded DNS resolver:

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
```

Without this line Nginx fails to start when an upstream server uses the `resolve` parameter. This is a required clean-rebuild setting, not a host-specific manual fix.

## 25. Current clean rebuild procedure — PostgreSQL + replicated API + Nginx

This section supersedes older SQLite/single-API topology statements above for the current Phase 3/4 development/test environment. It is intentionally step-by-step so the server can be recreated from a clean Synology checkout without relying on undocumented settings from the existing NAS.

### Step 1 — prepare the Synology

Install/enable DSM Container Manager (Docker/Compose), Git and SSH. Use the normal Synology account for Git and `sudo` for Docker/Compose. Ensure the NAS can make outbound connections required by GitHub, container registries and the OGN/APRS collector.

### Step 2 — clone the repository

```bash
cd /volume1/docker
git clone git@github.com:rhine59/ATOMMonitor.git
cd /volume1/docker/ATOMMonitor
git status
git branch --show-current
```

The expected branch is `main`. Configure GitHub SSH authentication first as described earlier in this runbook if the repository is private and the NAS has no key yet.

### Step 3 — create local server configuration

`server/.env` is deliberately ignored by Git. Create it from the committed template:

```bash
cd /volume1/docker/ATOMMonitor/server
cp .env.example .env
chmod 600 .env
```

Edit `.env` locally and replace placeholder secrets. At minimum the running PostgreSQL topology requires `ATOM_INGEST_TOKEN`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` and `ATOM_DATABASE_URL`. The database URL must address Compose service `postgres` on port 5432 and use credentials matching the PostgreSQL variables, for example in shape only:

```text
postgresql://atommonitor:<local-password>@postgres:5432/atommonitor
```

Do not commit `.env`, tokens or passwords. If a password contains URL-reserved characters, encode it correctly in the URL or choose a generated secret that is safe for this use.

### Step 4 — validate Compose before changing runtime

```bash
sudo docker compose config --quiet
```

A successful validation returns silently.

### Step 5 — create/start PostgreSQL and the replicated API topology

The PostgreSQL data directory is held in the named Docker volume `atommonitor-postgres-data`; it is not stored in Git. Start the current topology with two API replicas:

```bash
sudo docker compose up -d --build --scale atom-api=2
sudo docker compose ps
```

Expected services are `atommonitor-postgres`, `atommonitor-lb`, `atommonitor-ogn-probe`, and two Compose-managed `atom-api` containers `atommonitor-atom-api-1` and `atommonitor-atom-api-2`. Both APIs, PostgreSQL and Nginx should become healthy; the collector should be running. The API service deliberately has no fixed `container_name`, because a fixed name prevents Compose scaling; the explicit Compose project name supplies its repository prefix.

### Step 6 — understand the current routing

The current runtime path is:

```text
LAN / DSM reverse proxy -> Synology :8088 -> atom-lb (Nginx)
                                             |
                                             +-> atom-api replica 1 --+
                                             +-> atom-api replica 2 --+-> PostgreSQL

single-active OGN collector -> atom-lb -> API replicas -> PostgreSQL
```

Only Nginx publishes host port 8088. API replicas expose port 8080 only inside the Compose network. PostgreSQL port 5432 remains private to that network. The collector is intentionally single-active and submits to `http://atom-lb:8080/api/v1/observations`.

### Step 7 — retain Docker DNS configuration for Nginx

The committed `server/nginx/atommonitor.conf` uses runtime service discovery for scaled API containers. It must contain Docker's embedded resolver:

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
```

Do not replace this with a container IP. Docker container addresses are ephemeral.

### Step 8 — verify local readiness and reads

```bash
curl -fsS http://localhost:8088/ready
curl -fsS -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8088/api/v1/stations
```

Expected: `/ready` reports `status=ready`, `database=ok`, `databaseBackend=postgresql`; the station list returns HTTP 200. The exact station count is live data and must not be hard-coded as a rebuild requirement.

Verify live collector ingestion:

```bash
sudo docker compose logs --since=2m atom-api | grep 'POST /api/v1/observations' | tail -10
```

Expected: live submissions return HTTP 202. Do not retain general aircraft traffic as test evidence; ATOM Monitor remains ground-station operational monitoring only.

### Step 9 — recreate DSM/public networking

Configure DSM Reverse Proxy source HTTPS `granvillehouse.synology.me:8445` to destination HTTP `localhost:8088`, assign a valid certificate for `granvillehouse.synology.me`, and configure the router TCP forwarding for public port 8445 to the NAS as described in Sections 9–13. Do not expose host port 8088 or PostgreSQL 5432 directly to the Internet.

Verify with certificate checking enabled:

```bash
curl -fsS https://granvillehouse.synology.me:8445/health
curl -fsS https://granvillehouse.synology.me:8445/api/v1/stations >/dev/null
```

### Step 10 — persistence and resilience checks

PostgreSQL persistence belongs to the named volume, so a clean NAS rebuild without restoring that volume starts with a new database. Source checkout alone is not a database backup. After establishing an operational backup policy for PostgreSQL, include that restore procedure here; the older SQLite backup procedure does not back up the active PostgreSQL database.

For an API-only resilience check, stop one replica, verify `/ready` and station reads remain available and collector POSTs continue with HTTP 202, then restore the replica and confirm it becomes healthy. Do not delete the PostgreSQL volume as part of an API resilience test.

### Step 11 — rollback boundary

Phase 4 topology rollback is to one PostgreSQL-backed API instance; it does not require converting the database back to SQLite. Phase 3 retains the separately documented SQLite rollback boundary at `server/data/atommonitor.sqlite3`, but the current runtime backend is PostgreSQL. Never delete `atommonitor-postgres-data` during a topology rollback.

### Step 12 — final clean-rebuild verification

Before declaring a newly recreated environment operational, confirm: Compose validates; PostgreSQL is healthy; two API replicas are healthy; Nginx is healthy and owns host port 8088; the single collector is running; `/ready` reports PostgreSQL; station reads return HTTP 200; live collector submissions return HTTP 202; DSM HTTPS works with valid TLS; and the app can reach the public endpoint. Record any host-specific prerequisite discovered during a rebuild in this runbook rather than leaving it only on the NAS.
\n\n## Checkpoint synchronization — 18 September 2026\n\nCurrent clean-rebuild target is PostgreSQL persistent named volume, two stateless API replicas, Nginx publishing host port 8088 and one single-active collector posting through Nginx. The complete acceptance suite passed this topology. A rebuild that must retain registry data still requires a tested PostgreSQL restore; the historical SQLite backup path is not a PostgreSQL backup. See `CHECKPOINT-2026-09-18.md`.\n

## Per-container build/start procedure — 19 September 2026

The current stack can be rebuilt/started and verified one service layer at a time from the repository root:

```sh
sh scripts/build-postgres.sh
sh scripts/build-api.sh
sh scripts/build-nginx.sh
sh scripts/build-collector.sh
```

Or run the dependency-ordered wrapper:

```sh
sh scripts/build-all-containers.sh
```

The PostgreSQL script pulls the pinned Compose image tag, starts it without deleting its named volume, waits for health, checks the persistent mount and executes a database query. The API script builds the local API image, starts exactly two replicas, waits for both to become healthy and directly checks each replica's health/readiness/station API. The Nginx script pulls its Compose image, starts the load balancer, validates `nginx -t` and checks health/readiness/stations through host port 8088. The collector script runs its unit tests, builds its local image, starts the single collector and requires a new HTTP 202 observation in the Nginx log. These scripts do not replace the destructive Phase resilience acceptance suite.


## Restricted admin monitor

The clean rebuild now requires a separate `ATOM_ADMIN_TOKEN` in ignored `server/.env`. Compose builds `atom-admin-monitor`, which mounts the Docker socket read-only and is not host-published; Nginx proxies only `/api/v1/admin/` to it. The ordinary `atom-api` service has no Docker socket access. This first implementation is read-only and has no scale endpoint. Before enabling scaling, replace/augment the current socket boundary with a tested narrowly authorized mutation mechanism. Runtime verification of the monitor is pending.

## Admin scaling deployment checkpoint

Add a third unique secret, `ATOM_ADMIN_CONTROL_TOKEN`, to `server/.env`, then rebuild/recreate `atom-admin-monitor` and `atom-admin-control`. Never expose control port 8091 through DSM Reverse Proxy or a host port. Verify the monitor mounts the Docker socket read-only and only the control service mounts it writable. Preserve the `atommonitor-admin-audit` named volume during ordinary container recreation. Runtime validation is pending and must include authenticated 2→3→2 scaling with continuous public reads/collector writes and singleton checks.

### Admin build/test commands

Use `scripts/build-admin.sh` for the two Admin containers. The control code uses Docker's unversioned local-socket API by default for compatibility with the Synology engine; `DOCKER_API_PREFIX` is available only if an explicit engine API prefix is later required. Run `scripts/admin-scaling-acceptance.sh` only in a planned test window because it deliberately changes the API tier 2→3→2. It does not alter PostgreSQL, Nginx or the collector.


## Admin pairing rebuild and verification

Administrator pairing state is held in the named `atommonitor-admin-devices` volume mounted at `/data`. It contains hashed device credentials and pending one-time challenges. Normal image/container rebuilds must preserve this volume.

```bash
cd /volume1/docker/ATOMMonitor
git status --short
git pull --ff-only
cd server
sudo docker compose config --quiet
cd ..
sh scripts/build-admin.sh
sh scripts/admin-pairing-acceptance.sh
```

If `git pull` reports that `ios/ATOMMonitor.xcodeproj/project.pbxproj` would be overwritten, inspect and commit the intentional change or stash that exact file before pulling. Do not reset the whole working tree.

The public pairing page is `https://granvillehouse.synology.me:8445/api/v1/admin/pair`, but it is intentionally usable only when the source address is in `ATOM_ADMIN_PAIRING_NETWORKS`. The exchange endpoint is `POST /api/v1/admin/pair/exchange`. A 401 normally means an expired/already-used code, a disallowed source, or an obsolete deployment without persistent challenge storage.

Back up the named Admin data volume with the other service data. Deliberately deleting it revokes all paired phones. Full instructions: `docs/ADMIN-PAIRING-AND-RELEASE.md`.


## Complete synchronized rebuild checkpoint

```bash
cd /volume1/docker/ATOMMonitor
git pull --ff-only
sh scripts/build-all-containers.sh
sh scripts/all-phases-acceptance.sh
```

The container build suite now finishes with a real one-time pairing/exchange/authentication/revocation test. Nginx is force-recreated so Admin routes and timeout changes are loaded. The Synology build/test runner includes both Admin containers in diagnostics and also runs pairing acceptance.


## 3 October checkpoint verification

After the complete rebuild, confirm `ogn-station-probe`, `atom-admin-monitor` and `atom-admin-control` each show running and healthy. The complete source/status boundary is recorded in `CHECKPOINT-2026-10-03.md`.
