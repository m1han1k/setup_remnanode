#!/usr/bin/env bash
#
# Интерактивная настройка протоколов Xray для Remnawave Node.
# Запуск: ./scripts/setup-protocols.sh  (нода должна быть уже запущена)
#
# Скрипт:
#  1. Спрашивает, какие протоколы нужны (и на каких портах).
#  2. Генерирует Reality-ключи и shortIds.
#  3. Открывает нужные порты в UFW.
#  4. Собирает готовый мультиконфиг Xray → xray-multiconfig.json.
#  5. Валидирует его реальным бинарником xray внутри контейнера remnanode.
#
# Полученный JSON нужно вставить в панели Remnawave (Config ноды).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
log_success() { echo -e "${GREEN}✓${NC}  $*"; }
log_error()   { echo -e "${RED}✗${NC}  $*" >&2; }
log_warning() { echo -e "${YELLOW}⚠${NC}  $*"; }

if [[ ! -f .env ]]; then
  log_error "Нет .env — сначала выполните ./setup-remnanode.sh"
  exit 1
fi

DOMAIN=$(grep -m1 -E '^DOMAIN=' .env | cut -d= -f2- | tr -d '\r' | sed 's/^"\(.*\)"$/\1/')
if [[ -z "$DOMAIN" ]]; then
  log_error "В .env не задан DOMAIN."
  exit 1
fi

SSL_CERT="/var/lib/remnawave/configs/xray/ssl/fullchain.pem"
SSL_KEY="/var/lib/remnawave/configs/xray/ssl/privkey.key"
CONFIG_OUT="$ROOT/xray-multiconfig.json"

# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

ask_yn() { # ask_yn "вопрос" "default(y|n)" -> 0=yes 1=no
  local prompt="$1" def="${2:-y}" reply hint
  if [[ "$def" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
  read -r -p "$prompt ($hint) " reply || true
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[YyДд] ]]
}

ask_port() { # ask_port "название" default -> echo port
  local name="$1" def="$2" p
  read -r -p "  Порт для $name (по умолчанию $def): " p || true
  p="${p:-$def}"
  if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )); then
    echo "$p"
  else
    log_warning "Некорректный порт, используется $def" >&2
    echo "$def"
  fi
}

gen_short_ids() { # 3 shortId по 8 байт hex
  printf '"%s","%s","%s"' \
    "$(openssl rand -hex 8)" "$(openssl rand -hex 8)" "$(openssl rand -hex 8)"
}

ufw_allow() { # ufw_allow 443 tcp "комментарий"
  local port="$1" proto="$2" comment="$3"
  if ! command -v ufw &>/dev/null; then return 0; fi
  local SUDO=""
  if sudo -n true &>/dev/null; then SUDO="sudo"; fi
  if $SUDO ufw status 2>/dev/null | grep -qE "^${port}/${proto}\s+ALLOW"; then
    log_success "UFW: ${port}/${proto} уже открыт"
  else
    if $SUDO ufw allow "${port}/${proto}" comment "$comment" &>/dev/null; then
      log_success "UFW: открыт ${port}/${proto} ($comment)"
    else
      log_warning "UFW: не удалось открыть ${port}/${proto} — откройте вручную"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Шаг 1. Выбор протоколов
# ---------------------------------------------------------------------------

echo ""
log_info "=== Настройка протоколов Xray для ноды $DOMAIN ==="
echo ""
echo "Доступные протоколы:"
echo "  1) VLESS XHTTP + TLS       (реальный сертификат, 443/tcp)"
echo "  2) Hysteria2               (реальный сертификат, 443/udp)"
echo "  3) VLESS TCP  + Reality    (4443/tcp)"
echo "  4) VLESS gRPC + Reality    (8443/tcp)"
echo "  5) Trojan WS  + TLS        (реальный сертификат, 2096/tcp)"
echo "  6) Bridge-inbound для каскада (VLESS TCP без TLS, 9999/tcp)"
echo ""

WANT_XHTTP=0; WANT_HY2=0; WANT_TCPR=0; WANT_GRPCR=0; WANT_TROJAN=0; WANT_BRIDGE=0
ask_yn "1) Настроить VLESS XHTTP + TLS?"        y && WANT_XHTTP=1
ask_yn "2) Настроить Hysteria2?"                y && WANT_HY2=1
ask_yn "3) Настроить VLESS TCP + Reality?"      y && WANT_TCPR=1
ask_yn "4) Настроить VLESS gRPC + Reality?"     y && WANT_GRPCR=1
ask_yn "5) Настроить Trojan WS + TLS?"          n && WANT_TROJAN=1
ask_yn "6) Настроить bridge-inbound (каскад)?"  n && WANT_BRIDGE=1

if (( WANT_XHTTP + WANT_HY2 + WANT_TCPR + WANT_GRPCR + WANT_TROJAN + WANT_BRIDGE == 0 )); then
  log_warning "Ничего не выбрано — выходим."
  exit 0
fi

echo ""
log_info "Порты (Enter — оставить по умолчанию):"
PORT_XHTTP=443;  (( WANT_XHTTP ))  && PORT_XHTTP=$(ask_port "VLESS XHTTP+TLS" 443)
PORT_HY2=443;    (( WANT_HY2 ))    && PORT_HY2=$(ask_port "Hysteria2 (udp)" 443)
PORT_TCPR=4443;  (( WANT_TCPR ))   && PORT_TCPR=$(ask_port "VLESS TCP+Reality" 4443)
PORT_GRPCR=8443; (( WANT_GRPCR ))  && PORT_GRPCR=$(ask_port "VLESS gRPC+Reality" 8443)
PORT_TROJAN=2096;(( WANT_TROJAN )) && PORT_TROJAN=$(ask_port "Trojan WS+TLS" 2096)
PORT_BRIDGE=9999;(( WANT_BRIDGE )) && PORT_BRIDGE=$(ask_port "Bridge-inbound" 9999)

# Один TCP-порт не могут делить два inbound'а
declare -A USED_TCP=()
for entry in "XHTTP:$PORT_XHTTP:$WANT_XHTTP" "TCPR:$PORT_TCPR:$WANT_TCPR" \
             "GRPCR:$PORT_GRPCR:$WANT_GRPCR" "TROJAN:$PORT_TROJAN:$WANT_TROJAN" \
             "BRIDGE:$PORT_BRIDGE:$WANT_BRIDGE"; do
  IFS=: read -r name port want <<< "$entry"
  (( want )) || continue
  if [[ -n "${USED_TCP[$port]:-}" ]]; then
    log_error "Конфликт: ${USED_TCP[$port]} и $name оба на ${port}/tcp. Запустите заново с разными портами."
    exit 1
  fi
  USED_TCP[$port]="$name"
done

# ---------------------------------------------------------------------------
# Шаг 2. Параметры Reality (общий keypair на все Reality-инбаунды)
# ---------------------------------------------------------------------------

REALITY_PRIV=""; REALITY_PUB=""; REALITY_SNI="www.github.com"
if (( WANT_TCPR || WANT_GRPCR )); then
  echo ""
  read -r -p "SNI/dest для Reality (по умолчанию www.github.com): " REALITY_SNI_IN || true
  REALITY_SNI="${REALITY_SNI_IN:-www.github.com}"

  log_info "Генерация Reality-ключей..."
  X25519_OUT=""
  if docker ps --format '{{.Names}}' | grep -qx remnanode; then
    X25519_OUT=$(docker exec remnanode xray x25519 2>/dev/null || true)
  fi
  if [[ -z "$X25519_OUT" ]]; then
    X25519_OUT=$(docker run --rm --entrypoint xray remnawave/node:latest x25519 2>/dev/null || true)
  fi
  # Форматы вывода: "Private key: .../Public key: ..." (старый)
  # или "PrivateKey: .../Password: ..." (новый)
  REALITY_PRIV=$(echo "$X25519_OUT" | grep -iE '^\s*Private ?[Kk]ey' | head -1 | sed 's/.*:\s*//' | tr -d ' \r')
  REALITY_PUB=$(echo "$X25519_OUT" | grep -iE '^\s*(Public ?[Kk]ey|Password)' | head -1 | sed 's/.*:\s*//' | tr -d ' \r')
  if [[ -z "$REALITY_PRIV" || -z "$REALITY_PUB" ]]; then
    log_error "Не удалось сгенерировать Reality-ключи (xray x25519). Вывод:"
    echo "$X25519_OUT"
    exit 1
  fi
  log_success "Reality-ключи сгенерированы (public key будет в итоговом отчёте)"
fi

TROJAN_WS_PATH="/ws"
if (( WANT_TROJAN )); then
  read -r -p "Путь WebSocket для Trojan (по умолчанию /ws): " TROJAN_WS_PATH_IN || true
  TROJAN_WS_PATH="${TROJAN_WS_PATH_IN:-/ws}"
fi

# ---------------------------------------------------------------------------
# Шаг 3. UFW
# ---------------------------------------------------------------------------

echo ""
log_info "=== Открытие портов в UFW ==="
(( WANT_XHTTP ))  && ufw_allow "$PORT_XHTTP"  tcp "vless-xhttp-tls"
(( WANT_HY2 ))    && ufw_allow "$PORT_HY2"    udp "hysteria2"
(( WANT_TCPR ))   && ufw_allow "$PORT_TCPR"   tcp "vless-tcp-reality"
(( WANT_GRPCR ))  && ufw_allow "$PORT_GRPCR"  tcp "vless-grpc-reality"
(( WANT_TROJAN )) && ufw_allow "$PORT_TROJAN" tcp "trojan-ws"
(( WANT_BRIDGE )) && ufw_allow "$PORT_BRIDGE" tcp "bridge-cascade"

# ---------------------------------------------------------------------------
# Шаг 4. Сборка конфига
# ---------------------------------------------------------------------------

echo ""
log_info "=== Сборка мультиконфига ==="

INBOUNDS=()
DIRECT_TAGS=()

if (( WANT_XHTTP )); then
  DIRECT_TAGS+=('"VLESS_XHTTP_TLS"')
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "VLESS_XHTTP_TLS",
      "port": $PORT_XHTTP,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "xhttpSettings": {
          "host": "www.github.com",
          "mode": "auto",
          "path": "/api/v2/stream/",
          "extra": {
            "noSSEHeader": true,
            "xPaddingBytes": "100-1000",
            "scMaxBufferedPosts": 50,
            "scMaxEachPostBytes": 2000000,
            "scStreamUpServerSecs": "120-240"
          }
        },
        "tlsSettings": {
          "serverName": "$DOMAIN",
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" }
          ]
        }
      }
    }
EOF
)")
fi

if (( WANT_GRPCR )); then
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "VLESS_GRPC_REALITY",
      "port": $PORT_GRPCR,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
      "streamSettings": {
        "network": "grpc",
        "security": "reality",
        "grpcSettings": { "serviceName": "grpc-stream", "multiMode": false },
        "realitySettings": {
          "dest": "$REALITY_SNI:443",
          "show": false,
          "xver": 0,
          "shortIds": [$(gen_short_ids)],
          "privateKey": "$REALITY_PRIV",
          "serverNames": ["$REALITY_SNI"]
        }
      }
    }
EOF
)")
fi

if (( WANT_TCPR )); then
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "VLESS_TCP_REALITY",
      "port": $PORT_TCPR,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "$REALITY_SNI:443",
          "show": false,
          "xver": 0,
          "shortIds": [$(gen_short_ids)],
          "privateKey": "$REALITY_PRIV",
          "serverNames": ["$REALITY_SNI"]
        }
      }
    }
EOF
)")
fi

if (( WANT_HY2 )); then
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "HYSTERIA2_IN",
      "port": $PORT_HY2,
      "listen": "0.0.0.0",
      "protocol": "hysteria",
      "settings": { "version": 2, "users": [] },
      "streamSettings": {
        "network": "hysteria",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h3"],
          "certificates": [
            { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" }
          ]
        },
        "hysteriaSettings": {
          "version": 2,
          "udpIdleTimeout": 60,
          "masquerade": {
            "type": "", "dir": "", "url": "", "rewriteHost": false,
            "insecure": false, "content": "", "headers": {}, "statusCode": 0
          }
        }
      }
    }
EOF
)")
fi

if (( WANT_TROJAN )); then
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "TROJAN_WS_TLS",
      "port": $PORT_TROJAN,
      "listen": "0.0.0.0",
      "protocol": "trojan",
      "settings": { "clients": [] },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": { "path": "$TROJAN_WS_PATH", "headers": {} },
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "minVersion": "1.2",
          "certificates": [
            { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" }
          ]
        }
      }
    }
EOF
)")
fi

if (( WANT_BRIDGE )); then
  DIRECT_TAGS+=('"BRIDGE_DE_IN_MULT"')
  INBOUNDS+=("$(cat <<EOF
    {
      "tag": "BRIDGE_DE_IN_MULT",
      "port": $PORT_BRIDGE,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
      "streamSettings": { "network": "tcp" }
    }
EOF
)")
fi

# Склейка inbound'ов через запятую
INBOUNDS_JSON=$(printf '%s,\n' "${INBOUNDS[@]}")
INBOUNDS_JSON="${INBOUNDS_JSON%,}"

# Правило DIRECT только если есть кому его назначить
DIRECT_RULE=""
if (( ${#DIRECT_TAGS[@]} > 0 )); then
  TAGS_JOINED=$(IFS=,; echo "${DIRECT_TAGS[*]}")
  DIRECT_RULE=",
      {
        \"type\": \"field\",
        \"inboundTag\": [$TAGS_JOINED],
        \"outboundTag\": \"DIRECT\"
      }"
fi

cat > "$CONFIG_OUT" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
$INBOUNDS_JSON
  ],
  "outbounds": [
    { "tag": "DIRECT", "protocol": "freedom" },
    { "tag": "BLOCK", "protocol": "blackhole" }
  ],
  "routing": {
    "rules": [
      { "ip": ["geoip:private"], "type": "field", "outboundTag": "BLOCK" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "BLOCK" },
      { "type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "BLOCK" }$DIRECT_RULE
    ],
    "domainStrategy": "IPOnDemand"
  }
}
EOF

log_success "Конфиг записан: $CONFIG_OUT"

# ---------------------------------------------------------------------------
# Шаг 5. Валидация конфига реальным xray в контейнере
# ---------------------------------------------------------------------------

echo ""
log_info "=== Валидация конфига (xray -test в контейнере) ==="
if docker ps --format '{{.Names}}' | grep -qx remnanode; then
  docker cp "$CONFIG_OUT" remnanode:/tmp/xray-test-config.json
  if docker exec remnanode xray -test -c /tmp/xray-test-config.json; then
    log_success "Configuration OK"
  else
    log_error "xray -test нашёл ошибку в конфиге — не вставляйте его в панель, проверьте вывод выше."
    docker exec remnanode rm -f /tmp/xray-test-config.json || true
    exit 1
  fi
  docker exec remnanode rm -f /tmp/xray-test-config.json || true
else
  log_warning "Контейнер remnanode не запущен — пропускаю валидацию."
fi

# ---------------------------------------------------------------------------
# Шаг 6. Итог
# ---------------------------------------------------------------------------

echo ""
echo -e "${GREEN}=== Готово! ===${NC}"
echo ""
echo -e "${BLUE}Настроенные протоколы:${NC}"
(( WANT_XHTTP ))  && echo "  • VLESS XHTTP + TLS      → ${PORT_XHTTP}/tcp  (SNI: $DOMAIN)"
(( WANT_HY2 ))    && echo "  • Hysteria2              → ${PORT_HY2}/udp  (SNI: $DOMAIN)"
(( WANT_TCPR ))   && echo "  • VLESS TCP + Reality    → ${PORT_TCPR}/tcp  (SNI: $REALITY_SNI)"
(( WANT_GRPCR ))  && echo "  • VLESS gRPC + Reality   → ${PORT_GRPCR}/tcp  (SNI: $REALITY_SNI, serviceName: grpc-stream)"
(( WANT_TROJAN )) && echo "  • Trojan WS + TLS        → ${PORT_TROJAN}/tcp  (path: $TROJAN_WS_PATH)"
(( WANT_BRIDGE )) && echo "  • Bridge (каскад)        → ${PORT_BRIDGE}/tcp"
if [[ -n "$REALITY_PUB" ]]; then
  echo ""
  echo -e "${BLUE}Reality public key (для клиентов / хостов в панели):${NC}"
  echo "  $REALITY_PUB"
fi
echo ""
echo -e "${YELLOW}Что дальше:${NC}"
echo "  1. Откройте панель Remnawave → Config ноды."
echo "  2. Вставьте туда содержимое файла:"
echo "       $CONFIG_OUT"
echo "  3. Сохраните — панель перезапустит Xray на ноде с новым конфигом."
echo "  4. Проверьте логи: docker compose logs -f remnanode"
echo ""
