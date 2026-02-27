import httpx
from app.core.config import settings

OLLAMA_URL = "http://localhost:11434/api/generate"

def generate_llm_response(prompt: str) -> str:
    payload = {
        "model": settings.OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_predict": settings.OLLAMA_MAX_TOKENS,
            "temperature": 0.7,
            "top_p": 0.9,
        },
    }

    try:
        timeout = httpx.Timeout(
            connect=10.0,
            read=float(settings.OLLAMA_TIMEOUT_SECONDS),
            write=30.0,
            pool=30.0,
        )
        response = httpx.post(OLLAMA_URL, json=payload, timeout=timeout)
        data = response.json()
        return data.get("response", "").strip()
    except Exception as e:
        return f"LLM error: {str(e)}"
