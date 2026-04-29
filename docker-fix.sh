#!/bin/bash
# docker-fix.sh — Быстрое восстановление Docker
# Выполните: bash docker-fix.sh

set -euo pipefail

echo "════════════════════════════════════════════════════════════════"
echo "  🐳 Docker Recovery Tool"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Проверка, что запущено от sudo
if [[ $EUID -ne 0 ]]; then
  echo "Этот скрипт нужно запустить от sudo:"
  echo "  sudo bash docker-fix.sh"
  exit 1
fi

echo "[1/5] Остановка Docker..."
systemctl stop docker || true
sleep 2

echo "[2/5] Удаление старой установки..."
apt remove -y docker.io docker-ce docker-ce-cli containerd.io || true
apt autoremove -y
rm -rf /var/lib/docker /var/lib/containerd
rm -f /etc/apt/sources.list.d/docker.list

echo "[3/5] Обновление репозиториев..."
apt update

echo "[4/5] Установка Docker из официального репозитория..."
apt install -y curl wget git nano jq ca-certificates gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[5/5] Запуск Docker..."
systemctl start docker
systemctl enable docker
sleep 3

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ Docker восстановлен!"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Проверка
if docker run hello-world > /dev/null 2>&1; then
  echo "✓ Проверка успешна: Hello from Docker!"
  echo ""
  echo "Команды для проверки:"
  echo "  docker --version"
  echo "  docker compose version"
  echo "  docker ps"
else
  echo "⚠ Проверка не прошла. Попробуйте:"
  echo "  sudo systemctl status docker"
  echo "  sudo journalctl -xeu docker.service"
fi
