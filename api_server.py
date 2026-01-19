"""
FastAPI сервер для интеграции 1С с GigaChat.
Предоставляет REST API для анализа текста.
"""

import os
from contextlib import asynccontextmanager

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from gigachat_client import get_client, GigaChatClient

load_dotenv()


class TextAnalysisRequest(BaseModel):
    """Запрос на анализ текста."""
    text: str = Field(..., description="Текст для анализа", min_length=1)
    system_prompt: str = Field(
        default="Ты — полезный ассистент. Отвечай кратко и по существу.",
        description="Системный промпт для модели"
    )
    model: str = Field(
        default="GigaChat",
        description="Модель: GigaChat, GigaChat-Pro, GigaChat-Max"
    )
    temperature: float = Field(
        default=0.7,
        ge=0,
        le=2,
        description="Температура генерации (0-2)"
    )
    max_tokens: int = Field(
        default=1024,
        ge=1,
        le=8192,
        description="Максимум токенов в ответе"
    )


class TextAnalysisResponse(BaseModel):
    """Ответ с результатом анализа."""
    result: str = Field(..., description="Результат анализа от GigaChat")
    model: str = Field(..., description="Использованная модель")


class HealthResponse(BaseModel):
    """Ответ проверки здоровья сервиса."""
    status: str
    token_valid: bool
    message: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Жизненный цикл приложения."""
    # Проверяем токен при старте
    client = get_client()
    if client.is_token_valid():
        print("✓ GigaChat токен валиден")
    else:
        print("⚠ GigaChat токен невалиден или отсутствует")
        print("  Запустите: ./scripts/update_token.sh")
    yield


app = FastAPI(
    title="GigaChat API для 1С",
    description="REST API сервис для интеграции 1С с GigaChat",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health", response_model=HealthResponse, tags=["Системные"])
async def health_check():
    """Проверка состояния сервиса и валидности токена."""
    client = get_client()
    token_valid = client.is_token_valid()

    return HealthResponse(
        status="ok" if token_valid else "degraded",
        token_valid=token_valid,
        message="Сервис работает" if token_valid else "Токен невалиден"
    )


@app.post(
    "/analyze/text",
    response_model=TextAnalysisResponse,
    tags=["Анализ"],
    summary="Анализ текста через GigaChat"
)
async def analyze_text(request: TextAnalysisRequest):
    """
    Отправляет текст в GigaChat для анализа.

    Примеры использования:
    - Классификация обращений пациентов
    - Извлечение данных из текста
    - Суммаризация документов
    - Ответы на вопросы по контексту
    """
    client = get_client()

    try:
        result = client.chat(
            user_message=request.text,
            system_prompt=request.system_prompt,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens
        )

        return TextAnalysisResponse(
            result=result,
            model=request.model
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при обращении к GigaChat: {str(e)}"
        )


if __name__ == "__main__":
    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", "8000"))

    uvicorn.run(
        "api_server:app",
        host=host,
        port=port,
        reload=True
    )
