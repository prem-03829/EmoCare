from fastapi import APIRouter, Query
from pydantic import BaseModel
import app.services.chat_service as chat_service

router = APIRouter(prefix="/chat", tags=["chat"])


# ────────────────────────────────────────────────
# Request Models (POST bodies)
# ────────────────────────────────────────────────


class ChatRequest(BaseModel):
    user_id: str  # ← required: send "prem", "test1", etc.
    message: str


class JournalRequest(BaseModel):
    user_id: str  # ← required
    entry: str

@router.post("")
@router.post("/send")
def send_chat_message(req: ChatRequest):
    return chat_service.generate_reply(req.user_id, req.message)


@router.get("/history")
def get_chat_history(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    return chat_service.get_full_history(user_id)


@router.get("/mood/today")
def get_daily_mood_today(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    return chat_service.get_daily_mood(user_id)


@router.get("/timeline")
def get_emotion_timeline_endpoint(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    return chat_service.get_emotion_timeline(user_id)


@router.get("/weekly-insight")
def get_weekly_insight_endpoint(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    return chat_service.get_weekly_insight(user_id)


@router.get("/auto-journal")
def auto_journal(user_id: str = Query(...)):
    return chat_service.generate_auto_journal(user_id)