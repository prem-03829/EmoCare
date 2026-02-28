#chatservice
from app.api.emotion import detect_emotion
from app.services.language_detector import detect_language
from app.services.translation import translate
from app.api.ollama_client import generate_llm_response
from app.core.logger import logger
from app.core.supabase_client import supabase
from app.core.config import settings
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from app.utils.safety import is_sensitive
import random


CRISIS_KEYWORDS = [
    "suicide",
    "kill myself",
    "end my life",
    "i want to die",
    "self harm",
    "hurt myself",
]


TONE_MAP = {
    "sadness": "Be soft and comforting.",
    "anger": "Be calm and grounding.",
    "joy": "Match their excitement.",
    "fear": "Be reassuring and steady.",
}


def resolve_user_uuid(text_user_id: str) -> str:
    """
    Convert text user_id ("prem", "test123") → real UUID from users.id
    Auto-creates user if not found (demo mode)
    """

    # 1️⃣ Try to find existing user
    res = (
        supabase.table("users")
        .select("id")
        .eq("username", text_user_id)  # keep same column name
        .limit(1)
        .execute()
    )

    if res.data:
        return res.data[0]["id"]

    # 2️⃣ If not found → create new user
    new_user = (
        supabase.table("users")
        .insert({
            "username": text_user_id
        })
        .execute()
    )

    if not new_user.data:
        raise ValueError("Failed to create new demo user")

    return new_user.data[0]["id"]


def get_recent_history(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)  # ← now UUID
        .order("started_at", desc=True)
        .limit(1)
        .execute()
    )

    if not conv_response.data:
        return []

    conversation_id = conv_response.data[0]["id"]

    response = (
        supabase.table("messages")
        .select("sender, content, created_at")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=True)
        .limit(settings.CHAT_HISTORY_LIMIT)
        .execute()
    )

    if not response.data:
        return []

    history = []
    for row in reversed(response.data):
        history.append(
            {
                "message": row["content"] if row["sender"] == "user" else None,
                "reply": row["content"] if row["sender"] == "bot" else None,
                "created_at": row["created_at"],
            }
        )

    return history


def save_chat(
    text_user_id: str, user_message: str, reply: str, emotion: str, confidence: float
):
    user_uuid = resolve_user_uuid(text_user_id)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)
        .order("started_at", desc=True)
        .limit(1)
        .execute()
    )

    if conv_response.data:
        conversation_id = conv_response.data[0]["id"]
    else:
        conv_insert = (
            supabase.table("conversations")
            .insert({"user_id": user_uuid})  # ← UUID
            .execute()
        )
        conversation_id = conv_insert.data[0]["id"]

    now = datetime.utcnow().isoformat()

    user_msg = (
        supabase.table("messages")
        .insert(
            {
                "conversation_id": conversation_id,
                "sender": "user",
                "content": user_message,
                "created_at": now,
            }
        )
        .execute()
    )
    user_msg_id = user_msg.data[0]["id"]

    if emotion:
        supabase.table("message_emotions").insert(
            {"message_id": user_msg_id, "emotion": emotion, "confidence": confidence}
        ).execute()

    supabase.table("messages").insert(
        {
            "conversation_id": conversation_id,
            "sender": "bot",
            "content": reply,
            "created_at": now,
        }
    ).execute()


# def generate_reply(text_user_id: str, message: str):
#     user_uuid = resolve_user_uuid(text_user_id)

#     logger.info(f"User: {text_user_id} (UUID: {user_uuid}) | Message: {message}")
    
#     message_clean = message.strip()
#     message_lower = message_clean.lower()
#         # -------------------------
#     # 🌍 0️⃣ Language Detection + Translation
#     # -------------------------
#     lang = detect_language(message_clean)
#     logger.info(f"Detected language: {lang}")

#     if lang != "en":
#         message_en = translate(message_clean, lang, "en")
#     else:
#         message_en = message_clean

# # -------------------------
# # 1️⃣ Crisis check
# # -------------------------
#     if is_sensitive(message_en):

#         crisis_reply_en = (
#             "I'm really concerned about what you're feeling.\n\n"
#             "You don’t have to go through this alone. "
#             "If you're thinking about harming yourself, please reach out for help right now:\n\n"
#             "📞 AASRA: +91-9820466726\n"
#             "📞 iCALL: 9152987821\n\n"
#             "You matter. Talking to someone can really help."
#         )

#         # 🌍 Translate crisis reply if needed
#         if lang in ["hi", "mr"]:
#             final_reply = translate(crisis_reply_en, "en", lang)
#         else:
#             final_reply = crisis_reply_en

#         save_chat(text_user_id, message_clean, final_reply, "crisis", 1.0)

#         return{
#             "reply": final_reply,
#             "emotion": "crisis",
#             "confidence": 1.0,
#             "crisis_detected": True,
#             "typing_delay": 1.5,
#         }

#     # -------------------------
#     # 2️⃣ Greeting shortcut
#     # -------------------------
#     GREETINGS = {"hi", "hello", "hey", "hii", "yo", "sup"}

#     if message_lower in GREETINGS:
#         reply = random.choice([
#             "hey 🙂 what's up?",
#             "hi! how's your day going?",
#             "hey… good to see you."
#         ])

#         if lang in ["hi", "mr"]:
#             final_reply = translate(reply, "en", lang)
#         else:
#             final_reply = reply

#         save_chat(text_user_id, message_clean, final_reply, "neutral", 0.0)

#         return {
#             "reply": final_reply,
#             "emotion": "neutral",
#             "confidence": 0.0,
#             "crisis_detected": False,
#             "typing_delay": 0.8,
#         }

#     # -------------------------
#     # 3️⃣ Emotion detection (softer usage)
#     # -------------------------
#     emotion_data = detect_emotion(message_en)
#     emotion = emotion_data["emotion"]
#     confidence = emotion_data["confidence"]

#     # Only apply emotional tone if confidence strong
#     tone_hint = ""
#     if confidence > 0.65:
#         tone_hint = f"The user might be feeling {emotion}. Respond gently."

#     # -------------------------
#     # 4️⃣ Limit history (more natural)
#     # -------------------------
#     history = get_recent_history(text_user_id)[-2:]

#     conversation_context = ""
#     for chat in history:
#         if chat.get("message"):
#             conversation_context += f"User: {chat['message']}\n"
#         if chat.get("reply"):
#             conversation_context += f"You: {chat['reply']}\n"

#     # -------------------------
#     # 5️⃣ Random personality flavor
#     # -------------------------
#     personality_modes = [
#         "Be calm and grounded.",
#         "Be relaxed and casual.",
#         "Be gently supportive.",
#         "Be minimal and natural."
#     ]

#     random_style = random.choice(personality_modes)

#     # -------------------------
#     # 6️⃣ Humanized prompt
#     # -------------------------
#     prompt = f"""
# You are a real close friend texting back naturally.

# You are NOT a therapist.
# You are NOT giving advice unless directly asked.
# You're just being there.

# {random_style}
# {tone_hint}

# Keep responses short.
# Use normal, everyday language.
# It's okay to be imperfect.
# Sometimes respond briefly.
# Don't over-analyze.
# Don't sound motivational.

# Previous conversation:
# {conversation_context}

# User: {message_en}

# Reply naturally.
# """

#     reply = generate_llm_response(prompt)
#         # 🌍 Translate reply back if needed
#     if lang != "en":
#         final_reply = translate(reply, "en", lang)
#     else:
#         final_reply = reply

#     save_chat(text_user_id, message_clean, final_reply, emotion, confidence)

#     word_count = len(reply.split())
#     typing_delay = min(max(word_count * 0.04, 0.8), 3.0)

#     return {
#         "reply": final_reply,
#         "emotion": emotion,
#         "confidence": confidence,
#         "crisis_detected": False,
#         "typing_delay": typing_delay,
#     }
def generate_reply(text_user_id: str, message: str):
    user_uuid = resolve_user_uuid(text_user_id)

    logger.info(f"User: {text_user_id} (UUID: {user_uuid}) | Message: {message}")
    
    message_clean = message.strip()
    message_lower = message_clean.lower()

    # 🌍 Force emotion for strong Hindi/Marathi keywords (hackathon-safe layer)
    lower_original = message_clean.lower()
    forced_emotion = None

    # Hindi / Marathi sadness
    if any(word in lower_original for word in [
        "दुखी", "उदास", "अच्छा नहीं लग", "मन खराब",
        "वाईट वाटत", "बरं वाटत नाही"
    ]):
        forced_emotion = "sadness"

    # Hindi / Marathi anger
    elif any(word in lower_original for word in [
        "गुस्सा", "चिढ़", "परेशान",
        "राग", "चिडचिड"
    ]):
        forced_emotion = "anger"

    # Hindi / Marathi fear
    elif any(word in lower_original for word in [
        "डर", "घबराहट", "चिंता",
        "भीती", "काळजी"
    ]):
        forced_emotion = "fear"

    # -------------------------
    # 🌍 0️⃣ Language Detection + Translation
    # -------------------------
    lang = detect_language(message_clean)
        # 🔎 Fix Hindi/Marathi confusion
    if lang == "hi":
        # Simple Marathi keyword check
        if any(word in message_clean.lower() for word in [
            "मला", "नाही", "आहे", "वाटत", "बरं"
        ]):
            lang = "mr"
    logger.info(f"Detected language: {lang}")

    if lang != "en":
        message_en = translate(message_clean, lang, "en")
    else:
        message_en = message_clean

    # -------------------------
    # 1️⃣ Crisis check
    # -------------------------
    if is_sensitive(message_en):

        crisis_reply_en = (
            "I'm really concerned about what you're feeling.\n\n"
            "You don’t have to go through this alone. "
            "If you're thinking about harming yourself, please reach out for help right now:\n\n"
            "📞 AASRA: +91-9820466726\n"
            "📞 iCALL: 9152987821\n\n"
            "You matter. Talking to someone can really help."
        )

        if lang in ["hi", "mr"]:
            final_reply = translate(crisis_reply_en, "en", lang)
        else:
            final_reply = crisis_reply_en

        save_chat(text_user_id, message_clean, final_reply, "crisis", 1.0)

        return {
            "reply": final_reply,
            "emotion": "crisis",
            "confidence": 1.0,
            "crisis_detected": True,
            "typing_delay": 1.5,
        }

    # -------------------------
    # 2️⃣ Greeting shortcut
    # -------------------------
    GREETINGS = {"hi", "hello", "hey", "hii", "yo", "sup"}

    if message_lower in GREETINGS:
        reply = random.choice([
            "hey 🙂 what's up?",
            "hi! how's your day going?",
            "hey… good to see you."
        ])

        if lang in ["hi", "mr"]:
            final_reply = translate(reply, "en", lang)
        else:
            final_reply = reply

        save_chat(text_user_id, message_clean, final_reply, "neutral", 0.0)

        return {
            "reply": final_reply,
            "emotion": "neutral",
            "confidence": 0.0,
            "crisis_detected": False,
            "typing_delay": 0.8,
        }

    # -------------------------
    # 3️⃣ Emotion detection
    # -------------------------
    emotion_data = detect_emotion(message_en)

    if forced_emotion:
        emotion = forced_emotion
        confidence = 0.95
    else:
        emotion = emotion_data["emotion"]
        confidence = emotion_data["confidence"]

    tone_hint = ""
    if confidence > 0.65:
        tone_hint = f"The user might be feeling {emotion}. Respond gently."

    # -------------------------
    # 4️⃣ Limit history
    # -------------------------
    history = get_recent_history(text_user_id)[-2:]

    conversation_context = ""
    for chat in history:
        if chat.get("message"):
            conversation_context += f"User: {chat['message']}\n"
        if chat.get("reply"):
            conversation_context += f"You: {chat['reply']}\n"

    # -------------------------
    # 5️⃣ Personality flavor
    # -------------------------
    personality_modes = [
        "Be calm and grounded.",
        "Be relaxed and casual.",
        "Be gently supportive.",
        "Be minimal and natural."
    ]

    random_style = random.choice(personality_modes)

    # -------------------------
    # 6️⃣ Prompt
    # -------------------------
    prompt = f"""
You are a real close friend texting back naturally.

You are NOT a therapist.
You are NOT giving advice unless directly asked.
You're just being there.

{random_style}
{tone_hint}

Keep responses short.
Use normal, everyday language.
It's okay to be imperfect.
Sometimes respond briefly.
Don't over-analyze.
Don't sound motivational.

Previous conversation:
{conversation_context}

User: {message_en}

Reply naturally.
"""

    reply = generate_llm_response(prompt)

    if lang != "en":
        final_reply = translate(reply, "en", lang)
    else:
        final_reply = reply

    save_chat(text_user_id, message_clean, final_reply, emotion, confidence)

    word_count = len(reply.split())
    typing_delay = min(max(word_count * 0.04, 0.8), 3.0)

    return {
        "reply": final_reply,
        "emotion": emotion,
        "confidence": confidence,
        "crisis_detected": False,
        "typing_delay": typing_delay,
    }



def get_full_history(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)
        .order("started_at", desc=True)   # ✅ this is correct
        .limit(1)
        .execute()
    )

    if not conv_response.data:
        return []

    conversation_id = conv_response.data[0]["id"]

    response = (
        supabase.table("messages")
        .select("sender, content, created_at")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)  # 🔥 FIXED HERE
        .execute()
    )

    return response.data if response.data else []

def get_daily_mood(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)
        .execute()
    )

    if not conv_response.data:
        return {"message": "No mood data available."}

    conv_ids = [c["id"] for c in conv_response.data]

    today = datetime.utcnow().date().isoformat()

    emotions_data = (
        supabase.table("messages")
        .select("created_at, message_emotions(emotion, confidence)")
        .in_("conversation_id", conv_ids)
        .eq("sender", "user")
        .gte("created_at", f"{today}T00:00:00")
        .lt("created_at", f"{today}T23:59:59")
        .execute()
    )

    if not emotions_data.data:
        return {"message": "No mood data for today."}

    emotions_today = []
    confidences = []

    for row in emotions_data.data:
        if row.get("message_emotions"):
            emotions_today.append(row["message_emotions"]["emotion"])
            confidences.append(row["message_emotions"]["confidence"])

    if not emotions_today:
        return {"message": "No mood data for today."}

    dominant_emotion = max(set(emotions_today), key=emotions_today.count)
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0

    return {
        "date": today,
        "dominant_emotion": dominant_emotion,
        "average_confidence": round(avg_confidence, 3),
        "total_messages": len(emotions_today),
    }

def get_emotion_timeline(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)
        .execute()
    )

    if not conv_response.data:
        return {"message": "No emotion data available."}

    conv_ids = [c["id"] for c in conv_response.data]

    response = (
        supabase.table("messages")
        .select("created_at, message_emotions(emotion)")
        .in_("conversation_id", conv_ids)
        .eq("sender", "user")
        .execute()
    )

    if not response.data:
        return {"message": "No emotion data available."}

    daily_emotions = defaultdict(list)

    for row in response.data:
        if not row.get("message_emotions"):
            continue

        date = (
            datetime.fromisoformat(row["created_at"].replace("Z", ""))
            .date()
            .isoformat()
        )

        daily_emotions[date].append(
            row["message_emotions"]["emotion"]
        )

    timeline = []

    for date, emotions in daily_emotions.items():
        dominant = max(set(emotions), key=emotions.count)
        timeline.append({"date": date, "dominant_emotion": dominant})

    timeline.sort(key=lambda x: x["date"])

    return timeline


def get_weekly_insight(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    today = datetime.utcnow()
    week_ago = today - timedelta(days=7)

    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_uuid)
        .execute()
    )

    if not conv_response.data:
        return {"message": "No weekly data available."}

    conv_ids = [c["id"] for c in conv_response.data]

    response = (
        supabase.table("messages")
        .select("created_at, message_emotions(emotion, confidence)")
        .in_("conversation_id", conv_ids)
        .eq("sender", "user")
        .gte("created_at", week_ago.isoformat())
        .execute()
    )

    if not response.data:
        return {"message": "No activity in last 7 days."}

    weekly_emotions = []
    weekly_confidences = []

    for row in response.data:
        if not row.get("message_emotions"):
            continue

        weekly_emotions.append(
            row["message_emotions"]["emotion"]
        )
        weekly_confidences.append(
            row["message_emotions"]["confidence"]
        )

    if not weekly_emotions:
        return {"message": "No activity in last 7 days."}

    emotion_counts = Counter(weekly_emotions)
    emotion_summary = "\n".join(
        [f"{e}: {c}" for e, c in emotion_counts.items()]
    )

    avg_confidence = (
        sum(weekly_confidences) / len(weekly_confidences)
        if weekly_confidences else 0
    )

    prompt = f"""
You're reflecting on someone's emotional week.

Emotion frequency (last 7 days):
{emotion_summary}

Average emotional intensity: {round(avg_confidence, 3)}

Write a short, warm reflection.
Sound human, not clinical.
Keep it conversational.
Offer one small suggestion naturally.
Keep it under 5 sentences.
"""

    insight = generate_llm_response(prompt)

    return {
        "weekly_emotion_counts": dict(emotion_counts),
        "average_confidence": round(avg_confidence, 3),
        "weekly_insight": insight,
    }


def generate_auto_journal(text_user_id: str):
    user_uuid = resolve_user_uuid(text_user_id)

    messages = supabase.table("messages")\
        .select("content")\
        .eq("sender", "user")\
        .execute()

    all_text = " ".join([m["content"] for m in messages.data])

    prompt = f"""
You're writing a reflective journal summary based on these conversations.

{all_text}

Write it in a natural, thoughtful tone.
Don't sound like a report.
Sound like someone gently reflecting on their own week.
Keep it 5–7 sentences.
"""

    summary = generate_llm_response(prompt)

    return {"auto_journal": summary}