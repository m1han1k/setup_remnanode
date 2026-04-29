#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Нет .env — ./scripts/bootstrap.sh"
  exit 1
fi

DOMAIN=$(grep -m1 -E '^DOMAIN=' .env | cut -d= -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')
NODE_PORT=$(grep -m1 -E '^NODE_PORT=' .env | cut -d= -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')

if [[ -z "${DOMAIN}" ]]; then
  echo "В .env задайте DOMAIN."
  exit 1
fi

mkdir -p "letsencrypt/live/${DOMAIN}"

NODE_PORT="${NODE_PORT:-8080}"
echo "Запуск remnanode (host, NODE_PORT=${NODE_PORT}, Xray может использовать 443)..."
docker compose up -d remnanode

echo "Логи: docker compose logs -f -t remnanode"
