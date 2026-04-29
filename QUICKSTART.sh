#!/bin/bash
# QUICKSTART.sh — Быстрое развертывание на новом сервере
# 
# Запуск:
#   cd /opt/remnanode
#   chmod +x QUICKSTART.sh
#   ./QUICKSTART.sh
#
# Или просто прочитайте инструкции ниже и выполните их вручную.

set -euo pipefail

echo "================================================"
echo "  Remnanode-SSL: БЫСТРЫЙ СТАРТ"
echo "================================================"
echo ""

# Проверка текущей директории
if [[ ! -f "docker-compose.yml" ]] || [[ ! -f "setup-remnanode.sh" ]]; then
  echo "❌ Ошибка: запустите этот скрипт из директории Remnanode-SSL"
  echo "   cd /opt/remnanode && ./QUICKSTART.sh"
  exit 1
fi

echo "✓ Вы находитесь в правильной директории: $(pwd)"
echo ""

# Проверка Docker
if ! command -v docker &> /dev/null; then
  echo "❌ Docker не установлен."
  echo ""
  echo "Установите Docker:"
  echo "  sudo apt update && sudo apt install -y docker.io docker-compose-plugin"
  exit 1
fi

if ! command -v docker compose &> /dev/null; then
  echo "❌ Docker Compose не установлен."
  echo ""
  echo "Установите Docker Compose:"
  echo "  sudo apt install -y docker-compose-plugin"
  exit 1
fi

echo "✓ Docker найден"
echo "✓ Docker Compose найден"
echo ""

# Выданы права на выполнение скриптам
chmod +x setup-remnanode.sh scripts/*.sh

echo "✓ Права на выполнение выданы"
echo ""

echo "================================================"
echo "  Готово к запуску основного скрипта"
echo "================================================"
echo ""
echo "Выполните:"
echo "  ./setup-remnanode.sh"
echo ""
echo "Скрипт запросит:"
echo "  1. DOMAIN — домен ноды (должен указывать на этот IP)"
echo "  2. EMAIL — для уведомлений Let's Encrypt"
echo "  3. SECRET_KEY — из панели remnawave"
echo "  4. NODE_PORT — порт API (по умолчанию 8080)"
echo ""
echo "После этого все настроится автоматически!"
echo ""
