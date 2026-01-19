#!/bin/bash
# Скрипт обновления токена GigaChat
# Запуск через cron каждые 20 минут:
# */20 * * * * /path/to/scripts/update_token.sh >> /var/log/gigachat_token.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Загружаем credentials из .env
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
else
    echo "[$(date)] ОШИБКА: Файл .env не найден в $PROJECT_DIR"
    exit 1
fi

# Проверяем обязательные переменные
if [ -z "$GIGACHAT_CLIENT_ID" ] || [ -z "$GIGACHAT_CLIENT_SECRET" ]; then
    echo "[$(date)] ОШИБКА: GIGACHAT_CLIENT_ID или GIGACHAT_CLIENT_SECRET не заданы"
    exit 1
fi

AUTH_URL="${GIGACHAT_AUTH_URL:-https://ngw.devices.sberbank.ru:9443/api/v2/oauth}"
SCOPE="${GIGACHAT_SCOPE:-GIGACHAT_API_PERS}"

# Формируем Basic Auth
CREDENTIALS=$(echo -n "${GIGACHAT_CLIENT_ID}:${GIGACHAT_CLIENT_SECRET}" | base64 -w 0)

echo "[$(date)] Запрос токена GigaChat..."

# Запрос токена
RESPONSE=$(curl -s -k -X POST "$AUTH_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Accept: application/json" \
    -H "RqUID: $(uuidgen)" \
    -H "Authorization: Basic $CREDENTIALS" \
    -d "scope=$SCOPE")

# Извлекаем токен
ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
EXPIRES_AT=$(echo "$RESPONSE" | grep -o '"expires_at":[0-9]*' | cut -d':' -f2)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "[$(date)] ОШИБКА: Не удалось получить токен"
    echo "[$(date)] Ответ API: $RESPONSE"
    exit 1
fi

# Сохраняем токен в .env.tokens
cat > "$PROJECT_DIR/.env.tokens" << EOF
# Автоматически обновляется скриптом update_token.sh
# Последнее обновление: $(date)
GIGACHAT_ACCESS_TOKEN=$ACCESS_TOKEN
GIGACHAT_TOKEN_EXPIRES_AT=$EXPIRES_AT
EOF

echo "[$(date)] Токен успешно обновлён (expires_at: $EXPIRES_AT)"
