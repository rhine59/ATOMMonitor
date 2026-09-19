#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
echo '=== Build/start API replicas ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
sudo docker compose config --quiet
echo 'PASS: Compose validates'
sudo docker compose build atom-api
echo 'PASS: API image built'
sudo docker compose up -d --scale atom-api=2 atom-api
i=0
while [ "$i" -lt 90 ]; do
  ids="$(sudo docker compose ps -q atom-api)"
  count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  healthy=0
  for id in $ids; do
    state="$(sudo docker inspect "$id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
    [ "$state" = healthy ] && healthy=$((healthy+1))
  done
  [ "$count" -eq 2 ] && [ "$healthy" -eq 2 ] && break
  i=$((i+1)); sleep 1
done
[ "$count" -eq 2 ] && [ "$healthy" -eq 2 ] || { echo "FAIL: API replicas count=$count healthy=$healthy"; exit 1; }
echo 'PASS: two API replicas healthy'
for id in $ids; do
  name="$(sudo docker inspect "$id" --format '{{.Name}}' | sed 's#^/##')"
  sudo docker exec "$id" python -c "import urllib.request; assert urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=5).status==200" >/dev/null
  echo "PASS: $name /health"
  sudo docker exec "$id" python -c "import json,urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/ready',timeout=5); d=json.load(r); assert r.status==200 and d.get('database')=='ok' and d.get('databaseBackend')=='postgresql'" >/dev/null
  echo "PASS: $name /ready PostgreSQL"
  sudo docker exec "$id" python -c "import urllib.request; assert urllib.request.urlopen('http://127.0.0.1:8080/api/v1/stations',timeout=5).status==200" >/dev/null
  echo "PASS: $name station API"
done
echo 'API BUILD/START: PASS'
