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
| Public ATOM server connection | Use the Synology-hosted HTTPS endpoint for normal remote station-health access while retaining LAN port 8088 for diagnostics only. | Server / iOS | Build passed — runtime test pending | Public endpoint is `https://granvillehouse.synology.me:8445/`. Full cellular regression remains part of checkpoint acceptance. |
| Connection test station count | Make Test Connection prove both API health and the number of confirmed stations returned by `/health`. | iOS | Build passed — runtime test pending | Expected presentation: `OK — <count> stations`. |
| Compact Stations headings | Save top-screen space by using `Stations` rather than `ATOM Stations` on Map and Stations screens. | iOS | Build passed — runtime test pending | Current iOS source builds and automated Simulator feature tour passes. Physical-device acceptance remains pending. |
| Last-updated station count | Show the current station count alongside the last successful refresh time; retain cached count on network failure. | iOS / Android | Implemented — build pending | iOS automated Simulator feature tour passes; Android source mirrors compact Stations/status-count presentation and awaits first Android build. |
| Shared status and PilotAware-version filters | Allow Map and Stations to filter the same in-memory dataset by collected status and PilotAware version values. | iOS / Android | Build passed — runtime test pending | Multi-select; OR within category, AND across categories; search combines with filters. Android build remains pending. |
| Home-relative filtered map focus | When Status or PilotAware-version filters change, automatically focus Map on the matching station nearest the configured Home station; if Home is unset/unavailable or no positioned match exists, return to the UK view. Advise users at normal app startup to configure Home. | iOS | Implemented — build pending | Uses geographic distance from the configured Home station to positioned filtered matches. Startup advice is suppressed in `--demo-mode` so automated test setup is not interrupted. Settings and local User Guide explain the behaviour. |
| Configurable inactive threshold | Derive Inactive when `lastSeen` is at least the configured number of days old; default 2 days. | iOS / Android | Build passed — runtime test pending | iOS current source confirmed; Android build remains pending. |
| Inactive map presentation | Make Inactive visually distinct and red by default. | iOS / Android | Build passed — runtime test pending | Android marker-artwork parity remains incomplete. |
| Mixed map clusters | Make aggregate markers visually flag degraded content before zooming. | iOS | Build passed — runtime test pending | No-recent-heartbeat aggregate yellow rule and Healthy + Inactive mixed yellow rule implemented; runtime cluster regression remains. |
| Configurable map icon colours | Let the user choose and persist colours for Healthy, Back-level software, No recent heartbeat, Inactive, Warning and Unknown; provide Restore default colours. | iOS | Build passed — runtime test pending | Defaults: Healthy green; Back-level purple; No recent heartbeat blue; Inactive red; Warning orange; Unknown grey. |
| Back-level PilotAware software presentation | Identify a station as back-level when its reported PilotAware version is older than another collected station's version, without overriding a more important operational health state. | iOS | Build passed — runtime test pending | Numeric/case-insensitive version comparison. |
| Station report and native sharing | Summarise the current ATOM station dataset by displayed status and PilotAware version and share station-only report files using native phone capabilities. | iOS | Tested | Physical iPhone report/share flow confirmed good by user 17 Sep 2026, including the first-attempt share-sheet timing fix. |
| Report bar graphs | Make the shared HTML report easier to interpret visually with responsive horizontal status/version bar graphs while retaining exact count tables and CSV. | iOS | Tested | User confirmed the updated report/share result good on 17 Sep 2026. HTML/CSS only; CSV remains station-level data. |
| Persistent Xcode signing team | Prevent `xcodegen generate` from requiring manual Signing → Team selection each time. | iOS build tooling | Tested | `project.yml` now uses automatic signing and Development Team `VNQTGCW476`. User regenerated project and confirmed the issue fixed 17 Sep 2026. |
| Simulator Report coverage | Keep the recorded iOS Simulator feature tour aligned with current navigation/report functionality and compact-width More-tab behaviour. | iOS tests | Tested | After commits `0c4a4ca` and `6158901`, the automated feature tour handles refresh accessibility and Settings/Help under More. User reran `record-demo.sh` on 17 Sep 2026 and reported `PASS: automated ATOM Monitor feature tour completed.` Final MP4 and UI-test log were generated under `artifacts/`. |
| Absolute station record timestamp | Show the absolute local date/time of the latest station record while retaining relative ages for individual observation categories. | iOS / Android | Build passed — runtime test pending | Physical-device/platform regression remains part of acceptance. |
| Persistent station cache | Preserve the last successful station snapshot across launch/network failure without creating an aircraft-history database. | iOS / Android | Build passed — runtime test pending | Server-specific cache remains roadmap work; Android build pending. |
| Favourites persistence | Retain user-selected favourite ground stations locally. | iOS / Android | Build passed — runtime test pending | Android build remains pending. |
| Native local User Guide | Keep operational instructions available inside the app without external web dependency. | iOS / Android | Implemented — build pending | iOS guide now documents Home-relative filter focus; Android local Help includes Report scope/sharing and awaits Android build. |
| Android native client | Provide equivalent ATOM ground-station monitoring on Android without aircraft tracking or aircraft data. | Android | Implemented — build pending | Kotlin/Compose source updated 17 Sep 2026; first confirmed Android build is still required. |
| Android station report and native sharing | Provide Android report parity: current station counts by status/software version, responsive HTML bar graphs, CSV station data and native sharing. | Android | Implemented — build pending | Report tab, HTML/CSV generator, Android share chooser and FileProvider cache-path configuration committed 17 Sep 2026. Must be built and exercised in Android Studio/emulator/device before advancing. |
| Android clustering and mixed-colour clusters | Provide Android marker clustering and the same mixed-state cluster semantics as iOS. | Android | Planned | Required for full map parity. |
| Refresh serialization | Prevent startup, periodic and manual station refresh requests from overlapping or producing misleading refresh state. | iOS / Android as applicable | Planned | Roadmap item 2. |
| Stale packet overwrite protection | Prevent delayed older observations from replacing newer station telemetry in persistent server state. | Server | Planned | Roadmap item 3; requires timestamp-category tests. |
| Public API write-boundary hardening | Prevent unauthenticated Internet clients from submitting arbitrary station observations while retaining intended read access. | Server | Planned | Roadmap item 4. |
| Synology database backup/recovery automation | Make persistent station-registry backup, integrity checking and recovery repeatable. | Server | Planned | Roadmap item 7. |

## Mandatory change workflow

For every implementation change:

1. Add or update the feature row here with the **feature/change**, **objective**, **platform**, **status**, and verification notes.
2. Update affected design, requirements, user-guide, architecture, API or runbook documentation in the same development cycle.
3. Commit implementation and synchronized documentation to GitHub.
4. Build using the documented reproducible procedure. Do not mark a feature `Build passed` until the build result is actually confirmed.
5. Record meaningful build/test evidence in `docs/BUILD-AND-TEST.md` and/or a tracked milestone log when appropriate.
6. Run the required runtime/regression checks. Do not mark `Tested` until those checks actually pass.
7. If a later change touches an already-tested feature, move that feature back to the appropriate pending state until the affected checks have been repeated.

## Scope invariant

ATOM Monitor monitors PilotAware ATOM ground-station operational health and technical status only. It must not display, record or retain aircraft movements, tracks or aircraft identities. Every feature and test must preserve this boundary.
