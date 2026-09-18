#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/lib/acceptance.sh"
FAIL=0
cd "$ROOT/server"
HOST_PORT=8088
printf '%s\n' '=== Current-stack service/API acceptance ==='

http_code(){ curl -sS -o /tmp/atommonitor-http-$$ -w '%{http_code}' "$@" || true; }
check_get(){
  label="$1"; url="$2"; expected="$3"
  code="$(http_code "$url")"
  [ "$code" = "$expected" ] && pass "$label -> HTTP $expected" || fail "$label expected HTTP $expected, got $code"
}
cleanup(){ rm -f /tmp/atommonitor-http-$$; }
trap cleanup EXIT INT TERM

sudo docker compose config --quiet && pass "Compose validates" || fail "Compose validation"
sudo docker compose up -d --scale atom-api=2 >/dev/null

check_get "LB /health" "http://localhost:$HOST_PORT/health" 200
ready="$(curl -fsS "http://localhost:$HOST_PORT/ready" 2>/dev/null || true)"
printf '%s' "$ready" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='ready' and d.get('database')=='ok' and d.get('databaseBackend')=='postgresql'" 2>/dev/null && pass "LB /ready -> HTTP 200, PostgreSQL ready" || fail "LB /ready body/status"
check_get "LB /api/v1/stations" "http://localhost:$HOST_PORT/api/v1/stations" 200

station_id="$(curl -fsS "http://localhost:$HOST_PORT/api/v1/stations" | python3 -c 'import json,sys; a=json.load(sys.stdin); print(a[0]["id"] if a else "")' 2>/dev/null || true)"
if [ -n "$station_id" ]; then
  check_get "LB station detail" "http://localhost:$HOST_PORT/api/v1/stations/$station_id" 200
else
  fail "No confirmed station available for detail endpoint"
fi
check_get "LB missing station detail" "http://localhost:$HOST_PORT/api/v1/stations/__ATOM_ACCEPTANCE_NOT_FOUND__" 404

feedback_code="$(http_code -X POST -H 'Content-Type: application/json' -d '{"rating":0}' "http://localhost:$HOST_PORT/api/v1/feedback")"
[ "$feedback_code" = 400 ] && pass "LB invalid feedback -> HTTP 400 without sending mail" || fail "Invalid feedback expected HTTP 400, got $feedback_code"

unauth_code="$(http_code -X POST -H 'Content-Type: application/json' -d '{}' "http://localhost:$HOST_PORT/api/v1/observations")"
[ "$unauth_code" = 401 ] && pass "LB unauthenticated observation -> HTTP 401" || fail "Unauthenticated observation expected HTTP 401, got $unauth_code"

pg_count="$(sudo docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM stations WHERE isPilotAware=1;"' | tr -d '[:space:]')"
api_count="$(curl -fsS "http://localhost:$HOST_PORT/api/v1/stations" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
[ "$pg_count" = "$api_count" ] && pass "PostgreSQL confirmed count matches station API ($api_count)" || fail "PostgreSQL/API count mismatch: $pg_count vs $api_count"

for id in $(sudo docker compose ps -q atom-api); do
  name="$(sudo docker inspect "$id" --format '{{.Name}}' | sed 's#^/##')"
  sudo docker exec "$id" python -c "import urllib.request; assert urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=5).status==200" >/dev/null 2>&1 && pass "$name direct /health -> HTTP 200" || fail "$name direct /health"
  sudo docker exec "$id" python -c "import json,urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/ready',timeout=5); d=json.load(r); assert r.status==200 and d.get('databaseBackend')=='postgresql' and d.get('database')=='ok'" >/dev/null 2>&1 && pass "$name direct /ready -> PostgreSQL ready" || fail "$name direct /ready"
  sudo docker exec "$id" python -c "import urllib.request; assert urllib.request.urlopen('http://127.0.0.1:8080/api/v1/stations',timeout=5).status==200" >/dev/null 2>&1 && pass "$name direct station API -> HTTP 200" || fail "$name direct station API"
done

baseline="$(sudo docker compose logs atom-lb 2>/dev/null | grep -c 'POST /api/v1/observations HTTP/1.1" 202' || true)"
i=0
while [ "$i" -lt 90 ]; do
  now="$(sudo docker compose logs atom-lb 2>/dev/null | grep -c 'POST /api/v1/observations HTTP/1.1" 202' || true)"
  [ "$now" -gt "$baseline" ] && break
  i=$((i+5)); sleep 5
done
[ "$now" -gt "$baseline" ] && pass "Collector -> Nginx -> API live observation -> HTTP 202" || fail "No new collector HTTP 202 observed within 90 seconds"

finish "SERVICE/API"
