# Сценарий видео: Интеграция 1С с GigaChat API

## Метаданные
- **Название:** Подключаем GigaChat к 1С за 10 минут
- **Целевая аудитория:** 1С-разработчики
- **Длительность:** 10-15 минут
- **Формат:** Screencast с комментариями

---

## ПОДГОТОВКА К ЗАПИСИ

### Чеклист перед стартом

- [ ] OBS настроен (1920x1080, микрофон проверен)
- [ ] Терминал с крупным шрифтом (14-16pt)
- [ ] Чистая папка проекта создана
- [ ] Получены credentials GigaChat (Client ID, Secret)
- [ ] 1С готова (любая конфигурация)
- [ ] Браузер закрыт

### Создание чистой папки

```bash
mkdir -p ~/video-demo/ai-1c
cd ~/video-demo/ai-1c
```

---

## ЧАСТЬ 1: ВВЕДЕНИЕ (1-2 мин)

### Кадр 1.1: Титульный слайд

**Показать:** Рабочий стол или заставку

**Текст:**
> Привет! Сегодня покажу, как подключить GigaChat к 1С.
> Будем использовать Python как прослойку — это даёт гибкость и простоту.

### Кадр 1.2: Схема архитектуры

**Показать:** Схему (можно в draw.io или текстом)

```
┌─────────────┐     HTTP/JSON     ┌──────────────┐     ┌─────────────┐
│     1С      │ ───────────────►  │   FastAPI    │ ──► │  GigaChat   │
│             │ ◄───────────────  │  (Python)    │     │    API      │
└─────────────┘                   └──────────────┘     └─────────────┘
                                        ↑
                                  cron обновляет
                                  токен каждые 20 мин
```

**Текст:**
> Архитектура простая:
> - GigaChat API — нейросеть от Сбера
> - FastAPI — Python сервер, принимает запросы от 1С
> - Токен обновляется автоматически через cron
>
> Почему не напрямую из 1С? Потому что GigaChat требует OAuth-авторизацию
> и работу с сертификатами — проще вынести это в Python.

---

## ЧАСТЬ 2: НАСТРОЙКА ОКРУЖЕНИЯ (2 мин)

### Кадр 2.1: Создание проекта

```bash
cd ~/video-demo/ai-1c

# Создаём виртуальное окружение
python -m venv venv
source venv/bin/activate

# Устанавливаем зависимости
pip install fastapi uvicorn requests pydantic python-dotenv
```

**Текст:**
> Создаём Python проект. Нужно всего 5 библиотек.

### Кадр 2.2: Файл конфигурации

**Создать `.env`:**

```bash
# GigaChat API credentials
GIGACHAT_CLIENT_ID=ваш_client_id
GIGACHAT_CLIENT_SECRET=ваш_client_secret
GIGACHAT_SCOPE=GIGACHAT_API_PERS
GIGACHAT_AUTH_URL=https://ngw.devices.sberbank.ru:9443/api/v2/oauth
GIGACHAT_API_URL=https://gigachat.devices.sberbank.ru/api/v1

# Сервер
API_HOST=0.0.0.0
API_PORT=8000
```

**Текст:**
> Credentials получаем на developers.sber.ru.
> SCOPE — это тип доступа, PERS для физлиц, CORP для юрлиц.

---

## ЧАСТЬ 3: СКРИПТ ОБНОВЛЕНИЯ ТОКЕНА (2 мин)

### Кадр 3.1: Создание скрипта

**Создать `scripts/update_token.sh`:**

```bash
#!/bin/bash

# Скрипт обновления токена GigaChat
# Запускать через cron каждые 20 минут

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_DIR"

# Загружаем переменные
source .env

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
    echo "GIGACHAT_ACCESS_TOKEN=$TOKEN" > .env.tokens
    echo "$(date): Токен обновлён"
else
    echo "$(date): Ошибка получения токена"
    exit 1
fi
```

```bash
chmod +x scripts/update_token.sh
mkdir -p scripts
```

**Текст:**
> Токен GigaChat живёт 30 минут. Обновляем каждые 20 — с запасом.
> Скрипт сохраняет токен в отдельный файл, который читает сервер.

### Кадр 3.2: Настройка cron

```bash
# Открываем crontab
crontab -e

# Добавляем строку:
*/20 * * * * /home/user/video-demo/ai-1c/scripts/update_token.sh >> /home/user/video-demo/ai-1c/logs/token.log 2>&1
```

**Текст:**
> Cron будет запускать скрипт каждые 20 минут автоматически.

### Кадр 3.3: Первый запуск

```bash
# Создаём папку для логов
mkdir -p logs

# Запускаем вручную первый раз
./scripts/update_token.sh

# Проверяем что токен получен
cat .env.tokens
```

**Текст:**
> Отлично, токен получен. Теперь создаём API сервер.

---

## ЧАСТЬ 4: СОЗДАНИЕ FASTAPI СЕРВЕРА (3 мин)

### Кадр 4.1: Модуль GigaChat клиента

**Создать `gigachat_client.py`:**

```python
"""
Клиент для работы с GigaChat API
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()


def get_token() -> str:
    """Читает токен из файла (обновляется через cron)"""
    token_file = os.path.join(os.path.dirname(__file__), '.env.tokens')

    if not os.path.exists(token_file):
        raise RuntimeError("Токен не найден. Запустите scripts/update_token.sh")

    with open(token_file) as f:
        for line in f:
            if line.startswith('GIGACHAT_ACCESS_TOKEN='):
                return line.split('=', 1)[1].strip()

    raise RuntimeError("Токен не найден в файле")


def chat_completion(messages: list, model: str = "GigaChat") -> str:
    """
    Отправляет запрос к GigaChat API

    Args:
        messages: История сообщений [{"role": "user", "content": "..."}]
        model: Модель (GigaChat, GigaChat-Pro, GigaChat-Max)

    Returns:
        Ответ от нейросети
    """
    token = get_token()
    api_url = os.getenv('GIGACHAT_API_URL', 'https://gigachat.devices.sberbank.ru/api/v1')

    response = requests.post(
        f"{api_url}/chat/completions",
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {token}'
        },
        json={
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        },
        verify=False,  # GigaChat использует самоподписанный сертификат
        timeout=120
    )

    response.raise_for_status()
    data = response.json()

    return data['choices'][0]['message']['content']
```

**Текст:**
> Модуль простой: читаем токен из файла, отправляем запрос, возвращаем ответ.
> Обратите внимание на verify=False — GigaChat использует свой сертификат.

### Кадр 4.2: FastAPI сервер

**Создать `api_server.py`:**

```python
"""
FastAPI сервер для интеграции 1С с GigaChat
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import gigachat_client

app = FastAPI(
    title="GigaChat API для 1С",
    description="REST API для интеграции 1С с GigaChat",
    version="1.0.0"
)


class AnalyzeRequest(BaseModel):
    text: str
    system_prompt: str = "Ты - полезный ассистент. Отвечай кратко и по делу."
    return_format: str = "text"  # text или html


class AnalyzeResponse(BaseModel):
    success: bool
    result: str
    error: str | None = None


@app.get("/health")
def health():
    """Проверка состояния сервера"""
    try:
        # Проверяем что токен доступен
        gigachat_client.get_token()
        return {"status": "ok", "gigachat": True}
    except Exception as e:
        return {"status": "degraded", "gigachat": False, "error": str(e)}


@app.post("/analyze/text", response_model=AnalyzeResponse)
def analyze_text(req: AnalyzeRequest):
    """Анализ текста с помощью GigaChat"""

    try:
        messages = [
            {"role": "system", "content": req.system_prompt},
            {"role": "user", "content": req.text}
        ]

        result = gigachat_client.chat_completion(messages)

        # Форматируем в HTML если нужно
        if req.return_format == "html":
            result = f"""
            <html>
            <head><meta charset="utf-8"></head>
            <body style="font-family: Arial; padding: 20px; line-height: 1.6;">
            <div style="white-space: pre-wrap;">{result}</div>
            </body>
            </html>
            """

        return AnalyzeResponse(success=True, result=result)

    except Exception as e:
        return AnalyzeResponse(success=False, result="", error=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**Текст:**
> Сервер минималистичный: один endpoint для анализа текста.
> Принимает текст и системный промпт, возвращает ответ.
> Можно запросить HTML формат — удобно для отображения в 1С.

### Кадр 4.3: Запуск и тест

```bash
# Запускаем сервер
python api_server.py
```

**В новом терминале:**

```bash
# Тестируем
curl -X POST "http://localhost:8000/analyze/text" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Договор поставки №127 от 15.01.2024. Поставщик ООО ТехноПром обязуется поставить офисную мебель на сумму 2 450 000 руб. Срок 30 дней. Предоплата 50%.",
    "system_prompt": "Извлеки из договора: стороны, сумму, сроки, условия оплаты. Формат - список."
  }'
```

**Текст:**
> Отправляем текст договора. GigaChat извлекает ключевые данные...
> Работает! Теперь подключим к 1С.

---

## ЧАСТЬ 5: ИНТЕГРАЦИЯ С 1С (3 мин)

### Кадр 5.1: Создание Общей формы

1. Конфигуратор → Общие → Общие формы
2. Добавить → `ГигаЧатАссистент`

**Реквизиты формы:**
- `ТекстЗапроса` — Строка (неограниченная)
- `СистемныйПромпт` — Строка (неограниченная)
- `РезультатHTML` — Строка (неограниченная)
- `АдресСервера` — Строка, по умолчанию "localhost:8000"

### Кадр 5.2: Элементы формы

- ПолеТекстовогоДокумента → ТекстЗапроса
- ПолеТекстовогоДокумента → СистемныйПромпт
- ПолеHTMLДокумента → РезультатHTML
- Кнопка "Отправить"

### Кадр 5.3: Код модуля формы

```bsl
&НаКлиенте
Процедура ОтправитьЗапрос(Команда)

    Если ПустаяСтрока(ТекстЗапроса) Тогда
        Сообщить("Введите текст для анализа");
        Возврат;
    КонецЕсли;

    // Формируем JSON
    ПараметрыЗапроса = Новый Структура;
    ПараметрыЗапроса.Вставить("text", ТекстЗапроса);
    ПараметрыЗапроса.Вставить("system_prompt", СистемныйПромпт);
    ПараметрыЗапроса.Вставить("return_format", "html");

    ЗаписьJSON = Новый ЗаписьJSON;
    ЗаписьJSON.УстановитьСтроку();
    ЗаписатьJSON(ЗаписьJSON, ПараметрыЗапроса);
    ТелоЗапроса = ЗаписьJSON.Закрыть();

    // HTTP запрос
    Попытка
        АдресЧасти = СтрРазделить(АдресСервера, ":");
        Хост = АдресЧасти[0];
        Порт = ?(АдресЧасти.Количество() > 1, Число(АдресЧасти[1]), 8000);

        HTTPСоединение = Новый HTTPСоединение(Хост, Порт,,,, 120);
        HTTPЗапрос = Новый HTTPЗапрос("/analyze/text");
        HTTPЗапрос.УстановитьТелоИзСтроки(ТелоЗапроса, КодировкаТекста.UTF8);
        HTTPЗапрос.Заголовки.Вставить("Content-Type", "application/json");

        HTTPОтвет = HTTPСоединение.ОтправитьДляОбработки(HTTPЗапрос);

        Если HTTPОтвет.КодСостояния = 200 Тогда
            ЧтениеJSON = Новый ЧтениеJSON;
            ЧтениеJSON.УстановитьСтроку(HTTPОтвет.ПолучитьТелоКакСтроку());
            Ответ = ПрочитатьJSON(ЧтениеJSON);

            Если Ответ.success Тогда
                РезультатHTML = Ответ.result;
            Иначе
                Сообщить("Ошибка: " + Ответ.error);
            КонецЕсли;
        Иначе
            Сообщить("HTTP ошибка: " + HTTPОтвет.КодСостояния);
        КонецЕсли;

    Исключение
        Сообщить(ОписаниеОшибки());
    КонецПопытки;

КонецПроцедуры
```

**Текст:**
> Код стандартный для 1С: формируем JSON, отправляем POST, парсим ответ.
> Таймаут 120 секунд — GigaChat может думать долго на сложных запросах.

### Кадр 5.4: Демонстрация

1. Открыть форму в 1С
2. Ввести системный промпт: "Извлеки ключевые данные из договора"
3. Вставить текст договора
4. Нажать "Отправить"
5. Показать результат в HTML поле

**Текст:**
> Вставляем текст... отправляем... готово!
> GigaChat проанализировал договор и выделил все ключевые моменты.

---

## ЧАСТЬ 6: ЗАКЛЮЧЕНИЕ (1 мин)

### Кадр 6.1: Итоги

**Текст:**
> Что мы сделали:
> 1. Настроили автоматическое обновление токена через cron
> 2. Создали Python API сервер на FastAPI
> 3. Подключили к 1С через HTTP
>
> Теперь можно анализировать договоры, генерировать описания товаров,
> обрабатывать отчёты — всё что умеет GigaChat.

### Кадр 6.2: Ссылки

**Текст:**
> Код проекта в описании под видео.
> Вопросы — в комментариях!

---

## ДОПОЛНИТЕЛЬНО

### Возможные проблемы и решения

| Проблема | Решение |
|----------|---------|
| Токен не обновляется | Проверь права на скрипт: `chmod +x scripts/update_token.sh` |
| SSL ошибки | GigaChat использует самоподписанный сертификат, `verify=False` обязателен |
| 1С не подключается | Проверь firewall, попробуй `telnet localhost 8000` |
| Ошибка 401 | Токен истёк, запусти `./scripts/update_token.sh` вручную |
| Ошибка 402 | Закончился лимит на тарифе GigaChat |

### Файлы после записи

```
~/video-demo/ai-1c/
├── api_server.py           # FastAPI сервер
├── gigachat_client.py      # Клиент GigaChat
├── scripts/
│   └── update_token.sh     # Обновление токена
├── logs/
│   └── token.log           # Логи обновления
├── .env                    # Конфигурация
├── .env.tokens             # Текущий токен
├── venv/                   # Виртуальное окружение
└── requirements.txt        # Зависимости
```
