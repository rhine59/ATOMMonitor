#!/bin/sh
# Shared POSIX-sh helpers for ATOM Monitor acceptance runners.
pass(){ printf 'PASS: %s\n' "$1"; }
fail(){ printf 'FAIL: %s\n' "$1" >&2; FAIL=1; }
require_cmd(){ command -v "$1" >/dev/null 2>&1 && pass "$1 available" || fail "$1 unavailable"; }
finish(){ phase="$1"; if [ "${FAIL:-0}" -ne 0 ]; then printf '%s ACCEPTANCE: FAIL\n' "$phase"; return 1; fi; printf '%s ACCEPTANCE: PASS\n' "$phase"; }
