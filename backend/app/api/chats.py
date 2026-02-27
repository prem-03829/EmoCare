from fastapi import APIRouter, Query
from pydantic import BaseModel
from app.services.chat_service import (
    generate_reply,
    get_full_history,
    get_daily_mood,
    get_emotion_timeline,
    get_weekly_insight,
    create_journal_entry,
)

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


# ────────────────────────────────────────────────
# Chat endpoints
# ────────────────────────────────────────────────


@router.post("")
@router.post("/send")
def send_chat_message(req: ChatRequest):
    """
    Send a message and get AI reply + emotion info
    No authentication required
    """
    return generate_reply(req.user_id, req.message)


@router.get("/history")
def get_chat_history(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    """
    Get full chat history for the specified user
    No authentication required
    """
    return get_full_history(user_id)


@router.get("/mood/today")
def get_daily_mood_today(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    """
    Get today's mood summary for the specified user
    """
    return get_daily_mood(user_id)


@router.get("/timeline")
def get_emotion_timeline(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    """
    Get day-by-day emotion timeline for the specified user
    """
    return get_emotion_timeline(user_id)


@router.get("/weekly-insight")
def get_weekly_insight(
    user_id: str = Query(..., description="User identifier (e.g. prem, test1)")
):
    """
    Get weekly emotional insight for the specified user
    """
    return get_weekly_insight(user_id)


@router.post("/journal")
def create_journal_entry_endpoint(req: JournalRequest):
    """
    Create a journal entry for the specified user
    No authentication required
    """
    return create_journal_entry(req.user_id, req.entry)
