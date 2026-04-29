#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Нет .env"
  exit 1
fi

mkdir -p certbot/www

echo "Поднимаем nginx на :80 для webroot..."
docker compose --profile acme up -d nginx-acme

docker compose --profile cert run --rm certbot renew \
  --webroot -w /var/www/certbot

docker compose restart remnanode 2>/dev/null || docker compose up -d remnanode

echo "Готово."
