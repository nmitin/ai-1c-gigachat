# Интеграция 1С с GigaChat API

## Что это?

REST API сервис (FastAPI) для интеграции GigaChat с любой конфигурацией 1С.

**Преимущества:**
- Простая интеграция через HTTP — 1С отправляет текст, получает ответ
- Автоматическое обновление токена через cron
- Можно добавить кеширование, логирование, очереди запросов

## Архитектура

```
┌─────────────┐     HTTP/JSON     ┌──────────────┐     ┌─────────────┐
│     1С      │ ───────────────►  │   FastAPI    │ ──► │  GigaChat   │
│             │ ◄───────────────  │  (Python)    │     │    API      │
└─────────────┘                   └──────────────┘     └─────────────┘
                                        ↑
                                  cron обновляет
                                  токен каждые 20 мин
```

## Требования

- Python 3.11+
- Учётная запись GigaChat API (developers.sber.ru)
- Linux сервер с cron

## Быстрый старт

```bash
# 1. Клонировать и настроить
cd ~/ai-1c
cp .env.example .env
# Заполнить GIGACHAT_CLIENT_ID и GIGACHAT_CLIENT_SECRET

# 2. Установка зависимостей
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Получить первый токен
./scripts/update_token.sh

# 4. Настроить cron (каждые 20 минут)
crontab -e
# Добавить: */20 * * * * /path/to/scripts/update_token.sh

# 5. Запуск сервера
python api_server.py
```

API будет доступен на http://localhost:8000

## Структура проекта

```
├── api_server.py          # FastAPI сервер
├── gigachat_client.py     # Модуль работы с GigaChat API
├── scripts/
│   └── update_token.sh    # Скрипт обновления токена (для cron)
├── .env                   # Конфигурация (создать из .env.example)
├── .env.tokens            # Токен доступа (создаётся автоматически)
└── requirements.txt       # Зависимости Python
```

## API Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка состояния сервера |
| POST | /analyze/text | Анализ текста |
| GET | /docs | Swagger документация |

## Пример запроса

```bash
curl -X POST "http://localhost:8000/analyze/text" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Договор поставки №127. Сумма 2 450 000 руб. Срок 30 дней.",
    "system_prompt": "Извлеки ключевые данные: стороны, сумму, сроки",
    "return_format": "html"
  }'
```

## Интеграция с 1С

См. папку `1c_forms/` с готовым кодом Общей формы.

## Получение API ключей GigaChat

1. Зарегистрироваться на https://developers.sber.ru
2. Создать проект и получить Client ID / Client Secret
3. Выбрать тариф (есть бесплатный с лимитами)
