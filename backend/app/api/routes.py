from fastapi import APIRouter
from app.api.chats import router as chat_router
from app.api.voice import router as voice_router
from app.core.timezone import now_ist

router = APIRouter()
router.include_router(chat_router, prefix="/chat", tags=["Chat"])
router.include_router(voice_router, prefix="/voice", tags=["Voice"])
@router.get("/ping")
def ping():
    return {"message": "pong"}

@router.get("/time")
def get_time():
    return {
        "server_time": now_ist().isoformat()
    }