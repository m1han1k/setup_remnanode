═══════════════════════════════════════════════════════════════════════════════
  🐳 УСТАНОВКА DOCKER И DOCKER COMPOSE
═══════════════════════════════════════════════════════════════════════════════

Если вы получаете ошибку:
  E: Unable to locate package docker-compose-plugin

Используйте один из двух вариантов ниже.

═══════════════════════════════════════════════════════════════════════════════
  ВАРИАНТ A: С официальным репозиторием Docker (РЕКОМЕНДУЕТСЯ)
═══════════════════════════════════════════════════════════════════════════════

Этот вариант дает вам самую свежую версию Docker:

  # 1. Обновление системы
  sudo apt update && sudo apt upgrade -y

  # 2. Установка зависимостей
  sudo apt install -y curl wget git nano jq ca-certificates gnupg lsb-release

  # 3. Добавление официального репозитория Docker
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # 4. Обновление списка пакетов
  sudo apt update

  # 5. Установка Docker Engine + Docker Compose plugin
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  # 6. Запуск и включение Docker в автозагрузку
  sudo systemctl start docker
  sudo systemctl enable docker

  # 7. Проверка установки
  docker --version
  docker compose version
  docker run hello-world

═══════════════════════════════════════════════════════════════════════════════
  ВАРИАНТ B: Standalone Docker Compose (если Вариант A не подошел)
═══════════════════════════════════════════════════════════════════════════════

Этот вариант использует docker.io из стандартного репозитория Ubuntu:

  # 1. Обновление системы
  sudo apt update && sudo apt upgrade -y

  # 2. Установка Docker + зависимости
  sudo apt install -y docker.io curl wget git nano jq

  # 3. Скачивание standalone Docker Compose
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  # 4. (Опционально) Создание alias для команды "docker compose"
  echo "alias 'docker compose'='/usr/local/bin/docker-compose'" >> ~/.bashrc
  source ~/.bashrc

  # 5. Запуск и включение Docker в автозагрузку
  sudo systemctl start docker
  sudo systemctl enable docker

  # 6. Проверка установки
  docker --version
  docker-compose --version
  docker run hello-world

═══════════════════════════════════════════════════════════════════════════════
  ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ В ГРУППУ DOCKER (опционально)
═══════════════════════════════════════════════════════════════════════════════

Чтобы использовать Docker без sudo, добавьте пользователя в группу docker:

  # Для текущего пользователя:
  sudo usermod -aG docker $USER

  # Или конкретного пользователя (например, admin):
  sudo usermod -aG docker admin

  # Новые разрешения вступят в силу при следующей сессии:
  # Либо выйдите и войдите заново, либо:
  newgrp docker

  # Проверка:
  docker ps

═══════════════════════════════════════════════════════════════════════════════
  ПРОВЕРКА УСТАНОВКИ
═══════════════════════════════════════════════════════════════════════════════

Выполните эти команды для проверки:

  docker --version
  # Должно вывести: Docker version XX.X.X, build XXXXXXX

  docker compose version  # (для Варианта A)
  # или
  docker-compose --version  # (для Варианта B)
  # Должно вывести: Docker Compose version XX.X.X

  docker run hello-world
  # Должно вывести: Hello from Docker! ...

═══════════════════════════════════════════════════════════════════════════════
  РЕШЕНИЕ ПРОБЛЕМ
═══════════════════════════════════════════════════════════════════════════════

Проблема: "Permission denied" при запуске docker
→ Добавьте пользователя в группу docker (см. выше)

Проблема: "docker: command not found"
→ Убедитесь, что Docker установлен: sudo apt list --installed | grep docker

Проблема: "docker compose: command not found" (Вариант A)
→ Проверьте: docker compose version
→ Если не работает, попробуйте Вариант B

Проблема: "docker-compose: command not found" (Вариант B)
→ Проверьте путь: ls -la /usr/local/bin/docker-compose
→ Если файл существует но не работает, переустановите его

═══════════════════════════════════════════════════════════════════════════════
  ПОСЛЕ УСТАНОВКИ DOCKER
═══════════════════════════════════════════════════════════════════════════════

Как только Docker установлен, можно приступать к развертыванию Remnanode:

  cd /opt/remnanode
  ./setup-remnanode.sh

═══════════════════════════════════════════════════════════════════════════════
