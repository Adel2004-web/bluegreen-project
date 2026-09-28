#!/usr/bin/env bash
# Usage: ./scripts/switch.sh blue|green  — bascule Nginx sur la couleur donnée
set -euo pipefail
cd "$(dirname "$0")/.."
COLOR="$1"
CONF=nginx/conf.d/upstream.conf
cp "$CONF" "$CONF.bak" 2>/dev/null || true
echo "upstream app_backend { server app-$COLOR:3000; }" > "$CONF"
if docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload; then
  echo "Nginx -> $COLOR"
  rm -f "$CONF.bak"
else
  echo "!! Config invalide, restauration"
  mv "$CONF.bak" "$CONF"; exit 1
fi
