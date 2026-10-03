#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
echo '=== Build/start restricted Admin control plane ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
grep -q '^ATOM_ADMIN_TOKEN=.' .env || { echo 'FAIL: ATOM_ADMIN_TOKEN missing'; exit 1; }
grep -q '^ATOM_ADMIN_CONTROL_TOKEN=.' .env || { echo 'FAIL: ATOM_ADMIN_CONTROL_TOKEN missing'; exit 1; }
sudo docker compose config --quiet
sudo docker compose build atom-admin-control atom-admin-monitor
sudo docker compose up -d --force-recreate atom-admin-control atom-admin-monitor atom-lb
i=0
while [ "$i" -lt 90 ]; do
  control="$(sudo docker inspect atommonitor-admin-control --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  monitor="$(sudo docker inspect atommonitor-admin-monitor --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  load_balancer="$(sudo docker inspect atommonitor-lb --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  [ "$control" = healthy ] && [ "$monitor" = healthy ] && [ "$load_balancer" = healthy ] && break
  i=$((i+1)); sleep 1
done
[ "$control" = healthy ] && [ "$monitor" = healthy ] && [ "$load_balancer" = healthy ] || { echo "FAIL: control=$control monitor=$monitor load-balancer=$load_balancer"; exit 1; }
published="$(sudo docker port atommonitor-admin-control 2>/dev/null || true)"
[ -z "$published" ] || { echo 'FAIL: admin control has a published host port'; exit 1; }
curl -fsS http://127.0.0.1:8088/api/v1/admin/pair >/dev/null || { echo 'FAIL: Admin pairing page unavailable through load balancer'; exit 1; }
echo 'PASS: Admin control, monitor and load balancer healthy; control has no published host port; pairing page reachable'
echo 'ADMIN BUILD/START: PASS'
