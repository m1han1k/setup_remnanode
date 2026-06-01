# ssl-remnanode — Remnawave Node + nginx + certbot

Автоматизированная настройка ноды Remnawave с SSL-сертификатом Let's Encrypt.

Документация: [Remnawave Node](https://docs.rw/docs/install/remnawave-node)

<details>
<summary><h2>Предварительные настройки сервера перед использованием скрипта</h2></summary>
  
Подготовка сервера перед запуском setup-remnanode.sh

Требования к серверу

- ОС: Ubuntu 22.04 LTS (рекомендуется) или Debian 11/12
- RAM: минимум 1 ГБ
- Порт 80 и 443 должны быть свободны и доступны из интернета

---
Шаг 1 — Обновить систему

sudo apt update && sudo apt upgrade -y

---
Шаг 2 — Установить Docker

### Установить зависимости
sudo apt install -y ca-certificates curl gnupg lsb-release git

### Добавить официальный репозиторий Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

### Установить Docker и плагин Compose
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

### Запустить и включить в автозагрузку
sudo systemctl start docker
sudo systemctl enable docker

### Проверка
docker --version
docker compose version

---
Шаг 3 — Создать пользователя admin (если его нет)

### Проверить, существует ли пользователь
id admin 2>/dev/null || sudo useradd -m -s /bin/bash admin

### Добавить в группу docker (чтобы работать без sudo для docker)
sudo usermod -aG docker admin

### Установить пароль (запомните его)
sudo passwd admin

---
Шаг 4 — Настроить sudo без пароля для пользователя admin

Это нужно, чтобы скрипт мог настроить UFW:

echo "admin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin

---
Шаг 5 — Настроить DNS (делается у регистратора домена)

Перед запуском скрипта домен уже должен указывать на IP этого сервера, иначе Let's Encrypt не выдаст сертификат.

1. Узнайте IP сервера: curl -4 ifconfig.me
2. У регистратора домена создайте A-запись:
  - Имя: node1.example.com (ваш поддомен)
  - Тип: A
  - Значение: IP сервера
  - TTL: 300 (или минимальный)
3. Подождите 5–15 минут и проверьте: nslookup node1.example.com — должен вернуть IP сервера

---
Шаг 6 — Скопировать репозиторий на сервер

sudo mkdir -p /opt/remnanode
sudo git clone https://github.com/m1han1k/setup_remnanode.git /opt/remnanode
sudo chown -R admin:admin /opt/remnanode
chmod +x /opt/remnanode/setup-remnanode.sh
chmod +x /opt/remnanode/scripts/*.sh

---
Шаг 7 — Подготовить данные для скрипта

Перед запуском скрипта нужно иметь под рукой:

| Параметр | Где взять |
|---|---|
| Домен | Тот, что настроили в шаге 5 |
| Email | Любой — придут уведомления об истечении сертификата |
| SECRET_KEY | В панели Remnawave → Ноды → «Добавить ноду» → скопировать SECRET_KEY |
| IP панели | IP сервера, где установлена панель Remnawave (нужен для ограничения порта 8080) |

---
Шаг 8 — Запустить скрипт

### Переключиться на пользователя admin (если вы root)
su - admin

cd /opt/remnanode
./setup-remnanode.sh

---
Что делает скрипт автоматически (не нужно делать вручную)

- Настраивает UFW: открывает порты 22, 80, 443, 8080
- Получает SSL сертификат от Let's Encrypt
- Создаёт .env с конфигурацией
- Запускает Docker-контейнер ноды
- Настраивает автоматическое обновление сертификата (cron)

### Важно: порт 8080 скрипт открывает для всех. Если нужно ограничить только IP панели — после запуска скрипта выполните:
- sudo ufw delete allow 8080/tcp
- sudo ufw allow from <IP_ПАНЕЛИ> to any port 8080 proto tcp
- sudo ufw reload
</details>

## 🚀 Быстрый старт

**Новая нода? Используйте автоматизированный скрипт:**

```bash
# На сервере (пользователь admin):
cd /opt/remnanode
./setup-remnanode.sh
```

Скрипт автоматически:
- ✅ Запросит конфигурацию (DOMAIN, EMAIL, SECRET_KEY)
- ✅ Настроит UFW файрвол
- ✅ Получит SSL-сертификат от Let's Encrypt
- ✅ Запустит контейнер ноды
- ✅ Настроит автоматическое продление сертификата

**📖 [Полная инструкция по развертыванию](DEPLOYMENT.md)**

**⚠️ Проблемы с установкой Docker?**
- [DOCKER-INSTALL.md](DOCKER-INSTALL.md) — два варианта установки
- [DOCKER-TROUBLESHOOT.md](DOCKER-TROUBLESHOOT.md) — решение проблем
- Быстрое решение: `sudo bash docker-fix.sh`

---

## Порты

| Порт | Роль |
|------|------|
| **22** | SSH (управление сервером) |
| **80** | HTTP — только для Let's Encrypt HTTP-01 валидации |
| **443** | HTTPS — Xray слушает 443 для REALITY / WS+TLS |
| **8080** | API ноды для панели (открыть только IP панели!) |

Сертификаты в контейнере: `/var/lib/remnawave/configs/xray/ssl/` — см. [XRay SSL cert for Node](https://docs.rw/docs/install/remnawave-node#xray-ssl-cert-for-node). Для **REALITY** сертификаты не требуются.

---

## 📋 Для ручной настройки (опционально)

Если нужна ручная настройка без скрипта:

```bash
cd /opt/remnanode
cp .env.example .env && nano .env   # Задайте DOMAIN, EMAIL, NODE_PORT, SECRET_KEY
./scripts/issue-cert.sh
./scripts/up.sh
```

---

## 📅 Автоматическое продление сертификата

Скрипт автоматически добавляет Cron job:

```bash
# Выполняется 1-го числа каждого месяца в 04:00
0 4 1 * * /opt/remnanode/scripts/renew-cert.sh >> /var/log/ssl-remnanode-acme.log 2>&1
```

Проверить:
```bash
crontab -l | grep renew-cert
```

---

## 📁 Структура проекта

```
/opt/remnanode/
├── setup-remnanode.sh          # Главный скрипт настройки
├── .env                        # Конфигурация (создается скриптом)
├── .env.example                # Шаблон
├── docker-compose.yml          # Конфигурация контейнеров
├── README.md                   # Эта инструкция
├── DEPLOYMENT.md               # Подробное руководство
├── scripts/
│   ├── bootstrap.sh            # Инициализация .env
│   ├── issue-cert.sh           # Получение SSL-сертификата
│   ├── renew-cert.sh           # Продление сертификата (Cron)
│   └── up.sh                   # Запуск контейнера
├── nginx/
│   └── conf.d/00-acme.conf     # Конфиг для Let's Encrypt
├── certbot/                    # Данные certbot
└── letsencrypt/                # Сертификаты (создается скриптом)
```

---

## 🛠️ Полезные команды

```bash
# Логи контейнера
docker compose logs -f remnanode

# Статус
docker compose ps

# Остановка/перезапуск
docker compose down
docker compose restart remnanode

# Проверка сертификата
openssl x509 -in letsencrypt/live/<DOMAIN>/cert.pem -noout -dates
```

---

**Начните с [DEPLOYMENT.md](DEPLOYMENT.md) для полной инструкции!**
