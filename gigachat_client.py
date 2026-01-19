"""
Клиент для работы с GigaChat API
Токен читается из файла .env.tokens (обновляется через cron)
"""
import os
import requests
import urllib3
from dotenv import load_dotenv

# Отключаем предупреждения о самоподписанном сертификате
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

load_dotenv()


def get_token() -> str:
    """
    Читает токен из файла .env.tokens
    Файл обновляется скриптом scripts/update_token.sh через cron
    """
    token_file = os.path.join(os.path.dirname(__file__), '.env.tokens')

    if not os.path.exists(token_file):
        raise RuntimeError(
            "Токен не найден. Запустите: ./scripts/update_token.sh"
        )

    with open(token_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('GIGACHAT_ACCESS_TOKEN='):
                token = line.split('=', 1)[1]
                if token:
                    return token

    raise RuntimeError("Токен не найден в файле .env.tokens")


def chat_completion(
    messages: list,
    model: str = "GigaChat",
    temperature: float = 0.7,
    max_tokens: int = 2048
) -> str:
    """
    Отправляет запрос к GigaChat API

    Args:
        messages: История сообщений [{"role": "system/user/assistant", "content": "..."}]
        model: Модель (GigaChat, GigaChat-Pro, GigaChat-Max)
        temperature: Креативность (0.0 - 1.0)
        max_tokens: Максимальная длина ответа

    Returns:
        Текст ответа от нейросети

    Raises:
        RuntimeError: Если токен не найден или API вернул ошибку
    """
    token = get_token()
    api_url = os.getenv(
        'GIGACHAT_API_URL',
        'https://gigachat.devices.sberbank.ru/api/v1'
    )

    response = requests.post(
        f"{api_url}/chat/completions",
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {token}'
        },
        json={
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        },
        verify=False,  # GigaChat использует самоподписанный сертификат
        timeout=120
    )

    # Обработка ошибок
    if response.status_code == 401:
        raise RuntimeError("Токен истёк или недействителен. Запустите update_token.sh")
    elif response.status_code == 402:
        raise RuntimeError("Недостаточно средств на балансе GigaChat")
    elif response.status_code == 429:
        raise RuntimeError("Превышен лимит запросов к GigaChat API")

    response.raise_for_status()
    data = response.json()

    return data['choices'][0]['message']['content']


# Для тестирования модуля напрямую
if __name__ == "__main__":
    try:
        token = get_token()
        print(f"Токен найден: {token[:20]}...")

        # Тестовый запрос
        result = chat_completion([
            {"role": "user", "content": "Привет! Скажи одним предложением, кто ты?"}
        ])
        print(f"Ответ GigaChat: {result}")

    except Exception as e:
        print(f"Ошибка: {e}")
