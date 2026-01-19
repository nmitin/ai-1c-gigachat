"""
Клиент для работы с GigaChat API.
Токен читается из файла .env.tokens (обновляется cron-скриптом).
"""

import os
import requests
from pathlib import Path
from dotenv import load_dotenv

# Отключаем предупреждения о самоподписанных сертификатах
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class GigaChatClient:
    """Клиент для взаимодействия с GigaChat API."""

    def __init__(self):
        self.project_dir = Path(__file__).parent
        self._load_config()

    def _load_config(self):
        """Загрузка конфигурации из .env файлов."""
        # Основные настройки
        load_dotenv(self.project_dir / ".env")
        self.api_url = os.getenv(
            "GIGACHAT_API_URL",
            "https://gigachat.devices.sberbank.ru/api/v1"
        )

    def _get_token(self) -> str:
        """Получение актуального токена из .env.tokens."""
        tokens_file = self.project_dir / ".env.tokens"

        if not tokens_file.exists():
            raise RuntimeError(
                "Файл .env.tokens не найден. "
                "Запустите scripts/update_token.sh для получения токена."
            )

        load_dotenv(tokens_file, override=True)
        token = os.getenv("GIGACHAT_ACCESS_TOKEN")

        if not token:
            raise RuntimeError(
                "GIGACHAT_ACCESS_TOKEN не найден в .env.tokens. "
                "Запустите scripts/update_token.sh"
            )

        return token

    def chat(
        self,
        user_message: str,
        system_prompt: str | None = None,
        model: str = "GigaChat",
        temperature: float = 0.7,
        max_tokens: int = 1024
    ) -> str:
        """
        Отправка сообщения в GigaChat и получение ответа.

        Args:
            user_message: Сообщение пользователя
            system_prompt: Системный промпт (опционально)
            model: Модель GigaChat (GigaChat, GigaChat-Pro, GigaChat-Max)
            temperature: Температура генерации (0-2)
            max_tokens: Максимальное количество токенов в ответе

        Returns:
            Текст ответа от модели
        """
        token = self._get_token()

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": user_message})

        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }

        response = requests.post(
            f"{self.api_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            json=payload,
            verify=False,  # GigaChat использует самоподписанный сертификат
            timeout=60
        )

        response.raise_for_status()
        data = response.json()

        return data["choices"][0]["message"]["content"]

    def is_token_valid(self) -> bool:
        """Проверка валидности токена."""
        try:
            token = self._get_token()
            # Простой запрос для проверки токена
            response = requests.get(
                f"{self.api_url}/models",
                headers={"Authorization": f"Bearer {token}"},
                verify=False,
                timeout=10
            )
            return response.status_code == 200
        except Exception:
            return False


# Синглтон для использования в приложении
_client: GigaChatClient | None = None

def get_client() -> GigaChatClient:
    """Получение экземпляра клиента (синглтон)."""
    global _client
    if _client is None:
        _client = GigaChatClient()
    return _client
