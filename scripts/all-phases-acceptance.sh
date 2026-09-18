#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for phase in 1 2 3 4; do
  printf '\n===== RUNNING PHASE %s =====\n' "$phase"
  sh "$ROOT/scripts/phase${phase}-acceptance.sh"
done
printf '\n===== RUNNING CURRENT SERVICE/API MATRIX =====\n'
sh "$ROOT/scripts/service-api-acceptance.sh"
printf '\nALL IMPLEMENTED PHASE AND SERVICE/API ACCEPTANCE TESTS: PASS\n'
