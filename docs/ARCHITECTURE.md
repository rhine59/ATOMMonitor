# Architecture

## Overview

ATOM Monitor is proposed as two cooperating components:

1. A server-side collector/API, intended to run in Docker on a Synology NAS.
2. A native SwiftUI iPhone client.

```text
       OGN APRS infrastructure
        receiver/status data
                |
                v
      +---------------------+
      | Collector service   |
      |---------------------|
      | TCP/APRS client     |
      | receiver parser     |
      | ATOM classifier     |
      | health evaluator    |
      +----------+----------+
                 |
                 v
      +---------------------+
      | Persistent storage  |
      |---------------------|
      | station registry    |
      | latest health       |
      | health history      |
      +----------+----------+
                 |
                 v
      +---------------------+
      | REST API            |
      +----------+----------+
                 |
              HTTPS
                 |
                 v
      +---------------------+
      | SwiftUI iPhone app  |
      |---------------------|
      | MapKit              |
      | search              |
      | station details     |
      | history             |
      +---------------------+
```

## Why use a server collector?

A central collector maintains one polite, persistent connection to the upstream OGN APRS service, can reconnect independently of the phone, keeps historical data while the app is closed, avoids iOS background-network limitations, and gives the iPhone a simple HTTPS/JSON interface.

## Collector responsibilities

- Connect/reconnect to the selected OGN APRS server.
- Request/filter receiver/status data as efficiently as the protocol permits.
- Parse receiver beacon/status messages.
- Identify candidate PilotAware ATOM stations.
- Upsert station identity/location into a persistent registry.
- Record current and historical technical telemetry.
- Derive a health state using explicit rules.
- Discard aircraft position traffic; do not write it to persistent storage.
- Expose health and station information through the REST API.

## Persistence

PostgreSQL is a good production fit, especially if the Synology already hosts PostgreSQL-backed Docker applications. SQLite may be useful for an early collector prototype. The application should keep persistence behind a repository/storage abstraction so the first parser tests do not depend on the final database.

## iOS responsibilities

- Fetch station registry/current health from REST API.
- Cache enough station data for a responsive map.
- Render station annotations and clusters.
- Search station names locally or via API.
- Present compact map selection card.
- Present detailed station health.
- Fetch historical series only when requested.
- Optionally use device location for map centring/nearest stations.

## Provider abstraction

The server should distinguish source adapters from the canonical station model. Proposed adapters:

- `OGNAPRSProvider` — primary live receiver/status source.
- `PilotAwareProvider` — future supplementary metadata/status if a suitable stable endpoint is available.
- `RegistryBootstrapProvider` — method for seeding known ATOM stations so failed stations remain discoverable.

This avoids coupling the app itself to OGN/APRS packet formats.

## Security and deployment

The iPhone should communicate with the server over HTTPS. Upstream credentials/passcodes, if required, stay server-side and are never compiled into the app. Docker configuration should use environment variables/secrets rather than committed credentials.
