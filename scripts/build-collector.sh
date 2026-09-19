#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
echo '=== Build/start OGN station collector ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
sudo docker compose config --quiet
echo 'PASS: Compose validates'
echo '--- collector unit tests ---'
(cd diagnostic && python3 -m unittest -v)
echo 'PASS: collector unit tests'
sudo docker compose build ogn-station-probe
echo 'PASS: collector image built'
sudo docker compose up -d --scale atom-api=2 ogn-station-probe
id="$(sudo docker compose ps -q ogn-station-probe)"
[ -n "$id" ] || { echo 'FAIL: collector container absent'; exit 1; }
state="$(sudo docker inspect "$id" --format '{{.State.Status}}')"
[ "$state" = running ] || { echo "FAIL: collector state=$state"; exit 1; }
echo 'PASS: collector running'
baseline="$(sudo docker compose logs atom-lb 2>/dev/null | grep -c 'POST /api/v1/observations HTTP/1.1\" 202' || true)"
i=0
while [ "$i" -lt 90 ]; do
  now="$(sudo docker compose logs atom-lb 2>/dev/null | grep -c 'POST /api/v1/observations HTTP/1.1\" 202' || true)"
  [ "$now" -gt "$baseline" ] && break
  i=$((i+5)); sleep 5
done
[ "$now" -gt "$baseline" ] || { echo 'FAIL: no new collector HTTP 202 through Nginx within 90 seconds'; exit 1; }
echo 'PASS: new collector observation -> Nginx -> API HTTP 202'
echo 'COLLECTOR BUILD/START: PASS'
