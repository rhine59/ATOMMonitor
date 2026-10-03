#!/bin/sh
set -eu

BASE_URL="${1:-http://127.0.0.1:8088}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

fail() { echo "FAIL: $*" >&2; exit 1; }

curl -fsS "$BASE_URL/api/v1/admin/pair" -o "$TMP_DIR/pair.html" ||
  fail "pairing page unavailable (run this on an allowed host/network)"

python3 - "$TMP_DIR/pair.html" "$TMP_DIR/code" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
patterns = [
    r'<code>\s*([A-F0-9]{8})\s*</code>',
]
for pattern in patterns:
    match = re.search(pattern, html, re.I | re.S)
    if match:
        open(sys.argv[2], "w", encoding="ascii").write(match.group(1).replace("-", "").upper())
        break
else:
    raise SystemExit("pairing code not found in page")
PY

CODE="$(cat "$TMP_DIR/code")"
curl -fsS -H 'Content-Type: application/json'   --data "{\"code\":\"$CODE\",\"deviceName\":\"admin-pairing-acceptance\"}"   "$BASE_URL/api/v1/admin/pair/exchange" -o "$TMP_DIR/exchange.json" ||
  fail "pairing exchange failed"

python3 - "$TMP_DIR/exchange.json" "$TMP_DIR/token" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
token = data.get("deviceToken") or data.get("token")
if not token:
    raise SystemExit("device token missing from exchange")
open(sys.argv[2], "w", encoding="utf-8").write(token)
PY
TOKEN="$(cat "$TMP_DIR/token")"

curl -fsS -H "Authorization: Bearer $TOKEN"   "$BASE_URL/api/v1/admin/summary" >/dev/null ||
  fail "paired credential could not read admin summary"

reuse_status="$(curl -sS -o /dev/null -w '%{http_code}'   -H 'Content-Type: application/json'   --data "{\"code\":\"$CODE\",\"deviceName\":\"reuse-check\"}"   "$BASE_URL/api/v1/admin/pair/exchange")"
[ "$reuse_status" = 401 ] || fail "one-time code reuse returned HTTP $reuse_status, expected 401"

curl -fsS -X DELETE -H "Authorization: Bearer $TOKEN"   "$BASE_URL/api/v1/admin/device" >/dev/null ||
  fail "device revocation failed"

revoked_status="$(curl -sS -o /dev/null -w '%{http_code}'   -H "Authorization: Bearer $TOKEN"   "$BASE_URL/api/v1/admin/summary")"
[ "$revoked_status" = 401 ] || fail "revoked credential returned HTTP $revoked_status, expected 401"

echo "PASS: one-time pairing, authenticated access and device revocation"
