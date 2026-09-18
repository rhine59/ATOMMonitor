#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/lib/acceptance.sh"
FAIL=0
DB="$ROOT/server/data/atommonitor.sqlite3"
TMP="${TMPDIR:-/tmp}/atommonitor-phase2-$$"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/backups" "$TMP/restore"
printf '%s\n' '=== Phase 2 acceptance: SQLite backup/recovery regression ==='
[ -f "$DB" ] && pass "Preserved SQLite rollback database exists" || { fail "Preserved SQLite rollback database missing"; finish "PHASE 2"; exit 1; }
python3 - "$DB" <<'PY' && pass "SQLite integrity and stations table" || fail "SQLite integrity/stations table"
import sqlite3,sys
p=sys.argv[1]
with sqlite3.connect("file:"+p+"?mode=ro",uri=True) as c:
    assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
    assert c.execute("SELECT COUNT(*) FROM stations").fetchone()[0] > 0
PY
python3 "$ROOT/scripts/atom-db-backup.py" backup --db "$DB" --backup-dir "$TMP/backups" --keep 2 >/dev/null && pass "Controlled backup succeeds" || fail "Controlled backup"
sleep 1
python3 "$ROOT/scripts/atom-db-backup.py" backup --db "$DB" --backup-dir "$TMP/backups" --keep 2 >/dev/null
sleep 1
python3 "$ROOT/scripts/atom-db-backup.py" backup --db "$DB" --backup-dir "$TMP/backups" --keep 2 >/dev/null
count="$(find "$TMP/backups" -name 'atommonitor-*.sqlite3' -type f | wc -l | tr -d ' ')"
[ "$count" -eq 2 ] && pass "Retention keeps newest two backups" || fail "Retention expected 2 backups, found $count"
python3 "$ROOT/scripts/atom-db-backup.py" verify --backup-dir "$TMP/backups" >/dev/null && pass "Checksum/integrity controlled restore verification" || fail "Backup verification"
latest="$(find "$TMP/backups" -name 'atommonitor-*.sqlite3' -type f | sort | tail -1)"
python3 "$ROOT/scripts/atom-db-backup.py" restore "$latest" --target "$TMP/restore/atommonitor.sqlite3" >/dev/null && pass "Explicit restore to controlled copy" || fail "Controlled restore"
finish "PHASE 2"
