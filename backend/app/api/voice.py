# app/api/voice.py

from fastapi import APIRouter, UploadFile, File, Form
from app.services.voice_service import speech_to_text
from app.services.chat_service import generate_reply

router = APIRouter()


@router.post("/")
async def voice_chat(user_id: str = Form(...), file: UploadFile = File(...)):
    text = await speech_to_text(file)

    if not text:
        return {
            "reply": "I couldn’t clearly hear that. Could you please try again?",
            "emotion": "NEUTRAL",
            "confidence": 0.0,
        }

    # 🔥 Reuse your ENTIRE chat pipeline
    return generate_reply(user_id, text)
