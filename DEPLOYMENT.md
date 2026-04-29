# 📦 Развертывание Remnanode-SSL на новом сервере

Полная инструкция по автоматической настройке ноды Remnawave с SSL-сертификатом Let's Encrypt.

---

## 🚀 Быстрый старт (тл;др)

```bash
# На локальном компьютере:
git clone <ваш-репозиторий> remnanode
cd remnanode

# На сервере (по SSH от пользователя admin):
cd /opt/remnanode
./setup-remnanode.sh
```

---

## 📋 Требования

### На сервере до запуска скрипта:

- ✅ **OS**: Ubuntu 22.04 LTS (или Debian 11/12)
- ✅ **Docker**: установлен и работает (`docker --version`)
- ✅ **Docker Compose**: plugin mode (`docker compose version`)
- ✅ **Пользователь**: создан пользователь `admin` с домом `/home/admin`
- ✅ **SSH доступ**: возможен ssh от `admin` без пароля (или с паролем)
- ✅ **Домен**: DNS A/AAAA запись уже указывает на IP этого сервера
- ✅ **Порт 80**: доступен для HTTP-01 валидации Let's Encrypt
- ✅ **Sudo**: пользователь `admin` может использовать `sudo` (опционально для UFW)

### Что будет установлено скриптом:

- ✅ Директория `/opt/remnanode` с проектом
- ✅ Файл `.env` с конфигурацией (DOMAIN, EMAIL, SECRET_KEY)
- ✅ SSL-сертификат от Let's Encrypt в `letsencrypt/live/`
- ✅ Контейнер `remnanode` (Remnawave Node)
- ✅ UFW Firewall с правилами для портов 22, 80, 443, NODE_PORT
- ✅ Cron job для автоматического продления сертификата

---

## 🔧 Шаг за шагом

### **Шаг 1: Предварительная подготовка на сервере**

Это выполняется **один раз** перед запуском скрипта (можно от root или sudo):

#### **Вариант B: Если Вариант A не сработал (standalone docker-compose)**

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка зависимостей и docker.io
sudo apt install -y docker.io curl wget git nano jq

# Установка standalone docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Создание symlink для команды "docker compose" (без дефиса)
sudo ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose-new || true

# Запуск Docker сервиса
sudo systemctl start docker
sudo systemctl enable docker

# Проверка
docker --version
docker-compose --version

# Для совместимости с командой "docker compose" (с пробелом):
# Отредактируйте ~/.bashrc или используйте alias:
echo "alias 'docker compose'='/usr/local/bin/docker-compose'" >> ~/.bashrc
source ~/.bashrc
```

#### **Проверка успешной установки**

```bash
docker --version          # Должна вывести версию Docker
docker compose version    # Должна вывести версию Docker Compose
docker run hello-world    # Проверка, что Docker работает
```

⚠️ **Если Docker не запускается**: см. [DOCKER-TROUBLESHOOT.md](DOCKER-TROUBLESHOOT.md) или выполните:
```bash
sudo bash docker-fix.sh
```

### **Шаг 2: Создание пользователя `admin` (если еще не создан)**

```bash
# От root или sudo:
sudo useradd -m -s /bin/bash admin
sudo usermod -aG docker admin  # Добавить в группу docker

# Для удобства: настроить sudo без пароля для UFW (опционально)
sudo visudo
# Добавить строку:
# admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw
```

### **Шаг 3: Клонирование репозитория на сервер**

```bash
# От пользователя admin:
cd /home/admin
git clone <URL-ВАШ-РЕПОЗИТОРИЙ> remnanode
# или если уже скачали архив:
# unzip remnanode.zip && mv Remnanode-SSL remnanode

cd /home/admin/remnanode
chmod +x setup-remnanode.sh  # Выданы права на выполнение
```

### **Шаг 4: Подготовка директории в `/opt` (рекомендуется)**

```bash
# От root или sudo (опционально, для удобства):
sudo mkdir -p /opt
sudo cp -r /home/admin/remnanode /opt/remnanode
sudo chown -R admin:admin /opt/remnanode
sudo chmod +x /opt/remnanode/setup-remnanode.sh
```

### **Шаг 5: Запуск скрипта настройки**

```bash
# От пользователя admin:
cd /opt/remnanode
./setup-remnanode.sh
```

**Скрипт интерактивно запросит:**

1. **DOMAIN** — домен ноды (например, `node1.example.com`)
   - Должен быть валидный домен
   - Должен указывать на IP этого сервера (проверьте DNS)
   
2. **EMAIL** — email для Let's Encrypt уведомлений (например, `admin@example.com`)
   - На этот email придут уведомления о продлении сертификата
   
3. **SECRET_KEY** — base64-строка из панели remnawave
   - Получить: в панели remnawave → добавить новую ноду → скопировать SECRET_KEY
   - Длинная base64-строка (обычно 2000+ символов)
   
4. **NODE_PORT** — порт API ноды (по умолчанию 8080)
   - Порт, через который панель управляется ноде
   - По умолчанию 8080 (нажмите Enter для пропуска)

### **Шаг 6: Проверка результата**

После успешного выполнения скрипта:

```bash
# Проверить статус контейнера
docker compose ps

# Должен вывести: remnanode → STATUS: Up X seconds

# Проверить логи
docker compose logs -f remnanode

# Должны быть сообщения: "Connected to panel", "Node is ready", и т.д.

# Проверить сертификат
ls -la letsencrypt/live/<DOMAIN>/
# Должны быть: cert.pem, privkey.key, chain.pem, fullchain.pem

# Проверить UFW (если используется)
sudo ufw status
# Должны быть открыты: 22/tcp, 80/tcp, 443/tcp, 8080/tcp

# Проверить Cron
crontab -l | grep renew-cert
```

---

## 📝 Что делает скрипт

### Фаза 1: Проверки
- Проверка Docker и Docker Compose
- Проверка наличия скриптов в `scripts/`

### Фаза 2: Интерактивный ввод
- Запрос DOMAIN, EMAIL, SECRET_KEY, NODE_PORT
- Валидация входных данных

### Фаза 3: Создание .env
- Генерация файла конфигурации `.env`
- Установка правильных разрешений (600, только читаемый владельцем)

### Фаза 4: Настройка UFW (опционально)
- Открытие портов 22, 80, 443, 8080
- Включение Firewall (если не включен)

### Фаза 5: Получение SSL-сертификата
- Запуск HTTP-01 валидации через Let's Encrypt
- Сохранение сертификата в `letsencrypt/live/<DOMAIN>/`
- Создание symlink `privkey.key` → `privkey.pem` (требование Xray)

### Фаза 6: Запуск контейнера
- Запуск контейнера `remnanode` с SECRET_KEY из .env
- Проверка, что контейнер работает

### Фаза 7: Настройка Cron
- Добавление записи в crontab для автоматического продления сертификата
- 1-го числа каждого месяца в 04:00 выполнится `scripts/renew-cert.sh`

---

## 🔐 Безопасность

### Файл .env
- Создается с правами `600` (только владелец может читать)
- Содержит SECRET_KEY — **не делитесь этим файлом**
- Находится в `.gitignore` репозитория

### Порты
- **22 (SSH)** — управление сервером
- **80 (HTTP)** — только для Let's Encrypt валидации
- **443 (HTTPS)** — Xray (REALITY / WS+TLS)
- **8080 (API)** — панель управляет ноде (открыть только для IP панели!)

### Сертификаты
- Хранятся в `letsencrypt/live/<DOMAIN>/` (на сервере, **не в репозитории**)
- Автоматически продлеваются ежемесячно
- Валидны 90 дней (Let's Encrypt)

---

## 📊 Struktura projekta po завершении скрипта

```
/opt/remnanode/
├── setup-remnanode.sh          ← Скрипт настройки
├── .env                        ← Конфиг (DOMAIN, EMAIL, SECRET_KEY, NODE_PORT)
├── .env.example                ← Шаблон
├── .gitignore
├── docker-compose.yml          ← Конфигурация контейнеров
├── README.md
├── DEPLOYMENT.md               ← Эта инструкция
│
├── scripts/
│   ├── bootstrap.sh            ← Инициализация .env
│   ├── issue-cert.sh           ← Получение сертификата
│   ├── renew-cert.sh           ← Продление сертификата (cron)
│   └── up.sh                   ← Запуск контейнера
│
├── nginx/
│   └── conf.d/
│       └── 00-acme.conf        ← Конфиг для Let's Encrypt HTTP-01
│
├── certbot/
│   └── www/                    ← Webroot для certbot (challenge токены)
│
├── letsencrypt/                ← Сертификаты (создается скриптом)
│   ├── live/<DOMAIN>/
│   │   ├── cert.pem            ← Сертификат
│   │   ├── privkey.pem         ← Приватный ключ
│   │   ├── privkey.key         ← Symlink на privkey.pem (для Xray)
│   │   ├── chain.pem           ← Цепочка CA
│   │   └── fullchain.pem       ← cert + chain
│   ├── archive/                ← Архив версий
│   └── renewal/                ← Конфиги продления
│
└── docker/                     ← Другие зависимости
```

---

## 🐛 Troubleshooting

### Проблема: "DNS запись не указывает на сервер"
**Решение:**
```bash
# Проверить DNS:
nslookup node1.example.com
dig node1.example.com

# Должен вернуть IP этого сервера
```

### Проблема: "Не удалось получить сертификат"
**Решение:**
```bash
# Проверить, что порт 80 доступен:
sudo netstat -tlnp | grep :80

# Если занят другим приложением, остановите его или измените порт в docker-compose.yml

# Попробовать еще раз:
cd /opt/remnanode
./scripts/issue-cert.sh
```

### Проблема: "Контейнер не запускается"
**Решение:**
```bash
# Проверить логи:
docker compose logs remnanode

# Проверить, что достаточно ресурсов:
docker ps -a

# Перезапустить:
docker compose restart remnanode

# Если не помогает:
docker compose down
docker compose up -d remnanode
```

### Проблема: "SECRET_KEY неверный"
**Решение:**
```bash
# Проверить в .env:
cat .env | grep SECRET_KEY

# Если неверный — отредактировать вручную:
nano .env

# Сохранить (Ctrl+O, Enter, Ctrl+X)

# Перезапустить контейнер:
docker compose down remnanode
docker compose up -d remnanode
```

### Проблема: "Сертификат скоро истечет"
**Решение:**
```bash
# Скрипт должен автоматически продлить 1-го числа в 04:00

# Если нужно вручную продлить прямо сейчас:
./scripts/renew-cert.sh

# Проверить логи продления:
tail -f /var/log/ssl-remnanode-acme.log
```

---

## 📞 Полезные команды

```bash
# Логи контейнера (последние 50 строк, live)
docker compose logs -f --tail 50 remnanode

# Статус контейнера
docker compose ps

# Остановка ноды
docker compose down

# Перезапуск ноды
docker compose restart remnanode

# Вход в контейнер (для отладки)
docker exec -it remnanode /bin/sh

# Проверка сертификата
openssl x509 -in letsencrypt/live/<DOMAIN>/cert.pem -text -noout

# Проверка, когда истечет сертификат
openssl x509 -in letsencrypt/live/<DOMAIN>/cert.pem -noout -dates

# Просмотр конфигурации
cat .env

# Редактирование конфигурации (если нужно изменить)
nano .env
# После сохранения: docker compose restart remnanode
```

---

## 🎯 Следующие шаги после развертывания

1. **Подключение к панели remnawave:**
   - В панели управления → Ноды → Добавить новую ноду
   - Использовать `SECRET_KEY` из скрипта
   - Заполнить `DOMAIN` и `NODE_PORT` (8080)
   - Проверить, что нода появилась с статусом **Online**

2. **Проверка функциональности:**
   - Попробуйте создать конфигурацию на панели
   - Проверьте, что клиенты могут подключиться
   - Мониторьте логи: `docker compose logs -f remnanode`

3. **Настройка мониторинга (опционально):**
   - Настроить алерты на email при ошибках
   - Мониторить использование ресурсов (CPU, RAM, диск)
   - Настроить логирование (Stack Overflow, ELK, etc.)

4. **Резервная копия (опционально):**
   - Сохранить `.env` файл в безопасном месте
   - Сохранить `letsencrypt/` директорию
   - Документировать конфигурацию

---

## 📄 Лицензия и поддержка

Для вопросов и поддержки см. основной [README.md](README.md).

---

**Успешного развертывания! 🎉**
