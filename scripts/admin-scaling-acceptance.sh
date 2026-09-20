#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/lib/acceptance.sh"
FAIL=0
BASE_URL="${ATOM_ADMIN_BASE_URL:-http://127.0.0.1:8088}"
[ -n "${ATOM_ADMIN_TOKEN:-}" ] || { echo 'Set ATOM_ADMIN_TOKEN in the environment'; exit 1; }
tmp="$(mktemp -d)"; reader_pid=""
cleanup(){ [ -z "$reader_pid" ] || kill "$reader_pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM
admin_request(){
  method="$1"; path="$2"; data="${3:-}"
  { printf 'url = "%s%s"\n' "$BASE_URL" "$path"; printf 'header = "Authorization: Bearer %s"\n' "$ATOM_ADMIN_TOKEN"; printf 'header = "Content-Type: application/json"\n'; [ -z "$data" ] || { printf 'request = "%s"\n' "$method"; printf 'data = "%s"\n' "$data"; }; } | curl -fsS -K -
}
wait_count(){
  wanted="$1"; i=0
  while [ "$i" -lt 75 ]; do
    admin_request GET /api/v1/admin/summary >"$tmp/summary.json" || true
    if python3 - "$wanted" "$tmp/summary.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[2])); n=int(sys.argv[1]); r=d['apiReplicas']
assert r['running']==n and r['healthy']==n
for name in ('postgres','atom-lb','ogn-station-probe'):
    assert d['services'][name]['running']==1
PY
    then return 0; fi
    i=$((i+1)); sleep 1
  done
  return 1
}
(
  while :; do curl -fsS "$BASE_URL/api/v1/stations" >/dev/null || exit 1; sleep 1; done
) & reader_pid=$!
admin_request POST /api/v1/admin/api-scale '{\"replicas\":3,\"confirmed\":true}' >"$tmp/up.json" && pass '2 -> 3 request accepted' || fail '2 -> 3 request failed'
wait_count 3 && pass 'three API replicas healthy; singletons unchanged' || fail 'three-replica state not reached'
kill -0 "$reader_pid" 2>/dev/null && pass 'public station reads remained available' || fail 'public station read loop failed'
admin_request POST /api/v1/admin/api-scale '{\"replicas\":2,\"confirmed\":true}' >"$tmp/down.json" && pass '3 -> 2 request accepted' || fail '3 -> 2 request failed'
wait_count 2 && pass 'two API replicas healthy; singletons unchanged' || fail 'two-replica state not restored'
admin_request GET /api/v1/admin/events >"$tmp/events.json" && python3 - "$tmp/events.json" <<'PY' && pass 'successful scale events audited' || fail 'scale audit evidence missing'
import json,sys
events=json.load(open(sys.argv[1]))['events']
assert sum(e.get('type')=='api-scale' and e.get('result')=='succeeded' for e in events)>=2
PY
finish 'ADMIN SCALING'
