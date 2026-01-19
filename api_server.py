"""
FastAPI сервер для интеграции 1С с GigaChat
"""
from fastapi import FastAPI
from pydantic import BaseModel
import gigachat_client

app = FastAPI(
    title="GigaChat API для 1С",
    description="REST API для интеграции 1С с GigaChat",
    version="1.0.0"
)


class AnalyzeRequest(BaseModel):
    """Запрос на анализ текста"""
    text: str
    system_prompt: str = "Ты - полезный ассистент. Отвечай кратко и по делу."
    return_format: str = "text"  # text или html


class AnalyzeResponse(BaseModel):
    """Ответ с результатом анализа"""
    success: bool
    result: str
    error: str | None = None


@app.get("/")
def root():
    """Корневой endpoint"""
    return {
        "service": "GigaChat API для 1С",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
def health():
    """Проверка состояния сервера и доступности токена"""
    try:
        gigachat_client.get_token()
        return {"status": "ok", "gigachat": True}
    except Exception as e:
        return {"status": "degraded", "gigachat": False, "error": str(e)}


@app.post("/analyze/text", response_model=AnalyzeResponse)
def analyze_text(req: AnalyzeRequest):
    """
    Анализ текста с помощью GigaChat

    - **text**: Текст для анализа
    - **system_prompt**: Системный промпт (инструкция для ИИ)
    - **return_format**: Формат ответа - text или html
    """
    try:
        messages = [
            {"role": "system", "content": req.system_prompt},
            {"role": "user", "content": req.text}
        ]

        result = gigachat_client.chat_completion(messages)

        # Форматируем в HTML если нужно
        if req.return_format == "html":
            result = format_as_html(result)

        return AnalyzeResponse(success=True, result=result)

    except Exception as e:
        return AnalyzeResponse(success=False, result="", error=str(e))


def format_as_html(text: str) -> str:
    """Оборачивает текст в HTML для отображения в 1С"""
    # Экранируем HTML-символы
    text = text.replace("&", "&amp;")
    text = text.replace("<", "&lt;")
    text = text.replace(">", "&gt;")

    # Заменяем переносы строк на <br>
    text = text.replace("\n", "<br>\n")

    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{
            font-family: Arial, sans-serif;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }}
    </style>
</head>
<body>
{text}
</body>
</html>"""


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
