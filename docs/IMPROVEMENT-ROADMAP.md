# ATOM Monitor — Improvement Roadmap

Checkpoint: 17 September 2026

This document records the engineering improvements identified at the current stable checkpoint. The emphasis is now on reliability, correctness, security and reproducibility rather than adding unrelated features.

The authoritative feature/change objective and implementation/test state is maintained in `docs/FEATURE-STATUS.md`. **Every implementation change must update that register in the same development cycle.**

## Scope invariant

ATOM Monitor monitors the operational health and technical status of PilotAware ATOM ground stations only. It must not display, record or retain aircraft movements, tracks or aircraft identities. All roadmap work must preserve that boundary.

## Recommended implementation order

### 1. Complete the public-server transition

Use the established public HTTPS service as the normal application endpoint:

```text
https://granvillehouse.synology.me:8445/
```

Work required:

- make the verified public HTTPS URL the compiled application default;
- verify that changing the server URL in Settings actually changes the repository used by `StationStore`, rather than leaving an immutable repository pointing at the previous URL;
- make the persistent station cache server-specific, or explicitly invalidate/re-key it when the configured server changes;
- retain `http://192.168.1.99:8088/` only as a LAN diagnostic route;
- regression-test Test Connection, Save/reload, relaunch and cellular-data operation.

Acceptance: a clean/new installation works through the public DNS endpoint without manual LAN configuration, and changing server cannot display a cache belonging to another server.

### 2. Serialize and clarify refresh handling

Startup, periodic and manual refreshes should not run concurrently against the same store.

Work required:

- serialize or coalesce refresh operations;
- expose a genuine `isRefreshing` state independently of whether the station array is empty;
- animate/disable the manual refresh control while a request is in progress;
- distinguish network/API failure from persistent-cache write failure;
- preserve the previous successful snapshot on all failed refresh paths;
- ensure `Last updated` changes only after a successful server snapshot has been accepted.

Acceptance: repeated manual refreshes and timer boundaries cannot create overlapping requests or misleading UI state.

### 3. Protect station data from stale packet overwrite

The server persistence layer must not allow an older delayed packet to overwrite newer corresponding telemetry.

Work required:

- compare incoming packet/source timestamps with the existing timestamp for each observation category before updating;
- update position only from an equal/newer position observation;
- update heartbeat/status only from an equal/newer heartbeat/status observation;
- update technical telemetry only from an equal/newer technical observation;
- add unit/integration tests that submit records deliberately out of order;
- document the timestamp precedence rules in the data model/API documentation.

Acceptance: replaying an older packet after a newer packet cannot regress the stored station state.

### 4. Harden the public API boundary

DSM Reverse Proxy currently provides the public HTTPS path. Public read access and collector write access should be separated as far as practical.

Work required:

- ensure the Internet-facing service exposes only intended read endpoints where possible;
- keep observation ingestion Docker-internal, or authenticate/authorize it if it must remain reachable through the public listener;
- do not expose host port 8088 directly to the Internet;
- test `/health` and `/api/v1/stations` externally while verifying unauthorized observation submission is not possible;
- record the final configuration in `SYNOLOGY-HOSTING-RUNBOOK.md` and `PUBLIC-SERVER-SETUP.md`.

Acceptance: an unauthenticated Internet client cannot submit arbitrary station observations.

### 5. Improve station-detail presentation and timestamps

The current detail screen now displays an absolute **Record date & time** from `lastSeen`, while individual observation times remain relative.

Possible improvements:

- show the exact record time and its relative age together, for example `16 Sep 2026, 09:42:17 — 3 min ago`;
- retain separate relative ages for heartbeat, position and technical status;
- if the server later exposes a more authoritative source-record timestamp, prefer that over a generic receipt/last-seen timestamp and document the distinction;
- make health state and record age visually prominent without treating absent optional telemetry as a fault;
- keep `Not reported` for genuinely unavailable values.

Acceptance: a user can immediately determine both exactly when the latest station record occurred and how old the important observation categories are.

### 6. Full Simulator and physical-iPhone regression

After the reliability/security work above, create a new regression checkpoint.

Required coverage:

- automated Simulator feature tour;
- at least one small-screen iPhone Simulator and one Pro Max-sized Simulator for layout regression;
- Map header/status/search layout;
- all map layers and Home behaviour;
- station search, detail and Record date & time;
- favourites and Settings persistence;
- refresh interval and manual refresh;
- cached-data/no-network behaviour;
- local in-app User Guide;
- public HTTPS connection;
- physical iPhone test with Wi-Fi disabled so the route genuinely traverses cellular Internet, TLS, DSM Reverse Proxy and Docker.

Finished `.mp4` and `.log` evidence may be retained in Git according to the repository artifact policy; raw recordings and DerivedData remain excluded.

Acceptance: the tested app behaves consistently across representative screen sizes and the physical public-network path.

### 7. Automate Synology database backup and recovery verification

The hosting runbook now documents persistent SQLite data and manual recovery. Turn this into a repeatable tested procedure.

Work required:

- add a safe timestamped SQLite backup script;
- define retention/rotation rather than allowing unlimited backups;
- ensure backup files live outside the source-controlled runtime database path or are explicitly ignored;
- add integrity checking to the backup process;
- document and test restore into a controlled copy before relying on it;
- include the persistent station registry in the NAS backup policy.

Acceptance: a station registry can be restored from a documented backup without rebuilding it from live observations.

## Additional engineering items already identified

These remain useful after the main sequence above:

- deterministic `--reset-demo-preferences` behaviour for UI automation;
- harden SwiftUI UI-test selectors so tests do not depend on generic `Increment` buttons or fragile List/table assumptions;
- consider build-for-testing followed by test-without-building in the demo recorder;
- continue multi-station cadence measurements before finalising heartbeat health thresholds;
- establish a more authoritative complete ATOM registry/bootstrap mechanism rather than assuming the `PW` prefix is complete;
- review the Map header's remaining hard-coded safe-area floor if physical-device testing exposes layout issues.

## Checkpoint principle

Do not add significant unrelated functionality before the public endpoint, refresh concurrency, stale-packet protection and public API security work are complete. The current application has enough functional breadth that correctness and operational resilience now provide more value than feature count.

When any roadmap item or other implementation change is made, update `docs/FEATURE-STATUS.md`, the relevant repository documentation, the local in-app User Guide where user-visible behaviour changes, build/test evidence where appropriate, and commit the synchronized change to GitHub. A source-code commit is not a tested feature: status advances only when the corresponding build and runtime checks have actually passed.
\n\n## Checkpoint synchronization — 18 September 2026\n\nServer checkpoint: Phase 3 PostgreSQL migration is Tested and the Phase 4 replicated API/Nginx runtime acceptance has passed. The cross-phase acceptance framework is Tested. The principal server operational gap is PostgreSQL backup/restore plus NAS/external backup policy; Phase 4 close-out should retain the exact one-API rollback procedure. No Phase 5 acceptance contract has yet been defined. See `CHECKPOINT-2026-09-18.md`.\n