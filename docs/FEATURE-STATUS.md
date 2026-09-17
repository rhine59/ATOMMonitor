# ATOM Monitor — Feature, Objective and Status Register

Last updated: 17 September 2026

This is the authoritative change register for user-visible features and engineering changes in ATOM Monitor. Every change must update this file in the same development cycle as the implementation.

## Status vocabulary

- **Planned** — objective agreed; implementation not started.
- **In progress** — implementation is being changed and has not reached a build checkpoint.
- **Implemented — build pending** — source is committed; current change has not yet been confirmed to build.
- **Build passed — runtime test pending** — current source has a confirmed build but required functional/regression testing is incomplete.
- **Tested** — required build and functional checks have passed and evidence/status is recorded in Git.
- **Blocked** — progress depends on an identified external or technical issue.

A source-code commit alone does not mean a feature is Tested.

## Current feature register

| Feature / change | Objective | Platform | Status | Verification / notes |
| --- | --- | --- | --- | --- |
| Phase 1 Docker resilience hardening | Make the existing single-Synology Compose deployment self-checking and operationally safer before database migration/replication: liveness/readiness, Docker health state, health-gated collector startup, graceful shutdown, bounded logs and authenticated ingestion. | Server / Synology Docker | Build passed — runtime test pending | Health/readiness, 305-station persistence, collector recovery, Gunicorn, public HTTPS reads and authenticated ingestion passed 17 Sep 2026. Resource safeguards remain to be measured before closing Phase 1. |
| Production WSGI API serving | Replace Flask's development server with a production WSGI process while preserving the API contract and health/readiness checks. | Server / Synology Docker | Tested | Gunicorn 23.0.0, 2 workers × 2 threads; `/ready` DB OK; 305 stations retained; live collector POSTs accepted. |
| Public ATOM server connection | Use Synology HTTPS for normal remote station-health access while retaining LAN 8088 for diagnostics. | Server / iOS | Tested | Public HTTPS read path and normal TLS validation passed; iPhone subsequently loaded Stations/Map successfully through the configured service. |
| Connection test station count | Make Test Connection prove API/database readiness and report the confirmed station count from `/ready`. | iOS | Tested | Commit `0fcb967` changed Test Connection from `/health` to `/ready`; user built/ran on iPhone 17 Sep 2026 and confirmed Test Connection plus Stations/Map all good. |
| Public API write-boundary hardening | Reject unauthenticated observation ingestion while allowing the intended private collector to continue station-only ingestion. | Server | Tested | Shared `ATOM_INGEST_TOKEN` is supplied locally via ignored `server/.env`. Internal collector POSTs repeatedly returned 202; unauthenticated public HTTPS POST returned 401 on 17 Sep 2026. |
| Home-relative filtered map focus | Focus the filtered Map on the matching station nearest Home, with UK fallback and startup Home guidance. | iOS | Tested | User confirmed runtime behaviour good 17 Sep 2026. |
| Station report and native sharing | Summarise station status/version and share station-only HTML/CSV through native iOS capabilities. | iOS | Tested | Physical iPhone report/share flow confirmed good 17 Sep 2026. |
| Report bar graphs | Add responsive horizontal report graphs while retaining exact tables and CSV. | iOS | Tested | User confirmed updated report/share result good 17 Sep 2026. |
| Persistent Xcode signing team | Preserve automatic signing through XcodeGen. | iOS build tooling | Tested | Development Team `VNQTGCW476`; user confirmed fixed. |
| Simulator Report coverage | Keep the recorded Simulator feature tour aligned with current navigation/report behaviour. | iOS tests | Tested | Automated feature tour passed 17 Sep 2026; final MP4/log generated under `artifacts/`. |
| Compact Stations headings | Use `Stations` rather than `ATOM Stations` on Map and Stations. | iOS | Build passed — runtime test pending | Current source builds; broader physical-device acceptance pending. |
| Last-updated station count | Show current station count beside last successful refresh; retain cached count on failure. | iOS / Android | Implemented — build pending | Android build pending. |
| Shared status and PilotAware-version filters | Filter Map and Stations from the same in-memory dataset. | iOS / Android | Build passed — runtime test pending | Android build pending. |
| Configurable inactive threshold | Derive Inactive from configurable `lastSeen` age, default 2 days. | iOS / Android | Build passed — runtime test pending | Android build pending. |
| Inactive map presentation | Make Inactive visually distinct and red by default. | iOS / Android | Build passed — runtime test pending | Android marker parity incomplete. |
| Mixed map clusters | Visually flag aggregates containing degraded states. | iOS | Build passed — runtime test pending | Runtime cluster regression remains. |
| Configurable map icon colours | Persist configurable colours for all displayed health states. | iOS | Build passed — runtime test pending | Runtime colour/persistence regression remains. |
| Back-level PilotAware software presentation | Identify older PilotAware versions without overriding operational health. | iOS | Build passed — runtime test pending | Numeric/case-insensitive comparison. |
| Absolute station record timestamp | Show absolute local latest-record time while retaining relative observation ages. | iOS / Android | Build passed — runtime test pending | Android build pending. |
| Persistent station cache | Preserve last successful station snapshot across network failure. | iOS / Android | Build passed — runtime test pending | Server-specific cache remains roadmap work; Android build pending. |
| Favourites persistence | Retain favourite ground stations locally. | iOS / Android | Build passed — runtime test pending | Android build pending. |
| Native local User Guide | Keep operational instructions available inside the app. | iOS / Android | Build passed — runtime test pending | Android build pending. |
| Android native client | Provide equivalent station-only monitoring on Android. | Android | Implemented — build pending | First confirmed Android build required. |
| Android station report and native sharing | Provide Android report/share parity. | Android | Implemented — build pending | Build/runtime validation required. |
| Android clustering and mixed-colour clusters | Provide Android map clustering parity. | Android | Planned | Required for full map parity. |
| Refresh serialization | Prevent startup, periodic and manual refreshes from overlapping. | iOS / Android as applicable | Planned | Roadmap item 2. |
| Stale packet overwrite protection | Prevent delayed older observations replacing newer station telemetry. | Server | Planned | Roadmap item 3; timestamp-category tests required. |
| Synology database backup/recovery automation | Make station-registry backup, integrity checking and recovery repeatable. | Server | Planned | Roadmap item 7. |

## Mandatory change workflow

For every implementation change: update this register and affected documentation; commit implementation/documentation; build; record meaningful evidence; run runtime/regression checks; and only then mark Tested. Later changes that affect a Tested feature return it to the appropriate pending state until affected checks are repeated.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It must not display, record or retain aircraft movements, tracks or aircraft identities.
