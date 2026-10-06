#!/bin/sh
set -eu

# ATOM Monitor Synology build/test runner.
# Run from repository root. Docker commands deliberately use sudo; Git does not.
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
HOST_PORT="8088"
cd "$ROOT/server"

echo '=== ATOM Monitor Synology build/test ==='
echo "UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Git: $(git -C "$ROOT" rev-parse --short HEAD)"
echo "API load-balancer host port: $HOST_PORT"

[ -f .env ] || { echo 'ERROR: server/.env is missing; copy .env.example and set local secrets first.'; exit 1; }

echo '\n--- Compose validation ---'
sudo docker compose -p atommonitor config --quiet

echo '\n--- Python collector unit tests ---'
cd diagnostic
python3 -m unittest -v
cd ..

echo '\n--- Docker rebuild ---'
sudo docker compose -p atommonitor down
sudo docker compose -p atommonitor build --no-cache
sudo docker compose -p atommonitor up -d --scale atom-api=2

echo '\n--- Container state ---'
sudo docker compose -p atommonitor ps

echo '\n--- PostgreSQL-backed readiness through Nginx ---'
i=0
until READY="$(curl -fsS "http://localhost:${HOST_PORT}/ready" 2>/dev/null)"; do
  i=$((i+1)); [ "$i" -ge 60 ] && { echo 'API did not become ready through Nginx'; exit 1; }
  sleep 1
done
printf '%s\n' "$READY"
printf '%s' "$READY" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='ready'; assert d.get('database')=='ok'; assert d.get('databaseBackend')=='postgresql'; print('readiness_backend=postgresql')"

echo '\n--- Replicated API state ---'
replica_count="$(sudo docker compose -p atommonitor ps -q atom-api | wc -l | tr -d ' ')"
echo "api_replicas=$replica_count"
[ "$replica_count" -eq 2 ] || { echo 'ERROR: expected two API replicas'; exit 1; }

echo '\n--- Station API sample/count ---'
HOST_PORT="$HOST_PORT" python3 - <<'PY'
import json, os, urllib.request
u=f"http://localhost:{os.environ['HOST_PORT']}/api/v1/stations"
with urllib.request.urlopen(u, timeout=10) as r: data=json.load(r)
print('station_count=',len(data))
for s in data[:10]:
    print(s.get('name'), s.get('health'), s.get('lastHeartbeat'), s.get('latitude'), s.get('longitude'))
PY

echo '\n--- Live collector ingestion ---'
i=0
while :; do
  accepted="$(sudo docker compose -p atommonitor logs --since=90s atom-api 2>/dev/null | grep -c 'POST /api/v1/observations HTTP/1.1\" 202' || true)"
  [ "$accepted" -gt 0 ] && break
  i=$((i+1)); [ "$i" -ge 12 ] && { echo 'ERROR: no HTTP 202 collector observation seen within test window'; exit 1; }
  sleep 5
done
echo "accepted_observation_posts=$accepted"

echo '\n--- Admin pairing route/exchange/revocation acceptance ---'
cd "$ROOT"
sh scripts/admin-pairing-acceptance.sh
cd "$ROOT/server"

echo '\n--- Recent container logs ---'
sudo docker compose -p atommonitor logs --tail=50 atom-lb atom-api ogn-station-probe postgres atom-admin-monitor atom-admin-control

echo '\nPASS: unit tests, Compose validation, PostgreSQL-backed rebuild/start, two API replicas, Nginx REST path, Admin pairing acceptance and live HTTP 202 ingestion completed.'
