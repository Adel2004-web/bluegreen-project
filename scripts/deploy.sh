#!/usr/bin/env bash
# Usage: ./scripts/deploy.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git rev-parse --short HEAD 2>/dev/null || date +%s)}"
ACTIVE="$(cat .active_color 2>/dev/null || echo none)"
[ "$ACTIVE" = "blue" ] && TARGET=green || TARGET=blue
VAR="$(echo "$TARGET" | tr a-z A-Z)_VERSION"
touch .env

set_var() { grep -v "^$1=" .env > .env.tmp || true; echo "$1=$2" >> .env.tmp; mv .env.tmp .env; }

echo ">> Actif: $ACTIVE | Cible: $TARGET | Version: $VERSION"
set_var "$VAR" "$VERSION"

echo ">> Build + démarrage de app-$TARGET (l'ancienne version continue de servir)"
docker compose up -d --build --no-deps "app-$TARGET"

echo ">> Attente du healthcheck..."
STATUS=starting
for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Health.Status}}' "app-$TARGET" 2>/dev/null || echo starting)"
  [ "$STATUS" = "healthy" ] && break
  sleep 2
done
if [ "$STATUS" != "healthy" ]; then
  echo "!! app-$TARGET n'est pas healthy: abandon, le trafic reste sur $ACTIVE"
  docker compose logs --tail 30 "app-$TARGET" || true
  docker compose stop "app-$TARGET"
  exit 1
fi

echo ">> Smoke test"
docker exec "app-$TARGET" wget -qO- http://localhost:3000/health | grep -q "\"version\":\"$VERSION\"" \
  || { echo "!! Smoke test KO"; docker compose stop "app-$TARGET"; exit 1; }

echo ">> Démarrage de nginx / monitoring (si absents)"
docker compose up -d --no-deps nginx prometheus grafana

echo ">> Bascule du trafic vers $TARGET"
"$(dirname "$0")/switch.sh" "$TARGET"
echo "$TARGET" > .active_color
[ "$ACTIVE" != "none" ] && echo "$ACTIVE" > .previous_color

echo ">> OK: $TARGET (v$VERSION) reçoit le trafic. $ACTIVE reste dispo pour rollback."
