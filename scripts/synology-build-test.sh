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
echo "API host port: $HOST_PORT"

echo '\n--- Persistent storage ---'
mkdir -p "$ROOT/server/data"
echo "SQLite data directory: $ROOT/server/data"

echo '\n--- Python collector unit tests ---'
cd diagnostic
python3 -m unittest -v
cd ..

echo '\n--- Docker rebuild ---'
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d

echo '\n--- Container state ---'
sudo docker compose ps

echo '\n--- API health ---'
i=0
until curl -fsS "http://localhost:${HOST_PORT}/health"; do
  i=$((i+1)); [ "$i" -ge 20 ] && { echo 'API did not become ready'; exit 1; }
  sleep 1
done
echo

echo '\n--- Station API sample/count ---'
HOST_PORT="$HOST_PORT" python3 - <<'PY'
import json, os, urllib.request
u=f"http://localhost:{os.environ['HOST_PORT']}/api/v1/stations"
with urllib.request.urlopen(u, timeout=10) as r: data=json.load(r)
print('station_count=',len(data))
for s in data[:10]:
    print(s.get('name'), s.get('health'), s.get('lastHeartbeat'), s.get('latitude'), s.get('longitude'))
PY

echo '\n--- Recent container logs ---'
sudo docker compose logs --tail=50 atom-api ogn-station-probe

echo '\nPASS: unit tests, Docker build/start and local REST API checks completed.'
