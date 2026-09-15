# ATOM Monitor Server

The server will collect ground-receiver health/status observations, maintain a persistent ATOM station registry and history, derive health states, and expose a small HTTPS/JSON API to the iPhone app.

## Planned stack

- Python 3
- OGN/APRS TCP client/parser
- FastAPI
- PostgreSQL
- Docker / Docker Compose
- Synology NAS deployment

The exact APRS parsing dependency will be selected after live PWMalham packet validation. We may use an existing OGN parser where appropriate or implement a small receiver-status-focused parser with protocol fixtures/tests.

## Strict scope rule

The server is not an aircraft tracker. Aircraft position/identity messages must not be persisted. Production logging must also avoid accidentally becoming a raw aircraft-traffic archive.

## First implementation

The first code should be a diagnostic collector, not the full API. It should connect, identify PWMalham receiver/status packets, print/parse the relevant station-health fields and safely ignore everything else. Captured packet variants then become parser tests before database/API implementation.
