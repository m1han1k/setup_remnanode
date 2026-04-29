# ssl-remnanode — Remnawave Node + nginx + certbot

Автоматизированная настройка ноды Remnawave с SSL-сертификатом Let's Encrypt.

Документация: [Remnawave Node](https://docs.rw/docs/install/remnawave-node)

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
