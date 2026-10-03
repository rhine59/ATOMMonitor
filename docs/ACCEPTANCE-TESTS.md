# ATOM Monitor — Acceptance Test Runners

## Purpose

Acceptance tests are executable project evidence. Each implemented architecture phase has a committed POSIX `sh` runner that checks command results and returns non-zero on failure. Tests preserve the station-only scope and never require aircraft movement data.

## Runners

- `scripts/phase1-acceptance.sh` validates the base Synology/runtime boundary: required commands, repository checkout, ignored local environment, Compose validity, local readiness/station reads and the HTTP 401 ingestion boundary.
- `scripts/phase2-acceptance.sh` regression-tests the preserved SQLite backup/recovery mechanism entirely in a temporary directory: source integrity, backup, SHA-256/integrity verification, retention and controlled restore. It does not overwrite the live PostgreSQL registry or production backup directory.
- `scripts/phase3-acceptance.sh` validates the current PostgreSQL migration boundary: named-volume mount, PostgreSQL readiness, populated registry, reads/security, preserved SQLite rollback database, PostgreSQL restart persistence and API recovery. It deliberately restarts PostgreSQL and therefore causes a short development/test interruption.
- `scripts/phase4-acceptance.sh` validates the replicated topology: two API replicas, Nginx entry point, collector HTTP 202 traffic through Nginx, loss/rejoin of either replica, API recreation, load-balancer recreation, HTTP 401 ingestion boundary and final recovery.
- `scripts/service-api-acceptance.sh` exercises the current live service matrix: Nginx `/health`, `/ready`, station list/detail and 404 paths; safe feedback validation; observation authentication; PostgreSQL/API confirmed-station count agreement; direct in-container `/health`, `/ready` and station reads on every API replica; and a new live collector HTTP 202 observed through Nginx. PostgreSQL is tested with `psql` because it is intentionally not an HTTP service.\n- `scripts/all-phases-acceptance.sh` runs Phases 1–4 and then the current service/API matrix, stopping if a runner exits non-zero.

Shared simple PASS/FAIL helpers live in `scripts/lib/acceptance.sh`.

## Running

From the repository root, syntax-check first:

```sh
sh -n scripts/phase1-acceptance.sh
sh -n scripts/phase2-acceptance.sh
sh -n scripts/phase3-acceptance.sh
sh -n scripts/phase4-acceptance.sh
sh -n scripts/service-api-acceptance.sh\nsh -n scripts/all-phases-acceptance.sh
```

Run one phase with, for example:

```sh
sh scripts/phase2-acceptance.sh
```

Run the complete implemented-phase regression suite with:

```sh
sh scripts/all-phases-acceptance.sh
```

The service/API matrix uses explicit HTTP status/body assertions for every currently implemented HTTP route that can be exercised safely without sending feedback email or mutating the registry with synthetic station data. The collector write path is proven using a new real station-only HTTP 202 in the Nginx access log after the test starts. Direct replica checks execute HTTP requests from inside each API container because replica ports are deliberately not published on the host.\n\nPhase 3 and Phase 4 include deliberate container restart/failure/recreation tests. Run the complete suite only during an acceptable development/test interruption window.

## Historical versus current-state validation

The project has evolved in place. Phase 2 no longer makes SQLite the live backend, and Phase 3 no longer represents a one-API topology. Their runners therefore regression-test the durable acceptance properties that still exist in the current checkout rather than trying to downgrade the live stack to an obsolete architecture.

Historical migration/count evidence remains in the phase documents. A current acceptance runner must not claim to re-perform the original SQLite-to-PostgreSQL migration when live PostgreSQL has subsequently received additional observations.

## Phase 5

No Phase 5 implementation/acceptance contract is currently defined in the repository. A Phase 5 runner must be added only when its objective and acceptance criteria are committed; the test must follow the implementation rather than invent requirements in advance.

## Evidence rule

A runner being committed means only that the test is implemented. It becomes **Tested** only after it is run on the intended environment and its result is recorded in Git. Do not commit secrets, tokens, passwords, raw aircraft traffic or transient container addresses in acceptance evidence.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe cross-phase acceptance framework is now Tested. The complete Synology run passed Phases 1–4 and the current service/API matrix, including direct checks of both API replicas and a new collector HTTP 202 through Nginx. See `CHECKPOINT-2026-09-18.md`.\n

## Administrator device-pairing acceptance

Automated server check:

```bash
sh scripts/admin-pairing-acceptance.sh
```

Pass requires: pairing page reachable from an allowed network; code exchange succeeds; the issued device credential can read Admin summary; reuse of the code returns 401; revocation succeeds; and the revoked credential returns 401. The script prints no code or credential.

Manual iOS acceptance additionally requires a physical-device QR scan, Face ID/passcode unlock, relaunch persistence and manual-code fallback. This passed on 3 October 2026.

Manual Android acceptance requires the same scanner, persistence, revocation and fallback checks on a Google Play-enabled device. Source is implemented; device runtime acceptance remains pending.

Also verify the pairing page is rejected from outside the configured trusted networks. See `docs/ADMIN-PAIRING-AND-RELEASE.md`.


## Admin self-monitoring acceptance

After rebuilding the Admin services, unlock Admin and confirm the container list includes exactly one running/healthy `atom-admin-monitor` and one running/healthy `atom-admin-control`. Run `scripts/admin-scaling-acceptance.sh`; both Admin services must remain healthy singletons throughout the 2→3→2 API replica test.
