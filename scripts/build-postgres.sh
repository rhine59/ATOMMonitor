#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
echo '=== Build/start PostgreSQL ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
sudo docker compose config --quiet
echo 'PASS: Compose validates'
sudo docker compose pull postgres
echo 'PASS: PostgreSQL image pulled'
sudo docker compose up -d postgres
i=0
while [ "$i" -lt 60 ]; do
  state="$(sudo docker inspect atommonitor-postgres --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  [ "$state" = healthy ] && break
  i=$((i+1)); sleep 1
done
[ "$state" = healthy ] || { echo "FAIL: PostgreSQL health=$state"; exit 1; }
echo 'PASS: PostgreSQL healthy'
mounts="$(sudo docker inspect atommonitor-postgres --format '{{range .Mounts}}{{println .Name "->" .Destination}}{{end}}')"
printf '%s\n' "$mounts" | grep -q 'atommonitor-postgres-data -> /var/lib/postgresql/data' || { echo 'FAIL: PostgreSQL named volume not mounted'; exit 1; }
echo 'PASS: PostgreSQL persistent volume mounted'
count="$(sudo docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM stations;"' | tr -d '[:space:]')"
case "$count" in ''|*[!0-9]*) echo "FAIL: invalid station count: $count"; exit 1;; esac
echo "PASS: PostgreSQL query station_rows=$count"
echo 'POSTGRESQL BUILD/START: PASS'
