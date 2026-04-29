╔═══════════════════════════════════════════════════════════════════════════╗
║  🐳 РЕШЕНИЕ: Docker демон не запускается                                   ║
║  Error: "Cannot connect to the Docker daemon"                              ║
╚═══════════════════════════════════════════════════════════════════════════╝

Симптомы:
  ❌ sudo docker run hello-world
  Error: Cannot connect to the Docker daemon at unix:///var/run/docker.sock

  ❌ sudo systemctl start docker
  Job for docker.service failed because the control process exited with error code

═══════════════════════════════════════════════════════════════════════════════
  ДИАГНОСТИКА (выполните эти команды)
═══════════════════════════════════════════════════════════════════════════════

1️⃣  Проверить статус сервиса:
  sudo systemctl status docker.service

2️⃣  Посмотреть детальные логи ошибок:
  sudo journalctl -xeu docker.service | tail -50

3️⃣  Проверить, установлены ли все зависимости:
  dpkg -l | grep -E 'docker|containerd'

═══════════════════════════════════════════════════════════════════════════════
  РЕШЕНИЕ 1️⃣ : Переустановить Docker (самое эффективное)
═══════════════════════════════════════════════════════════════════════════════

Выполните эти команды по порядку:

  # Остановить Docker (если работает)
  sudo systemctl stop docker || true

  # Удалить Docker полностью
  sudo apt remove -y docker.io docker-ce docker-ce-cli containerd.io
  sudo apt autoremove -y
  sudo rm -rf /var/lib/docker /var/lib/containerd

  # Очистить репозитории
  sudo rm -f /etc/apt/sources.list.d/docker.list

  # Обновить список пакетов
  sudo apt update

  # ВАРИАНТ A: Установить из официального репозитория Docker
  sudo apt install -y curl wget git nano jq ca-certificates gnupg lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  # Или ВАРИАНТ B: Установить docker.io из стандартного репозитория
  sudo apt install -y docker.io curl wget git nano jq

  # Запустить Docker
  sudo systemctl start docker
  sudo systemctl enable docker

  # Проверить
  sudo docker run hello-world

═══════════════════════════════════════════════════════════════════════════════
  РЕШЕНИЕ 2️⃣ : Если переустановка не помогла
═══════════════════════════════════════════════════════════════════════════════

Проверьте, что containerd запущен:

  sudo systemctl status containerd

Если не работает, перезапустите:

  sudo systemctl restart containerd
  sudo systemctl restart docker

═══════════════════════════════════════════════════════════════════════════════
  РЕШЕНИЕ 3️⃣ : Проверить разрешения сокета Docker
═══════════════════════════════════════════════════════════════════════════════

  # Проверить существует ли сокет
  ls -la /var/run/docker.sock

  # Если файла нет, перезагрузитесь и пересоздайте Docker
  sudo reboot

  # После перезагрузки:
  sudo systemctl start docker
  ls -la /var/run/docker.sock

═══════════════════════════════════════════════════════════════════════════════
  РЕШЕНИЕ 4️⃣ : Если всё ещё не работает - перезагрузка сервера
═══════════════════════════════════════════════════════════════════════════════

Иногда помогает полная перезагрузка:

  sudo reboot

После перезагрузки:

  sudo systemctl status docker
  sudo docker run hello-world

═══════════════════════════════════════════════════════════════════════════════
  ПРОВЕРКА УСПЕШНОЙ УСТАНОВКИ
═══════════════════════════════════════════════════════════════════════════════

Если всё работает, вы должны увидеть:

  admin@vm:~$ sudo docker run hello-world

  Hello from Docker!
  This message shows that your installation appears to be working correctly.

═══════════════════════════════════════════════════════════════════════════════
  ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ В ГРУППУ DOCKER (опционально)
═══════════════════════════════════════════════════════════════════════════════

После успешной установки можете добавить себя в группу docker,
чтобы не писать sudo каждый раз:

  sudo usermod -aG docker admin
  newgrp docker

Проверьте:
  docker run hello-world  # Без sudo!

═══════════════════════════════════════════════════════════════════════════════
  ЕСЛИ НИЧЕГО НЕ ПОМОГАЕТ
═══════════════════════════════════════════════════════════════════════════════

Выполните эти команды и отправьте вывод:

  sudo systemctl status docker.service
  sudo journalctl -xeu docker.service | head -100
  docker --version
  docker-compose --version
  dpkg -l | grep -i docker
  dpkg -l | grep -i containerd
  cat /etc/os-release

═══════════════════════════════════════════════════════════════════════════════
