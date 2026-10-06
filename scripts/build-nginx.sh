#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
echo '=== Pull/start Nginx load balancer ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
sudo docker compose -p atommonitor config --quiet
echo 'PASS: Compose validates'
sudo docker compose -p atommonitor pull atom-lb
echo 'PASS: Nginx image pulled'
sudo docker compose -p atommonitor up -d --force-recreate --scale atom-api=2 atom-lb
i=0
while [ "$i" -lt 90 ]; do
  state="$(sudo docker inspect atommonitor-lb --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  [ "$state" = healthy ] && break
  i=$((i+1)); sleep 1
done
[ "$state" = healthy ] || { echo "FAIL: Nginx health=$state"; exit 1; }
echo 'PASS: Nginx healthy'
sudo docker exec atommonitor-lb nginx -t >/dev/null 2>&1
echo 'PASS: Nginx configuration valid'
curl -fsS http://localhost:8088/health >/dev/null
echo 'PASS: /health through Nginx'
ready="$(curl -fsS http://localhost:8088/ready)"
printf '%s' "$ready" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='ready' and d.get('database')=='ok' and d.get('databaseBackend')=='postgresql'"
echo 'PASS: /ready through Nginx to PostgreSQL'
curl -fsS http://localhost:8088/api/v1/stations >/dev/null
echo 'PASS: station API through Nginx'
echo 'NGINX BUILD/START: PASS'
