# ATOM Monitor — Acceptance Test Runners

## Purpose

Acceptance tests are executable project evidence. Each implemented architecture phase has a committed POSIX `sh` runner that checks command results and returns non-zero on failure. Tests preserve the station-only scope and never require aircraft movement data.

## Runners

- `scripts/phase1-acceptance.sh` validates the base Synology/runtime boundary: required commands, repository checkout, ignored local environment, Compose validity, local readiness/station reads and the HTTP 401 ingestion boundary.
- `scripts/phase2-acceptance.sh` regression-tests the preserved SQLite backup/recovery mechanism entirely in a temporary directory: source integrity, backup, SHA-256/integrity verification, retention and controlled restore. It does not overwrite the live PostgreSQL registry or production backup directory.
- `scripts/phase3-acceptance.sh` validates the current PostgreSQL migration boundary: named-volume mount, PostgreSQL readiness, populated registry, reads/security, preserved SQLite rollback database, PostgreSQL restart persistence and API recovery. It deliberately restarts PostgreSQL and therefore causes a short development/test interruption.
- `scripts/phase4-acceptance.sh` validates the replicated topology: two API replicas, Nginx entry point, collector HTTP 202 traffic through Nginx, loss/rejoin of either replica, API recreation, load-balancer recreation, HTTP 401 ingestion boundary and final recovery.
- `scripts/all-phases-acceptance.sh` runs Phases 1–4 in order and stops if a runner exits non-zero.

Shared simple PASS/FAIL helpers live in `scripts/lib/acceptance.sh`.

## Running

From the repository root, syntax-check first:

```sh
sh -n scripts/phase1-acceptance.sh
sh -n scripts/phase2-acceptance.sh
sh -n scripts/phase3-acceptance.sh
sh -n scripts/phase4-acceptance.sh
sh -n scripts/all-phases-acceptance.sh
```

Run one phase with, for example:

```sh
sh scripts/phase2-acceptance.sh
```

Run the complete implemented-phase regression suite with:

```sh
sh scripts/all-phases-acceptance.sh
```

Phase 3 and Phase 4 include deliberate container restart/failure/recreation tests. Run the complete suite only during an acceptable development/test interruption window.

## Historical versus current-state validation

The project has evolved in place. Phase 2 no longer makes SQLite the live backend, and Phase 3 no longer represents a one-API topology. Their runners therefore regression-test the durable acceptance properties that still exist in the current checkout rather than trying to downgrade the live stack to an obsolete architecture.

Historical migration/count evidence remains in the phase documents. A current acceptance runner must not claim to re-perform the original SQLite-to-PostgreSQL migration when live PostgreSQL has subsequently received additional observations.

## Phase 5

No Phase 5 implementation/acceptance contract is currently defined in the repository. A Phase 5 runner must be added only when its objective and acceptance criteria are committed; the test must follow the implementation rather than invent requirements in advance.

## Evidence rule

A runner being committed means only that the test is implemented. It becomes **Tested** only after it is run on the intended environment and its result is recorded in Git. Do not commit secrets, tokens, passwords, raw aircraft traffic or transient container addresses in acceptance evidence.
