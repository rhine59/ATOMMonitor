# Design Decisions

This file records decisions and the reasoning behind them. New material changes should be added here rather than silently changing assumptions.

## DD-001 — Ground-station health only

**Decision:** ATOM Monitor will monitor ATOM ground-station health/details and will not be an aircraft-tracking application.

**Reason:** The project goal is to inspect ATOM infrastructure, not duplicate traffic/flight-tracking products.

**Consequence:** Aircraft position/identity/track data must not be persisted. Collector filtering and production logging should reflect this boundary.

## DD-002 — Map-first user interface

**Decision:** The iPhone opens to a map containing all known ATOM stations.

**Reason:** Geographic network health is the most useful overview and naturally supports navigation to a chosen station.

## DD-003 — Persistent station registry

**Decision:** Known stations remain in the registry/map after they stop reporting.

**Reason:** Removing a failed station would hide exactly the failure the app is intended to expose.

## DD-004 — Conservative status terminology

**Decision:** Initial states are Healthy, Warning, No recent heartbeat and Unknown.

**Reason:** Missing receiver telemetry does not prove that the physical station is powered off. `Offline` would overstate what the source tells us.

## DD-005 — OGN APRS as primary live-health candidate

**Decision:** Investigate/build around OGN APRS receiver/status data first.

**Reason:** OGN infrastructure carries receiver-status information and avoids relying on KTrax as the primary automated source. PilotAware sources remain possible supplementary providers.

**Status:** Architecture decision pending final validation of live ATOM packet coverage and acceptable upstream usage.

## DD-006 — Central collector rather than direct iPhone APRS

**Decision:** Run the APRS collector/server on the Synology in Docker and expose HTTPS/JSON to iOS.

**Reason:** One persistent upstream connection, reliable background operation, history while the phone is closed, simpler iOS networking and better future scalability.

## DD-007 — PWMalham reference station

**Decision:** Use `PWMalham` as the initial end-to-end test station.

**Reason:** It is a concrete PilotAware station already identified during research and provides a stable name around which to validate discovery/status parsing.

## DD-008 — Missing telemetry remains missing

**Decision:** Optional health values are nullable and shown as `Not reported`.

**Reason:** Zero may be a valid value and must not be confused with absence of data.

## DD-009 — Health thresholds follow observation

**Decision:** Do not hard-code final heartbeat/telemetry warning thresholds until real reporting intervals and values have been sampled across representative ATOM stations.

## DD-010 — Documentation evolves with implementation

**Decision:** README, architecture, research notes and this decision log should be updated as material implementation decisions change.

**Reason:** The repository should preserve project thinking as well as source code.


## DD-011 — Feedback is relayed server-side

**Decision:** Phone clients submit ratings/comments to the ATOM Monitor server; the server sends the email to Richard Hine. The destination email address is not embedded or displayed in either phone client.

**Reason:** A client-side mail composer would reveal the private destination address and depend on local mail configuration.

**Consequence:** Feedback UI may ship independently, but delivery remains **pending** until private SMTP settings are configured and tested on the Synology. SMTP credentials and the destination address must never be committed to Git.

## DD-012 — Feedback and About are first-class navigation areas

**Decision:** Feedback and About sit at the same main-navigation level as Settings and Help on iPhone and Android.

**Reason:** They are application-level functions rather than Settings sub-options.

**Consequence:** Avoid duplicate links or nested navigation stacks that create duplicate Back controls.

## DD-013 — About owns product identity, attribution and distribution notices

**Decision:** About displays Version, Build and Platform separately, credits Richard Hine, links to the official PilotAware ATOM page, carries the copyright/trademark/non-affiliation notice, and identifies the applicable distribution/open-source notices.

**Reason:** Product identity, third-party attribution and licence information should be visible in the installed application and synchronized across platforms.

**Consequence:** Do not duplicate a combined Version / Build row. iOS uses the Apple Standard EULA unless a custom EULA is deliberately adopted. Android retains the project's proprietary status while separately acknowledging licences applicable to AndroidX/Jetpack Compose, osmdroid and OpenStreetMap data.

## DD-014 — Proprietary distribution by default

**Decision:** ATOM Monitor remains proprietary: © 2026 Richard Hine. All rights reserved. No project-level open-source licence is granted unless a later explicit decision changes this.

**Reason:** Third-party open-source components do not require the ATOM Monitor application itself to be released under the same permissive licences.

**Consequence:** Release packaging must preserve required third-party notices and must not commit signing keys, passwords, SMTP secrets or other distribution credentials.
\n\n## Checkpoint synchronization — 18 September 2026\n\nImplementation checkpoint: PostgreSQL is the live backend; two stateless API replicas run behind Nginx; the collector remains single-active and submits through Nginx. The complete Phase 1–4/service acceptance suite passed. This operational topology and the reproducible-rebuild/acceptance-test discipline are now established project decisions. See `CHECKPOINT-2026-09-18.md`.\n