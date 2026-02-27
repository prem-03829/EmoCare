from fastapi import APIRouter
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


class ChatRequest(BaseModel):
    message: str


class JournalRequest(BaseModel):
    entry: str


# ────────────────────────────────────────────────
# Chat endpoints (no auth)
# ────────────────────────────────────────────────


@router.post("")
@router.post("/send")
def send_chat_message(req: ChatRequest):
    """
    Send a message and get AI reply + emotion info
    No authentication required
    """
    # For testing: you can hardcode a user_id or pass it in the body
    # Here we use a fixed test user (change it to whatever you want)
    test_user_id = "11111111-1111-1111-1111-111111111111"

    return generate_reply(test_user_id, req.message)


@router.get("/history")
def get_chat_history():
    """
    Get full chat history for the test user
    No authentication required
    """
    test_user_id = "11111111-1111-1111-1111-111111111111"
    return get_full_history(test_user_id)


@router.get("/mood/today")
def get_daily_mood_today():
    """
    Get today's mood summary for the test user
    """
    test_user_id = "11111111-1111-1111-1111-111111111111"
    return get_daily_mood(test_user_id)


@router.get("/timeline")
def get_emotion_timeline():
    """
    Get day-by-day emotion timeline for the test user
    """
    test_user_id = "11111111-1111-1111-1111-111111111111"
    return get_emotion_timeline(test_user_id)


@router.get("/weekly-insight")
def get_weekly_insight():
    """
    Get weekly emotional insight for the test user
    """
    test_user_id = "11111111-1111-1111-1111-111111111111"
    return get_weekly_insight(test_user_id)


@router.post("/journal")
def create_journal_entry_endpoint(req: JournalRequest):
    """
    Create a journal entry for the test user
    No authentication required
    """
    test_user_id = "11111111-1111-1111-1111-111111111111"
    return create_journal_entry(test_user_id, req.entry)
