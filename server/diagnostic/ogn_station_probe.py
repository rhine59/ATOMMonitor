#!/usr/bin/env python3
"""ATOM Monitor OGN receiver-status diagnostic probe.

Connects read-only to OGN APRS-IS and emits ONLY receiver station position/status
messages. Aircraft messages are discarded before logging and are never persisted.

This is deliberately a diagnostic tool, not yet the production collector.
"""

from __future__ import annotations

import argparse
import json
import re
import socket
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Optional

DEFAULT_HOST = "aprs.glidernet.org"
DEFAULT_PORT = 14580

POSITION_RE = re.compile(
    r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:/"
    r"(?P<time>\d{6})h"
    r"(?P<latdeg>\d{2})(?P<latmin>\d{2}\.\d{2})(?P<lathem>[NS])"
    r"[A-Z]"
    r"(?P<londeg>\d{3})(?P<lonmin>\d{2}\.\d{2})(?P<lonhem>[EW])"
    r"[^/]*/A=(?P<altfeet>\d{6})"
)

STATUS_HEAD_RE = re.compile(
    r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:>"
    r"(?P<time>\d{6})h\s+(?P<body>.*)$"
)

CPU_RE = re.compile(r"\bCPU:(?P<v>[+-]?\d+(?:\.\d+)?)")
RAM_RE = re.compile(r"\bRAM:(?P<used>\d+(?:\.\d+)?)/(?P<total>\d+(?:\.\d+)?)MB")
NTP_RE = re.compile(r"\bNTP:(?P<offset>[+-]?\d+(?:\.\d+)?)ms/(?P<corr>[+-]?\d+(?:\.\d+)?)ppm")
TEMP_RE = re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)C\b")
RF_RE = re.compile(r"\bRF:(?P<body>\S+)")
RF_PPM_RE = re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)ppm")
RF_DB_RE = re.compile(r"/(?P<v>[+-]?\d+(?:\.\d+)?)dB")
VOLTAGE_RE = re.compile(r"\b(?P<v>\d+(?:\.\d+)?)V\b")
UPTIME_RE = re.compile(r"\b(?P<v>\d+)_m_(?:r_)?uptime\b")
TIME_SYNC_RE = re.compile(r"\b(time_synched|time_not_synched)\b")


@dataclass
class StationObservation:
    station: str
    kind: str
    received_at: str
    tocall: str
    packet_time_utc: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    altitude_m: Optional[float] = None
    software_version: Optional[str] = None
    cpu_load: Optional[float] = None
    ram_used_mb: Optional[float] = None
    ram_total_mb: Optional[float] = None
    ntp_offset_ms: Optional[float] = None
    ntp_correction_ppm: Optional[float] = None
    temperature_c: Optional[float] = None
    rf_correction_ppm: Optional[float] = None
    rf_quality_db: Optional[float] = None
    voltage_v: Optional[float] = None
    uptime_minutes: Optional[int] = None
    time_sync: Optional[str] = None


def aprs_coord(deg: str, minutes: str, hemisphere: str) -> float:
    value = float(deg) + float(minutes) / 60.0
    return -value if hemisphere in ("S", "W") else value


def packet_time(value: str) -> str:
    now = datetime.now(timezone.utc)
    hh, mm, ss = int(value[:2]), int(value[2:4]), int(value[4:6])
    return now.replace(hour=hh, minute=mm, second=ss, microsecond=0).isoformat()


def parse_receiver_packet(line: str) -> Optional[StationObservation]:
    received_at = datetime.now(timezone.utc).isoformat()

    m = POSITION_RE.match(line)
    if m:
        return StationObservation(
            station=m["name"], kind="position", received_at=received_at,
            tocall=m["tocall"], packet_time_utc=packet_time(m["time"]),
            latitude=aprs_coord(m["latdeg"], m["latmin"], m["lathem"]),
            longitude=aprs_coord(m["londeg"], m["lonmin"], m["lonhem"]),
            altitude_m=round(int(m["altfeet"]) * 0.3048, 1),
        )

    m = STATUS_HEAD_RE.match(line)
    if not m:
        return None

    body = m["body"]
    obs = StationObservation(
        station=m["name"], kind="status", received_at=received_at,
        tocall=m["tocall"], packet_time_utc=packet_time(m["time"]),
    )

    first = body.split(maxsplit=1)[0] if body else ""
    if first.startswith("v"):
        obs.software_version = first[1:]

    if x := CPU_RE.search(body): obs.cpu_load = float(x["v"])
    if x := RAM_RE.search(body):
        obs.ram_used_mb, obs.ram_total_mb = float(x["used"]), float(x["total"])
    if x := NTP_RE.search(body):
        obs.ntp_offset_ms, obs.ntp_correction_ppm = float(x["offset"]), float(x["corr"])
    if x := TEMP_RE.search(body): obs.temperature_c = float(x["v"])
    if x := VOLTAGE_RE.search(body): obs.voltage_v = float(x["v"])
    if x := UPTIME_RE.search(body): obs.uptime_minutes = int(x["v"])
    if x := TIME_SYNC_RE.search(body): obs.time_sync = x.group(1)

    if x := RF_RE.search(body):
        rf = x["body"]
        if p := RF_PPM_RE.search(rf): obs.rf_correction_ppm = float(p["v"])
        if q := RF_DB_RE.search(rf): obs.rf_quality_db = float(q["v"])

    return obs


def wanted(obs: StationObservation, station: Optional[str], prefix: Optional[str]) -> bool:
    if station and obs.station.casefold() != station.casefold(): return False
    if prefix and not obs.station.casefold().startswith(prefix.casefold()): return False
    return True


def run(args: argparse.Namespace) -> None:
    while True:
        try:
            print(f"Connecting to {args.host}:{args.port} …", file=sys.stderr, flush=True)
            with socket.create_connection((args.host, args.port), timeout=30) as sock:
                sock.settimeout(None)
                login = f"user {args.user} pass -1 vers ATOMMonitor 0.1"
                if args.filter:
                    login += f" filter {args.filter}"
                sock.sendall((login + "\n").encode("ascii"))
                print("Connected read-only; aircraft packets will be discarded.", file=sys.stderr, flush=True)

                with sock.makefile("r", encoding="utf-8", errors="replace", newline="\n") as stream:
                    for raw in stream:
                        line = raw.rstrip("\r\n")
                        if not line or line.startswith("#"):
                            continue
                        obs = parse_receiver_packet(line)
                        if obs is None or not wanted(obs, args.station, args.prefix):
                            continue
                        print(json.dumps(asdict(obs), separators=(",", ":")), flush=True)
        except KeyboardInterrupt:
            return
        except Exception as exc:
            print(f"OGN connection error: {exc}; retrying in {args.retry}s", file=sys.stderr, flush=True)
            time.sleep(args.retry)


def main() -> None:
    p = argparse.ArgumentParser(description="Observe OGN ground-station status only")
    p.add_argument("--host", default=DEFAULT_HOST)
    p.add_argument("--port", type=int, default=DEFAULT_PORT)
    p.add_argument("--user", default="ATOMMON")
    p.add_argument("--station", help="Exact receiver name, e.g. PWMalham")
    p.add_argument("--prefix", help="Receiver-name prefix, e.g. PW")
    p.add_argument("--filter", help="Optional APRS-IS server filter expression")
    p.add_argument("--retry", type=int, default=10)
    run(p.parse_args())


if __name__ == "__main__":
    main()
