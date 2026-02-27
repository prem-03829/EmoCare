# from fastapi import APIRouter
# from app.api.chats import router as chat_router
# from app.api.voice import router as voice_router
# from app.core.timezone import now_ist

# router = APIRouter()
# router.include_router(chat_router, prefix="/chat", tags=["Chat"])
# router.include_router(voice_router, prefix="/voice", tags=["Voice"])
# @router.get("/ping")
# def ping():
#     return {"message": "pong"}

# @router.get("/time")
# def get_time():
#     return {
#         "server_time": now_ist().isoformat()
#     }

# from fastapi import APIRouter
# from app.api.chats import router as chat_router
# from app.api.voice import router as voice_router
# from app.core.timezone import now_ist
# from pydantic import BaseModel
# from app.utils.safety import is_sensitive

# router = APIRouter()
# router.include_router(prefix="/chat", tags=["Chat"])
# router.include_router(prefix="/voice", tags=["Voice"])

# class ChatRequest(BaseModel):
#     message: str

# def generate_ai_response(text):
#     return "AI response"

# @router.get("/ping")
# def ping():
#     return {"message": "pong"}

# @router.get("/time")
# def get_time():
#     return {
#         "server_time": now_ist().isoformat()
#     }

# @router.post("/chat")
# async def chat(request: ChatRequest):

#     user_message = request.message

#     print("User message:", user_message)
#     print("Is sensitive:", is_sensitive(user_message))  # :point_left: add this

#     if is_sensitive(user_message):
#         return {
#             "response": "Safety triggered"
#         }

#     ai_reply = generate_ai_response(user_message)

#     return {"response": ai_reply}

from fastapi import APIRouter
from app.api.chats import router as chat_router
from app.api.voice import router as voice_router
from app.core.timezone import now_ist

router = APIRouter()

# :white_check_mark: Pass the router as first argument
router.include_router(chat_router)
router.include_router(voice_router)

@router.get("/ping")
def ping():
    return {"message": "pong"}

@router.get("/time")
def get_time():
    return {
        "server_time": now_ist().isoformat()
    }