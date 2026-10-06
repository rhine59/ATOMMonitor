#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/lib/acceptance.sh"
FAIL=0
cd "$ROOT/server"
printf '%s\n' '=== Phase 3 acceptance: PostgreSQL migration regression ==='
sudo docker compose -p atommonitor config --quiet && pass "Compose validates" || fail "Compose validation"
mounts="$(sudo docker inspect atommonitor-postgres --format '{{range .Mounts}}{{println .Name "->" .Destination}}{{end}}' 2>/dev/null || true)"
printf '%s\n' "$mounts" | grep -q 'atommonitor-postgres-data -> /var/lib/postgresql/data' && pass "PostgreSQL persistent volume mounted" || fail "PostgreSQL persistent volume mount"
ready="$(curl -fsS http://localhost:8088/ready 2>/dev/null || true)"
printf '%s' "$ready" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='ready' and d.get('database')=='ok' and d.get('databaseBackend')=='postgresql'" 2>/dev/null && pass "Readiness reports PostgreSQL database ok" || fail "PostgreSQL readiness"
before="$(sudo docker compose -p atommonitor exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM stations;"' | tr -d '[:space:]')"
case "$before" in ''|*[!0-9]*) fail "PostgreSQL station count invalid: $before";; *) [ "$before" -gt 0 ] && pass "PostgreSQL station registry populated" || fail "PostgreSQL station registry empty";; esac
curl -fsS http://localhost:8088/api/v1/stations >/dev/null 2>&1 && pass "Station reads through PostgreSQL stack" || fail "Station reads"
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' http://localhost:8088/api/v1/observations || true)"
[ "$code" = 401 ] && pass "Unauthenticated ingestion rejected HTTP 401" || fail "Expected HTTP 401, got $code"
[ -f data/atommonitor.sqlite3 ] && python3 - <<'PY' && pass "SQLite rollback boundary remains intact" || fail "SQLite rollback boundary"
import sqlite3
with sqlite3.connect("file:data/atommonitor.sqlite3?mode=ro",uri=True) as c:
    assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
PY
printf '%s\n' '--- PostgreSQL restart persistence check ---'
sudo docker compose -p atommonitor restart postgres >/dev/null
i=0
while [ "$i" -lt 60 ]; do
  state="$(sudo docker inspect atommonitor-postgres --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
  [ "$state" = healthy ] && break
  i=$((i+1)); sleep 1
done
sudo docker compose -p atommonitor up -d --scale atom-api=2 atom-api atom-lb ogn-station-probe >/dev/null
i=0
while [ "$i" -lt 60 ]; do curl -fsS http://localhost:8088/ready >/dev/null 2>&1 && break; i=$((i+1)); sleep 1; done
after="$(sudo docker compose -p atommonitor exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM stations;"' | tr -d '[:space:]')"
[ "$before" = "$after" ] && pass "PostgreSQL station count persists across restart ($after)" || fail "Station count changed across restart: $before -> $after"
curl -fsS http://localhost:8088/ready >/dev/null 2>&1 && pass "API recovers after PostgreSQL restart" || fail "API recovery after PostgreSQL restart"
finish "PHASE 3"
