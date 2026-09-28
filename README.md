# Déploiement Blue-Green (Docker Compose + Nginx)

## Architecture
Client → **Nginx** → `app-blue` *ou* `app-green` (un seul reçoit le trafic).
Prometheus scrape les deux, Grafana affiche les métriques.

## Démarrage
```bash
./scripts/deploy.sh v1        # 1er déploiement → blue
curl localhost:8080           # {"version":"v1","color":"blue"}
./scripts/deploy.sh v2        # build green, healthcheck, smoke test, bascule
curl localhost:8080           # {"version":"v2","color":"green"}
./scripts/rollback.sh         # retour instantané sur blue (v1)
```

## Fonctionnement de `deploy.sh`
1. Détermine la couleur inactive (cible).
2. Build et démarre uniquement la cible (l'ancienne continue de servir).
3. Attend le healthcheck Docker + smoke test (version attendue).
4. Réécrit `nginx/conf.d/upstream.conf`, `nginx -t`, puis `nginx -s reload` (sans coupure).
5. Garde l'ancienne version en marche pour rollback. En cas d'échec, le trafic ne bouge pas.

## CI/CD (bonus)
`.github/workflows/deploy.yml` : à chaque push sur `main`, test de l'image puis SSH sur le serveur → `git pull` + `deploy.sh <sha>`.
Secrets GitHub à créer : `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`.
Sur le serveur : Docker + Compose, dépôt cloné dans `~/bluegreen`.

## Monitoring (bonus)
- Prometheus : http://localhost:9090 (ex: `up`, `app_info`, `rate(http_request_duration_seconds_count[1m])`)
- Grafana : http://localhost:3001 (admin/admin, datasource Prometheus préprovisionnée)
- `app_info{color,version}` indique quelle version tourne sur quelle couleur.
