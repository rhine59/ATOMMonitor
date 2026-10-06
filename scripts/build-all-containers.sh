#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
echo '=== ATOM Monitor container build/start suite ==='
echo "UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Git: $(git -C "$ROOT" rev-parse --short HEAD)"
for script in build-postgres.sh build-api.sh build-collector.sh build-admin.sh build-nginx.sh; do
  printf '\n===== %s =====\n' "$script"
  sh "$ROOT/scripts/$script"
done
printf '\n--- Admin pairing route/exchange/revocation acceptance ---\n'
sh "$ROOT/scripts/admin-pairing-acceptance.sh"
printf '\n--- repository-prefixed container names ---\n'
sh "$ROOT/scripts/check-container-names.sh"
printf '\n--- final Compose state ---\n'
cd "$ROOT/server"
sudo docker compose -p atommonitor ps
printf '\nALL CONTAINER BUILDS/START CHECKS: PASS\n'
