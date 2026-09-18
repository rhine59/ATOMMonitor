# OGN APRS Investigation

## Purpose

Use the OGN APRS infrastructure only for ground-receiver/ATOM health and technical details. ATOM Monitor is not an aircraft-tracking application.

## Working connection model

Research examples in the OGN ecosystem use APRS servers such as:

```text
aprs.glidernet.org:14580
```

with an APRS login and optional server-side filter. Receive-only/unverified login behaviour and the exact filter needed for receiver-status packets must be verified before implementation.

## Receiver/status information of interest

Depending on receiver/software version, status messages may expose some subset of:

- receiver/station identifier;
- receiver position and altitude;
- status timestamp/heartbeat;
- receiver software/version/platform;
- CPU load;
- RAM usage/total;
- temperature;
- NTP offset and frequency correction;
- RF/frequency correction;
- RF gain/quality-related fields;
- other system-health values.

Not every station will report every field. Parsers and database columns therefore need optional/null values.

## Parser strategy

Do not write a parser based on a single example packet. Capture a representative corpus from PWMalham and multiple other ATOM/OGN receivers and add those packets as sanitised parser fixtures/tests where licensing/data considerations permit.

Parser stages:

```text
raw APRS line
    |
    +-- comment/server line? -> ignore
    |
    +-- parse envelope/source/path
    |
    +-- receiver beacon/status? -> parse health fields
    |
    +-- aircraft/other traffic? -> discard
    |
    v
canonical StationObservation
```

## Privacy/scope guardrail

Aircraft traffic may necessarily pass through the TCP socket because of upstream filtering limitations, but it is out of scope. The collector must not persist aircraft positions, aircraft identifiers or tracks. Logging should avoid dumping unrestricted raw traffic in production.

## PWMalham validation milestone

Before building the full server:

1. establish a compliant receive-only connection;
2. capture PWMalham receiver/status messages;
3. establish its normal reporting interval;
4. map each observed health field to a canonical field;
5. test parser behaviour when fields are absent;
6. repeat with several ATOM stations running different software versions;
7. determine whether `PW` naming is sufficient for candidate discovery or whether a stronger ATOM-identification method is available.

## Useful upstream code references

- `glidernet/ogn-aprs-protocol`
- `Meisterschueler/python-ogn-client`
- other current `glidernet` receiver/server examples

Use these as protocol references, not as an assumption that all old packet examples remain current.
\n\n## Checkpoint synchronization — 18 September 2026\n\nThe collector remains single-active and station-only, and now submits authenticated observations through Nginx to the replicated API tier. The complete acceptance suite observed a new live collector HTTP 202 through that path. See `CHECKPOINT-2026-09-18.md`.\n