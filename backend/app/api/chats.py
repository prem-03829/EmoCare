# from fastapi import APIRouter
# from pydantic import BaseModel
# from app.services.chat_service import generate_reply
# from pydantic import BaseModel
# from app.core.auth import get_current_user

# router = APIRouter()

# class ChatRequest(BaseModel):
#     message: str


# class JournalRequest(BaseModel):
#     user_id: str
#     entry: str


# @router.post("/",summary="Generate emotion-aware AI reply",description="Accepts user text and returns an empathetic AI response along with detected emotion and confidence score.")
# def chat(req: ChatRequest):
#     return generate_reply(req.user_id, req.message)


# @router.get("/history/{user_id}")
# def chat_history(user_id: str):
#     from app.services.chat_service import get_full_history
#     return get_full_history(user_id)


# @router.get("/mood/{user_id}")
# def daily_mood(user_id: str):
#     from app.services.chat_service import get_daily_mood
#     return get_daily_mood(user_id)

# @router.get("/timeline/{user_id}")
# def emotion_timeline(user_id: str):
#     from app.services.chat_service import get_emotion_timeline
#     return get_emotion_timeline(user_id)

# @router.get("/weekly-insight/{user_id}")
# def weekly_insight(user_id: str):
#     from app.services.chat_service import get_weekly_insight
#     return get_weekly_insight(user_id)


# @router.post("/journal")
# def journal(req: JournalRequest):
#     from app.services.chat_service import create_journal_entry
#     return create_journal_entry(req.user_id, req.entry)


# @router.post("/chat")
# def chat(req: ChatRequest, user=Depends(get_current_user)):
#     user_id = user["sub"]



from fastapi import APIRouter, Depends
from pydantic import BaseModel
from app.services.chat_service import generate_reply
from app.core.auth import get_current_user

router = APIRouter()


class ChatRequest(BaseModel):
    message: str


class JournalRequest(BaseModel):
    user_id: str
    entry: str


@router.post("/")
def chat(req: ChatRequest, user=Depends(get_current_user)):
    user_id = user["sub"]  # from JWT
    return generate_reply(user_id, req.message)


@router.get("/history/{user_id}")
def chat_history(user_id: str):
    from app.services.chat_service import get_full_history
    return get_full_history(user_id)


@router.get("/mood/{user_id}")
def daily_mood(user_id: str):
    from app.services.chat_service import get_daily_mood
    return get_daily_mood(user_id)

@router.get("/timeline/{user_id}")
def emotion_timeline(user_id: str):
    from app.services.chat_service import get_emotion_timeline
    return get_emotion_timeline(user_id)

@router.get("/weekly-insight/{user_id}")
def weekly_insight(user_id: str):
    from app.services.chat_service import get_weekly_insight
    return get_weekly_insight(user_id)


@router.post("/journal")
def journal(req: JournalRequest):
    from app.services.chat_service import create_journal_entry
    return create_journal_entry(req.user_id, req.entry)


@router.post("/chat")
def chat_auth(req: ChatRequest, user=Depends(get_current_user)):
    user_id = user["sub"]
    return generate_reply(user_id, req.message)
