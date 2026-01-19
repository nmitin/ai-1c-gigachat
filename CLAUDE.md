# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

REST API сервис (FastAPI) для интеграции GigaChat с 1С. Токен обновляется автоматически через cron.

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

## Структура файлов

```
├── api_server.py          # FastAPI сервер (endpoint /analyze/text)
├── gigachat_client.py     # Клиент GigaChat API (чтение токена, запросы)
├── scripts/
│   └── update_token.sh    # Скрипт обновления токена (запускается cron)
├── .env                   # Credentials GigaChat
├── .env.tokens            # Текущий access token (создаётся скриптом)
└── requirements.txt       # Зависимости Python
```

## Команды разработки

```bash
# Активация окружения
source venv/bin/activate

# Установка зависимостей
pip install -r requirements.txt

# Получение токена вручную
./scripts/update_token.sh

# Запуск сервера
python api_server.py

# Тест API
curl -X POST "http://localhost:8000/analyze/text" \
  -H "Content-Type: application/json" \
  -d '{"text": "Текст для анализа", "system_prompt": "Проанализируй"}'
```

## API Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка состояния и токена |
| POST | /analyze/text | Анализ текста через GigaChat |
| GET | /docs | Swagger документация |

## Особенности GigaChat API

- Токен живёт 30 минут → обновляем каждые 20 через cron
- Требуется `verify=False` — самоподписанный сертификат
- SCOPE: `GIGACHAT_API_PERS` (физлица) или `GIGACHAT_API_CORP` (юрлица)
- Модели: GigaChat (базовая), GigaChat-Pro, GigaChat-Max

## Рабочий пример

Полная реализация с дополнительными функциями (Streamlit UI, LLM Router, обработка файлов) находится в `/home/mnv/Y/giga/`.
