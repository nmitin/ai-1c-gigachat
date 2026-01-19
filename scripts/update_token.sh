#!/bin/bash

# Скрипт обновления токена GigaChat
# Запускать через cron каждые 20 минут:
# */20 * * * * /path/to/scripts/update_token.sh >> /path/to/logs/token.log 2>&1

set -e

# Получаем директории
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_DIR"

# Загружаем переменные окружения
if [ ! -f .env ]; then
    echo "$(date): Ошибка - файл .env не найден"
    exit 1
fi

source .env

# Проверяем наличие необходимых переменных
if [ -z "$GIGACHAT_CLIENT_ID" ] || [ -z "$GIGACHAT_CLIENT_SECRET" ]; then
    echo "$(date): Ошибка - не заданы GIGACHAT_CLIENT_ID или GIGACHAT_CLIENT_SECRET"
    exit 1
fi

# Значения по умолчанию
GIGACHAT_AUTH_URL=${GIGACHAT_AUTH_URL:-"https://ngw.devices.sberbank.ru:9443/api/v2/oauth"}
GIGACHAT_SCOPE=${GIGACHAT_SCOPE:-"GIGACHAT_API_PERS"}

# Проверяем наличие jq
if ! command -v jq &> /dev/null; then
    echo "$(date): Ошибка - требуется jq (sudo apt install jq)"
    exit 1
fi

# Получаем токен
RESPONSE=$(curl -s -k -X POST "$GIGACHAT_AUTH_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Accept: application/json" \
    -H "RqUID: $(uuidgen)" \
    -H "Authorization: Basic $(echo -n "$GIGACHAT_CLIENT_ID:$GIGACHAT_CLIENT_SECRET" | base64 -w 0)" \
    -d "scope=$GIGACHAT_SCOPE")

# Извлекаем токен
TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    # Сохраняем токен
    echo "GIGACHAT_ACCESS_TOKEN=$TOKEN" > .env.tokens
    echo "$(date): Токен успешно обновлён"
else
    echo "$(date): Ошибка получения токена"
    echo "Ответ API: $RESPONSE"
    exit 1
fi
