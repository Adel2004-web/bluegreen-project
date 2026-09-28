#!/usr/bin/env bash
# Retour instantané à la version précédente (toujours en cours d'exécution)
set -euo pipefail
cd "$(dirname "$0")/.."
PREV="$(cat .previous_color)"; CUR="$(cat .active_color)"
[ "$(docker inspect -f '{{.State.Health.Status}}' "app-$PREV")" = healthy ] || { echo "app-$PREV non healthy"; exit 1; }
./scripts/switch.sh "$PREV"
echo "$PREV" > .active_color; echo "$CUR" > .previous_color
