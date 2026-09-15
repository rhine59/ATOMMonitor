# Data Model

This is an architectural draft, not a final migration.

## Station registry

A persistent registry is essential because a station that stops transmitting must remain visible.

```text
stations
--------
id
station_name
latitude
longitude
altitude_m
first_seen_at
last_seen_at
last_heartbeat_at
current_health
current_health_reason
software_version
platform
source
created_at
updated_at
```

Coordinates should allow null during bootstrap if a known station cannot yet be located reliably.

## Latest health

Latest telemetry may either live on `stations` for fast map reads or in a separate one-to-one/latest-observation table. Keeping a canonical observation model is likely cleaner:

```text
station_latest_health
---------------------
station_id
observed_at
cpu_load_percent
memory_used_mb
memory_total_mb
temperature_c
uptime_seconds
ntp_offset_ms
ntp_correction_ppm
rf_frequency_correction_khz
rf_correction_ppm
rf_quality_db
raw_source_type
```

All telemetry fields are nullable.

## Health history

```text
station_health_history
----------------------
id
station_id
observed_at
health_state
cpu_load_percent
memory_used_mb
memory_total_mb
temperature_c
uptime_seconds
ntp_offset_ms
ntp_correction_ppm
rf_frequency_correction_khz
rf_correction_ppm
rf_quality_db
source
```

Retention/downsampling policy is to be decided after observing report frequency. Long-term storage may retain hourly aggregates while keeping higher-resolution recent data.

## Provider observations

If multiple sources are later combined, it may be useful to retain provider-specific observations separately from the canonical station state. That decision can wait until a second provider is actually implemented.

## Explicit exclusions

There is intentionally no aircraft, flight, track-point, aircraft-identity or aircraft-position table in this project.
