#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"

ids="$(sudo docker compose -p atommonitor ps -q)"
[ -n "$ids" ] || { echo 'FAIL: no ATOMMonitor containers found'; exit 1; }
failed=0
for id in $ids; do
  name="$(sudo docker inspect "$id" --format '{{.Name}}' | sed 's#^/##')"
  case "$name" in
    atommonitor-*) echo "PASS: $name" ;;
    *) echo "FAIL: $name does not start with atommonitor-" >&2; failed=1 ;;
  esac
done
[ "$failed" -eq 0 ] || exit 1
echo 'CONTAINER NAME CHECK: PASS'
