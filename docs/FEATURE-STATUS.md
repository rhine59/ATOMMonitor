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
| Documentation and guide synchronization | Keep architecture, API, build/test, checkpoint, feature register and in-app guides aligned with current implementation and cross-platform policy. | Project / iOS / Android | Implemented — build pending | Architecture, API design, build/test guide and 17 Sep checkpoint synchronized; Android runtime networking checkpoint added after successful emulator test. Current phone guides still require their normal feature-specific regression checks after later changes. |
| Phase 1 Docker resilience hardening | Make the existing single-Synology Compose deployment self-checking and operationally safer before database migration/replication: liveness/readiness, Docker health state, health-gated collector startup, graceful shutdown, bounded logs and authenticated ingestion. | Server / Synology Docker | Tested | Health/readiness, station persistence, collector recovery, Gunicorn, public HTTPS reads and authenticated ingestion passed 17 Sep 2026. Two resource samples were stable at about 84 MiB API and 23 MiB collector; no evidence justified arbitrary tight resource caps. Evidence recorded in `docs/PHASE1-TEST-EVIDENCE-2026-09-17.md`. |
| Production WSGI API serving | Replace Flask's development server with a production WSGI process while preserving the API contract and health/readiness checks. | Server / Synology Docker | Tested | Gunicorn 23.0.0, 2 workers × 2 threads; `/ready` DB OK; persistent stations retained; live collector POSTs accepted. |
| Public ATOM server connection | Use Synology HTTPS for normal remote station-health access while retaining LAN 8088 for diagnostics. | Server / iOS / Android | Tested | Public HTTPS read path and normal TLS validation passed on iPhone and Android. On 17 Sep Android Pixel 10a / Android 17 API 37.2 loaded 305 live stations after commit `b472821` moved blocking HTTP work off the UI thread. |
| Connection test station count | Make Test Connection prove API/database readiness and report the confirmed station count from `/ready`. | iOS | Tested | Commit `0fcb967` changed Test Connection from `/health` to `/ready`; user built/ran on iPhone 17 Sep 2026 and confirmed Test Connection plus Stations/Map all good. |
| Public API write-boundary hardening | Reject unauthenticated observation ingestion while allowing the intended private collector to continue station-only ingestion. | Server | Tested | Shared `ATOM_INGEST_TOKEN` is supplied locally via ignored `server/.env`. Internal collector POSTs repeatedly returned 202; unauthenticated public HTTPS POST returned 401 on 17 Sep 2026. |
| Stale packet overwrite protection | Prevent delayed older observations replacing newer station telemetry and prevent implausible future packet clocks poisoning category ordering. | Server | Tested | Category-ordering and future timestamp tests passed. Live deployment retained the station registry, `/ready` DB OK, normal collector observations returned 202, and a live PWAachen position nearly 12 hours in the future was rejected with HTTP 400 while its valid heartbeat continued. Commits `f3058c1`, `89f066e`, `6a928ba`, `eca369d`. |
| Station detail telemetry cleanup | Keep station detail focused on fields actually populated by the live station feed. | iOS / Android | Build passed — runtime test pending | Uptime, Supply voltage and Frequency correction omitted from both phone detail displays. Android current source builds after networking fix; Station Detail runtime interaction still pending. iOS commit `ccc4312`; Android parity commit `afd17fe`. |
| Station detail icon explanation | Show the station's effective map/status icon in station detail and explain what it means. | iOS / Android | Build passed — runtime test pending | iOS and Android detail render/explain effective health, including Healthy/back-level presentation. Android current source builds; detail runtime interaction still pending. |
| Google Maps satellite station pin | Open Station Detail coordinates in Google Maps with satellite imagery and a pin on the target location. | iOS / Android | Build passed — runtime test pending | Both clients request station latitude/longitude, satellite imagery and zoom 18. Android current source builds; final Maps intent runtime verification remains pending. |
| Home-relative filtered map focus | Focus the filtered Map on the matching station nearest Home, with UK fallback and startup Home guidance. | iOS / Android | In progress | iOS runtime behaviour previously passed; later no-filter refresh correction requires regression. Android parity is still outstanding. |
| Station report and native sharing | Summarise station status/version and share station-only HTML/CSV through native phone capabilities. | iOS / Android | Build passed — runtime test pending | iOS physical report/share flow previously passed. Android current source builds and live station data loads; Android report/share interaction remains pending. |
| Report bar graphs | Add responsive horizontal report graphs while retaining exact tables and CSV. | iOS / Android | Build passed — runtime test pending | iOS result previously passed; Android source builds but report/share runtime remains pending. |
| Persistent Xcode signing team | Preserve automatic signing through XcodeGen. | iOS build tooling | Tested | Development Team `VNQTGCW476`; user confirmed fixed. |
| Simulator Report coverage | Keep the recorded Simulator feature tour aligned with current navigation/report behaviour. | iOS tests | Tested | Automated feature tour passed 17 Sep 2026; final MP4/log generated under `artifacts/`. |
| Compact Stations headings | Use `Stations` rather than `ATOM Stations` on Map and Stations. | iOS / Android | Tested | Android Pixel 10a runtime on 17 Sep displayed the compact `Stations` heading with the live 305-station dataset. |
| Last-updated station count | Show current station count beside last successful refresh; retain cached count on failure. | iOS / Android | Build passed — runtime test pending | Android live-success path passed with 305 stations shown after refresh; cached-count-on-failure behaviour still requires regression. |
| Shared status and PilotAware-version filters | Filter Map and Stations from the same in-memory dataset. | iOS / Android | Build passed — runtime test pending | Android current source builds and live data loads; filter interactions remain pending. |
| Configurable inactive threshold | Derive Inactive from configurable `lastSeen` age, default 2 days. | iOS / Android | Build passed — runtime test pending | Android current source builds and live data loads; threshold interaction remains pending. |
| Inactive map presentation | Make Inactive visually distinct and red by default. | iOS / Android | In progress | Android marker parity incomplete. |
| Mixed map clusters | Visually flag aggregates containing degraded states. | iOS / Android | In progress | iOS implemented; Android clustering/mixed-colour parity remains outstanding. |
| Configurable map icon colours | Persist configurable colours for all displayed health states. | iOS / Android | In progress | iOS implemented; Android parity remains outstanding. |
| Back-level PilotAware software presentation | Identify older PilotAware versions without overriding operational health. | iOS / Android | Build passed — runtime test pending | Station Detail parity exists and Android current source builds; broader Android map/list colour presentation and runtime detail check remain. |
| Absolute station record timestamp | Show absolute local latest-record time while retaining relative observation ages. | iOS / Android | Build passed — runtime test pending | Both Station Detail implementations contain this presentation; Android current source builds, detail runtime check pending. |
| Persistent station cache | Preserve last successful station snapshot across network failure. | iOS / Android | Build passed — runtime test pending | Android live retrieval passed; cache/no-network regression remains pending. Server-specific cache remains roadmap work. |
| Favourites persistence | Retain favourite ground stations locally. | iOS / Android | Build passed — runtime test pending | Android current source builds and live data loads; favourite persistence interaction remains pending. |
| Native local User Guide | Keep operational instructions available inside the app and synchronized with current behaviour. | iOS / Android | Build passed — runtime test pending | Both in-app guides updated 17 Sep 2026. Android current source builds; guide/navigation runtime check remains pending. |
| Android native client | Provide equivalent station-only monitoring on Android. | Android | Build passed — runtime test pending | Debug APK build passed. Pixel 10a / Android 17 API 37.2 runtime connected to public HTTPS and loaded 305 stations with map markers after threading fix `b472821`. Responsive-layout regression also built and ran successfully on Pixel 10a on 17 Sep. Full six-area Android regression is still incomplete. |
| Android public station refresh threading | Keep blocking HTTP work off the Android main/UI thread while preserving Compose state updates and useful diagnostics. | Android | Tested | Initial emulator run exposed `NetworkOnMainThreadException` in `StationVM.refresh()`. Commit `b472821` moved HTTP work to `Dispatchers.IO`; `assembleDebug` passed and rerun loaded 305 live stations with map markers. |
| Android station detail parity | Match the current iPhone Station Detail information and navigation objective. | Android | Build passed — runtime test pending | Commit `afd17fe`; current source builds and live dataset loads, but Station Detail interaction/Maps checks remain pending. |
| Android station report and native sharing | Provide Android report/share parity. | Android | Build passed — runtime test pending | Current debug build passes and live station data loads; runtime report/share validation remains required. |
| Android screen-space utilisation | Use Android phone screen area efficiently, keeping the map dominant and navigation legible without wrapped labels, with layout driven by the available window rather than a fixed phone size. | Android | Tested | Responsive launcher commits `82888a5` and `d0c16eb`. Command-line `assembleDebug` passed; after clearing stale Android Studio incremental output, Clean Project and Assemble Project passed with warnings only. Pixel 10a runtime on 17 Sep confirmed a full-height map, compact overlaid Stations/search/filter/refresh controls and all six bottom navigation labels visible without wrapping. Screenshot/user review confirmed the layout looks good. Further device-size/orientation coverage remains desirable regression testing rather than a blocker for this Pixel 10a checkpoint. |
| Android clustering and mixed-colour clusters | Provide Android map clustering parity. | Android | Planned | Required for full map parity. |
| Android configurable map colours | Match iPhone persisted map/status colour controls. | Android | Planned | Required for full presentation parity. |
| Android Home-relative filtered map focus | Match iPhone Home-centred and nearest-filtered-station map behaviour. | Android | Planned | Required for full navigation parity. |
| Refresh serialization | Prevent startup, periodic and manual refreshes from overlapping. | iOS / Android as applicable | Planned | Roadmap item 2. |
| Synology database backup/recovery automation | Make station-registry backup, integrity checking and recovery repeatable. | Server | Planned | Roadmap item 7. |

## Cross-platform parity rule

A user-facing phone feature or behaviour change must be implemented on both iOS and Android in the same development cycle unless there is a documented platform-specific reason not to. Native implementation details may differ, but the user-visible objective must remain aligned. Build and runtime status are always tracked separately; a pass on one platform does not imply a pass on the other.

## Mandatory change workflow

For every implementation change: update this register and affected documentation; commit implementation/documentation; build; record meaningful evidence; run runtime/regression checks; and only then mark Tested. Later changes that affect a Tested feature return it to the appropriate pending state until affected checks are repeated.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It must not display, record or retain aircraft movements, tracks or aircraft identities.
