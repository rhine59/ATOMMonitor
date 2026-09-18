# Station Health Model

## Principle

Health is a **derived interpretation of observations**, not a claim that ATOM Monitor has authoritative control-plane knowledge of a station.

## Initial states

### Healthy

A recent receiver/status heartbeat has been observed and no implemented telemetry rule is in warning state.

### Warning

A heartbeat is present/recent but one or more conditions warrant attention, or the heartbeat is becoming stale. Candidate future rules include high temperature, excessive NTP error, implausible RF correction, memory pressure or stale reporting.

### No recent heartbeat

The station exists in the persistent registry but its last receiver/status observation is older than the configured threshold.

This does **not** necessarily prove that the physical installation is powered off or completely unavailable.

### Unknown

There is insufficient recent information to assign a meaningful state, for example a bootstrapped registry entry for which no compatible health packet has yet been observed.

## Thresholds

Do not freeze arbitrary time thresholds into v1 before measuring real ATOM reporting behaviour. Configuration should support values such as:

```text
healthy_max_age
warning_max_age
```

The values should be chosen after live observation of PWMalham and other representative stations.

## Telemetry

Canonical optional fields may include:

- `software_version`
- `platform`
- `cpu_load_percent`
- `memory_used_mb`
- `memory_total_mb`
- `temperature_c`
- `uptime_seconds`
- `ntp_offset_ms`
- `ntp_correction_ppm`
- `rf_frequency_correction_khz`
- `rf_correction_ppm`
- `rf_quality_db`

Exact names/units must be validated from the source protocol before implementation.

## UI rules

- Green: Healthy.
- Amber: Warning.
- Red: No recent heartbeat.
- Grey: Unknown.
- Always display last-observed time/age where known.
- Never display an absent numeric value as `0`.
- Prefer `Not reported` for absent telemetry.
- Explain derived warnings in the detail view, e.g. `Heartbeat overdue` rather than just showing amber.

## Future alerting

Notifications for favourite stations are a possible later feature. They should use hysteresis/debouncing to avoid repeated alerts during brief network interruptions and should distinguish server/upstream feed failure from an individual station ceasing to report.
\n\n## Checkpoint synchronization — 18 September 2026\n\nHealth semantics remain unchanged at this checkpoint. The server architecture underneath them is now PostgreSQL plus two stateless APIs behind Nginx, with full service/API acceptance passed. See `CHECKPOINT-2026-09-18.md`.\n