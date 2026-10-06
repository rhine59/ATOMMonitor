#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"

echo '=== Migrate Docker Compose project to atommonitor ==='
[ -f .env ] || { echo 'FAIL: server/.env missing'; exit 1; }
sudo docker compose -p atommonitor config --quiet

echo 'Preserving existing PostgreSQL, Admin audit and Admin device volumes.'
echo 'Stopping the legacy server Compose project (volumes are not removed).'
if sudo docker ps -a --filter label=com.docker.compose.project=server -q | grep -q .; then
  sudo docker compose -p server down --remove-orphans
else
  echo 'No legacy server project containers found.'
fi

echo 'Building and starting the atommonitor project.'
sudo docker compose -p atommonitor build --pull
sudo docker compose -p atommonitor up -d --force-recreate --scale atom-api=2

i=0
while [ "$i" -lt 120 ]; do
  ids="$(sudo docker compose -p atommonitor ps -q)"
  count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  healthy=0
  running=0
  bad_names=""
  for id in $ids; do
    state="$(sudo docker inspect "$id" --format '{{.State.Status}}')"
    health="$(sudo docker inspect "$id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}')"
    name="$(sudo docker inspect "$id" --format '{{.Name}}' | sed 's#^/##')"
    [ "$state" = running ] && running=$((running+1))
    [ "$health" = healthy ] && healthy=$((healthy+1))
    case "$name" in atommonitor-*) ;; *) bad_names="$bad_names $name";; esac
  done
  [ "$count" -eq 7 ] && [ "$running" -eq 7 ] && [ "$healthy" -eq 7 ] && [ -z "$bad_names" ] && break
  i=$((i+1)); sleep 1
done

[ "$count" -eq 7 ] || { echo "FAIL: expected 7 containers, found $count"; exit 1; }
[ "$running" -eq 7 ] || { echo "FAIL: expected 7 running containers, found $running"; exit 1; }
[ "$healthy" -eq 7 ] || { echo "FAIL: expected 7 healthy containers, found $healthy"; exit 1; }
[ -z "$bad_names" ] || { echo "FAIL: containers without atommonitor- prefix:$bad_names"; exit 1; }

curl -fsS http://127.0.0.1:8088/ready >/dev/null
sudo docker compose -p atommonitor ps
echo 'CONTAINER NAME MIGRATION: PASS'
