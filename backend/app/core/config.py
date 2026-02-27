import os
from dotenv import load_dotenv

# Load .env file
load_dotenv()

class Settings:
    APP_NAME: str = os.getenv("APP_NAME", "Emotion AI Backend")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "phi3")
    OLLAMA_TIMEOUT_SECONDS: int = int(os.getenv("OLLAMA_TIMEOUT_SECONDS", "300"))
    OLLAMA_MAX_TOKENS: int = int(os.getenv("OLLAMA_MAX_TOKENS", "120"))
    CHAT_HISTORY_LIMIT: int = int(os.getenv("CHAT_HISTORY_LIMIT", "4"))
    WHISPER_MODEL: str = os.getenv("WHISPER_MODEL", "base")
    FFMPEG_PATH: str = os.getenv("FFMPEG_PATH", "")
    SUPABASE_URL: str = os.getenv("SUPABASE_URL")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY")
    SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

settings = Settings()


