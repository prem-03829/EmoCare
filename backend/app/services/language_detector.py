#language detector
from langdetect import detect

SUPPORTED_LANGUAGES = ["en", "hi", "mr"]

def detect_language(text: str) -> str:
    try:
        if len(text.strip()) < 3:
            return "en"

        lang = detect(text)

        if lang in SUPPORTED_LANGUAGES:
            return lang
        return "en"

    except Exception:
        return "en"