#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Создан .env — задайте DOMAIN, EMAIL, NODE_PORT (SECRET_KEY может быть в docker-compose.yml)."
  echo "Далее: ./scripts/issue-cert.sh && ./scripts/up.sh"
  exit 0
fi

echo ".env уже есть: $ROOT/.env"
