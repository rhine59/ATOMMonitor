#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT/server"
HOST_PORT=8088
FAIL=0
pass(){ printf 'PASS: %s\n' "$1"; }
fail(){ printf 'FAIL: %s\n' "$1" >&2; FAIL=1; }
wait_ready(){ i=0; while [ "$i" -lt 60 ]; do out="$(curl -fsS "http://localhost:$HOST_PORT/ready" 2>/dev/null || true)"; if printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('status')=='ready' and d.get('database')=='ok' and d.get('databaseBackend')=='postgresql'" 2>/dev/null; then return 0; fi; i=$((i+1)); sleep 1; done; return 1; }
station_200(){ [ "$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost:$HOST_PORT/api/v1/stations" || true)" = 200 ]; }
wait_posts(){ service="$1"; limit="$2"; i=0; while [ "$i" -lt "$limit" ]; do if sudo docker compose -p atommonitor logs --since=90s "$service" 2>/dev/null | grep -q 'POST /api/v1/observations HTTP/1.1" 202'; then return 0; fi; i=$((i+5)); sleep 5; done; return 1; }
cleanup(){ echo "--- cleanup: restoring two API replicas and load balancer ---"; sudo docker compose -p atommonitor up -d --scale atom-api=2 atom-api atom-lb >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
echo "=== Phase 4 acceptance ==="
sudo docker compose -p atommonitor config --quiet && pass "Compose validates" || fail "Compose validation"
sudo docker compose -p atommonitor up -d --scale atom-api=2 >/dev/null
wait_ready && pass "Baseline PostgreSQL readiness through Nginx" || fail "Baseline readiness"
station_200 && pass "Baseline station read HTTP 200" || fail "Baseline station read"
[ "$(sudo docker compose -p atommonitor ps -q atom-api | wc -l | tr -d ' ')" -eq 2 ] && pass "Two API replicas present" || fail "Expected two API replicas"
wait_posts atom-lb 90 && pass "Collector POST HTTP 202 visible in Nginx access log" || fail "Collector traffic through Nginx"
echo "--- fail replica 1 ---"
api_1="$(sudo docker compose -p atommonitor ps -q atom-api | sed -n '1p')"
api_2="$(sudo docker compose -p atommonitor ps -q atom-api | sed -n '2p')"
[ -n "$api_1" ] && [ -n "$api_2" ] || { fail "Could not resolve two API container IDs"; exit 1; }
sudo docker stop "$api_1" >/dev/null
wait_ready && station_200 && pass "Reads survive loss of replica 1" || fail "Reads after replica 1 loss"
wait_posts atom-lb 90 && pass "Collector writes survive loss of replica 1" || fail "Collector writes after replica 1 loss"
sudo docker start "$api_1" >/dev/null; sleep 5
wait_ready && pass "Replica 1 rejoins" || fail "Replica 1 rejoin"
echo "--- fail replica 2 ---"
sudo docker stop "$api_2" >/dev/null
wait_ready && station_200 && pass "Reads survive loss of replica 2" || fail "Reads after replica 2 loss"
wait_posts atom-lb 90 && pass "Collector writes survive loss of replica 2" || fail "Collector writes after replica 2 loss"
sudo docker start "$api_2" >/dev/null; sleep 5
wait_ready && pass "Replica 2 rejoins" || fail "Replica 2 rejoin"
echo "--- recreate API service ---"
sudo docker compose -p atommonitor up -d --scale atom-api=2 --force-recreate atom-api >/dev/null
wait_ready && station_200 && pass "API recreation recovers through Nginx" || fail "API recreation recovery"
wait_posts atom-lb 90 && pass "Collector writes recover after API recreation" || fail "Collector writes after API recreation"
echo "--- recreate load balancer ---"
sudo docker compose -p atommonitor up -d --no-deps --force-recreate atom-lb >/dev/null
wait_ready && station_200 && pass "Load balancer recreation recovers" || fail "Load balancer recreation recovery"
wait_posts atom-lb 90 && pass "Collector writes visible after LB recreation" || fail "Collector writes after LB recreation"
echo "--- unauthenticated ingestion security ---"
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "http://localhost:$HOST_PORT/api/v1/observations" || true)"
[ "$code" = 401 ] && pass "Unauthenticated ingestion rejected HTTP 401" || fail "Unauthenticated ingestion expected 401, got $code"
echo "--- final state ---"
sudo docker compose -p atommonitor ps
wait_ready && station_200 && pass "Final service readiness/read path" || fail "Final service state"
if [ "$FAIL" -ne 0 ]; then echo "PHASE 4 ACCEPTANCE: FAIL"; exit 1; fi
echo "PHASE 4 ACCEPTANCE: PASS"
