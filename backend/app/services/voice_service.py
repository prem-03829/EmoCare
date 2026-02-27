# app/services/voice_service.py

import os
import tempfile
import whisper
from app.core.config import settings

whisper_model = whisper.load_model(settings.WHISPER_MODEL)


def _ensure_ffmpeg_on_path() -> None:
    ffmpeg_dir = (settings.FFMPEG_PATH or "").strip()
    if not ffmpeg_dir:
        return

    current_path = os.environ.get("PATH", "")
    path_parts = current_path.split(os.pathsep) if current_path else []
    if ffmpeg_dir not in path_parts:
        os.environ["PATH"] = f"{ffmpeg_dir}{os.pathsep}{current_path}" if current_path else ffmpeg_dir


async def speech_to_text(file):
    _ensure_ffmpeg_on_path()

    with tempfile.NamedTemporaryFile(delete=False, suffix=".m4a") as temp_audio:
        temp_audio.write(await file.read())
        temp_path = temp_audio.name

    try:
        result = whisper_model.transcribe(
            temp_path, task="transcribe", language=None, temperature=0.2, fp16=False
        )

        return result.get("text", "").strip()

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
