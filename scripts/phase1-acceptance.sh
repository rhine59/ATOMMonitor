#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/lib/acceptance.sh"
FAIL=0
printf '%s\n' '=== Phase 1 acceptance: base Synology/runtime boundary ==='
require_cmd git
require_cmd python3
require_cmd curl
require_cmd sudo
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && pass "Repository checkout valid" || fail "Repository checkout invalid"
[ -f "$ROOT/server/.env" ] && pass "Ignored server/.env exists" || fail "server/.env missing"
git -C "$ROOT" check-ignore -q server/.env && pass "server/.env is ignored by Git" || fail "server/.env is not ignored"
cd "$ROOT/server"
sudo docker compose -p atommonitor config --quiet && pass "Compose validates" || fail "Compose validation"
curl -fsS http://localhost:8088/ready >/dev/null 2>&1 && pass "Local readiness endpoint responds" || fail "Local readiness endpoint"
curl -fsS http://localhost:8088/api/v1/stations >/dev/null 2>&1 && pass "Local station API responds" || fail "Local station API"
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' http://localhost:8088/api/v1/observations || true)"
[ "$code" = 401 ] && pass "Unauthenticated ingestion rejected HTTP 401" || fail "Expected ingestion HTTP 401, got $code"
finish "PHASE 1"
