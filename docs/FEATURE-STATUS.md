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
| Public ATOM server connection | Use the Synology-hosted HTTPS endpoint for normal remote station-health access while retaining LAN port 8088 for diagnostics only. | Server / iOS | Build passed — runtime test pending | Public endpoint is `https://granvillehouse.synology.me:8445/`. Physical-iPhone Wi-Fi and cellular regression still required. |
| Connection test station count | Make Test Connection prove both API health and the number of confirmed stations returned by `/health`. | iOS | Build passed — runtime test pending | Expected presentation: `OK — <count> stations`. Current iOS source build confirmed good by user 17 Sep 2026; runtime UI verification pending. Implemented in commit `dfa2992`. |
| Compact Stations headings | Save top-screen space by using `Stations` rather than `ATOM Stations` on Map and Stations screens. | iOS | Build passed — runtime test pending | Current iOS source build confirmed good by user 17 Sep 2026; visual verification pending. Commits `67e01aa`, `0e7a2b5`. |
| Last-updated station count | Show the current station count alongside the last successful refresh time; retain cached count on network failure. | iOS | Build passed — runtime test pending | Expected examples: `Last updated: 09:42 • 301 stations`; `No Network • 301 stations`. Current iOS source build confirmed good by user 17 Sep 2026; runtime verification pending. Commit `67e01aa`. |
| Shared status and PilotAware-version filters | Allow Map and Stations to filter the same in-memory dataset by collected status and PilotAware version values. | iOS / Android | Build passed — runtime test pending | Multi-select; OR within category, AND across categories; search combines with filters. iOS current source build confirmed; Android build remains pending. |
| Configurable inactive threshold | Derive Inactive when `lastSeen` is at least the configured number of days old; default 2 days. | iOS / Android | Build passed — runtime test pending | iOS current source build confirmed good 17 Sep 2026; runtime inactive-data test remains incomplete. Android build remains pending. |
| Inactive map presentation | Make Inactive visually distinct and red by default. | iOS / Android | Build passed — runtime test pending | iOS current source build confirmed; Android implementation exists but Android build has not yet been confirmed. |
| Mixed map clusters | Make aggregate markers visually flag degraded content before zooming. Healthy + Inactive remains yellow, and any aggregate containing a No recent heartbeat station is yellow by default while the individual station remains blue by default. | iOS | Build passed — runtime test pending | Current iOS source including no-recent-heartbeat aggregate rule built successfully as confirmed by user 17 Sep 2026. Runtime cluster verification required. Rule implemented in commit `eae1f2a`. |
| Configurable map icon colours | Let the user choose and persist colours for Healthy, Back-level software, No recent heartbeat, Inactive, Warning and Unknown; provide Restore default colours. | iOS | Build passed — runtime test pending | Defaults: Healthy green; Back-level purple; No recent heartbeat blue; Inactive red; Warning orange; Unknown grey. Current iOS source build confirmed good by user 17 Sep 2026; settings persistence/map runtime verification pending. Commits `61245b0`, `d917040`, `6dac56b`. |
| Back-level PilotAware software presentation | Identify a station as back-level when its reported PilotAware version is older than another collected station's version, without overriding a more important operational health state. | iOS | Build passed — runtime test pending | Numeric/case-insensitive version comparison. Current iOS source build confirmed good by user 17 Sep 2026; runtime version-colour verification pending. Commit `bf397fe`. |
| Station report and native sharing | Provide an at-a-glance report of the current ATOM ground-station dataset with counts by displayed status and PilotAware software version, and allow it to be sent using standard iPhone sharing capabilities. | iOS | Build passed — runtime test pending | First build attempt failed in `ReportView.swift`; corrective commit `3850e99` fixed compilation. User then confirmed `BUILD SUCCEEDED` on 17 Sep 2026. Runtime checks still required for Report counts, HTML generation, CSV contents and standard iPhone share sheet. Original implementation commits `435a454`, `6dce7d6`. |
| Absolute station record timestamp | Show the absolute local date/time of the latest station record while retaining relative ages for individual observation categories. | iOS | Build passed — runtime test pending | Implemented earlier; physical-device regression remains part of acceptance. |
| Persistent station cache | Preserve the last successful station snapshot across launch/network failure without creating an aircraft-history database. | iOS | Build passed — runtime test pending | Server-specific cache remains roadmap work. |
| Favourites persistence | Retain user-selected favourite ground stations locally. | iOS / Android | Build passed — runtime test pending | Physical-device regression still required; Android build remains pending. |
| Native local User Guide | Keep operational instructions available inside the app without external web dependency. | iOS / Android | Build passed — runtime test pending | iOS guide including Report now builds successfully; runtime/offline guide verification remains pending. Android build remains pending. |
| Android native client | Provide equivalent ATOM ground-station monitoring on Android without aircraft tracking or aircraft data. | Android | Implemented — build pending | Initial Kotlin/Compose implementation is committed, but no confirmed Android build yet; parity/hardening work remains. |
| Android clustering and mixed-colour clusters | Provide Android marker clustering and the same mixed-state cluster semantics as iOS, including yellow aggregates containing No recent heartbeat. | Android | Planned | Required for full map parity. |
| Android station report and native sharing | Provide Android report parity: current station counts by status/software version with shareable report and CSV station data. | Android | Planned | Implement after Android client reaches a confirmed build checkpoint. |
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
