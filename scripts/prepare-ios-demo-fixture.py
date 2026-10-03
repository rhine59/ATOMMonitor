#!/usr/bin/env python3
"""Capture a deterministic, station-only demo fixture from the live ATOM service."""
from __future__ import annotations
import argparse, json, os, pathlib, tempfile, urllib.request
from collections import Counter

DEFAULT_URL = "https://granvillehouse.synology.me:8445/api/v1/stations"
DEFAULT_OUTPUT = pathlib.Path(__file__).resolve().parents[1] / "ios/ATOMMonitor/Resources/demo-stations.json"

def fetch(url: str) -> list[dict]:
    request = urllib.request.Request(url, headers={"User-Agent": "ATOMMonitor-DemoFixture/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"station service returned HTTP {response.status}")
        value = json.load(response)
    if not isinstance(value, list):
        raise RuntimeError("station service did not return a JSON array")
    return value

def select_geographic(stations: list[dict], count: int) -> list[dict]:
    eligible = [
        station for station in stations
        if isinstance(station, dict)
        and isinstance(station.get("latitude"), (int, float))
        and isinstance(station.get("longitude"), (int, float))
        and station.get("id")
        and station.get("name")
    ]
    eligible.sort(key=lambda station: (
        float(station["latitude"]),
        float(station["longitude"]),
        str(station["id"]),
    ))
    if len(eligible) < count:
        raise RuntimeError(f"live service supplied only {len(eligible)} geolocated stations; {count} requested")
    if count == 1:
        return [eligible[len(eligible) // 2]]
    indexes = [round(index * (len(eligible) - 1) / (count - 1)) for index in range(count)]
    return [eligible[index] for index in indexes]

def write_atomic(path: pathlib.Path, stations: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(stations, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("ATOM_DEMO_STATIONS_URL", DEFAULT_URL))
    parser.add_argument("--count", type=int, default=int(os.getenv("ATOM_DEMO_STATION_COUNT", "100")))
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    if args.count < 1:
        raise SystemExit("--count must be at least 1")
    stations = select_geographic(fetch(args.url), args.count)
    write_atomic(args.output, stations)
    health = Counter(str(station.get("health") or "unknown") for station in stations)
    versions = Counter(str(station.get("pilotAwareVersion") or "Not reported") for station in stations)
    print(f"Captured {len(stations)} real geolocated stations -> {args.output}")
    print("Health:", ", ".join(f"{key}={value}" for key, value in sorted(health.items())))
    print("PilotAware versions:", ", ".join(f"{key}={value}" for key, value in sorted(versions.items())))

if __name__ == "__main__":
    main()
