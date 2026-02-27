from app.api.emotion import detect_emotion
from app.api.ollama_client import generate_llm_response
from app.core.logger import logger
from app.core.supabase_client import supabase
from app.core.config import settings
from datetime import datetime, timedelta
from collections import defaultdict
from collections import Counter
from app.services.crisis_detector import is_crisis
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


def is_crisis(message: str) -> bool:
    message_lower = message.lower()
    return any(keyword in message_lower for keyword in CRISIS_KEYWORDS)


def get_recent_history(user_id: str):
    # Get the most recent conversation for this user
    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_id)
        .order("started_at", desc=True)
        .limit(1)
        .execute()
    )

    if not conv_response.data:
        return []

    conversation_id = conv_response.data[0]["id"]

    # Get last N messages from that conversation
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

    # reverse so oldest comes first + format like old structure
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


def save_chat(user_id, message, reply, emotion, confidence):
    # ── 1. Get or create conversation ───────────────────────────────────────
    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_id)
        .order("started_at", desc=True)
        .limit(1)
        .execute()
    )

    if conv_response.data:
        conversation_id = conv_response.data[0]["id"]
    else:
        conv_insert = (
            supabase.table("conversations").insert({"user_id": user_id}).execute()
        )
        conversation_id = conv_insert.data[0]["id"]

    now = datetime.utcnow().isoformat()

    # ── 2. Insert user message ──────────────────────────────────────────────
    user_msg = (
        supabase.table("messages")
        .insert(
            {
                "conversation_id": conversation_id,
                "sender": "user",
                "content": message,
                "created_at": now,
            }
        )
        .execute()
    )
    user_msg_id = user_msg.data[0]["id"]

    # ── 3. Insert emotion for user message ──────────────────────────────────
    if emotion:
        supabase.table("message_emotions").insert(
            {"message_id": user_msg_id, "emotion": emotion, "confidence": confidence}
        ).execute()

    # ── 4. Insert bot reply ─────────────────────────────────────────────────
    bot_msg = (
        supabase.table("messages")
        .insert(
            {
                "conversation_id": conversation_id,
                "sender": "bot",
                "content": reply,
                "created_at": now,  # same timestamp ≈ (in reality you'd use trigger or slight delay)
            }
        )
        .execute()
    )


def generate_reply(user_id: str, message: str):

    logger.info(f"User: {user_id} | Message: {message}")

    user_word_count = len(message.split())

    if user_word_count <= 5:
        length_instruction = "Reply in 1 short sentence."
    elif user_word_count <= 20:
        length_instruction = "Reply in 1-2 short sentences."
    else:
        length_instruction = "Reply in 2-4 sentences, still under 80 words."

    # 1️⃣ Detect emotion
    emotion_data = detect_emotion(message)
    emotion = emotion_data["emotion"]
    confidence = emotion_data["confidence"]

    logger.info(f"Detected emotion: {emotion}")

    tone_instruction = TONE_MAP.get(emotion, "Be emotionally present and natural.")
    logger.info(f"Tone selected: {tone_instruction}")

    # 🔴 Crisis check first
    if is_sensitive(message):
        crisis_reply = (
            "I'm really concerned about what you're feeling.\n\n"
            "You don’t have to go through this alone. "
            "If you're thinking about harming yourself, please reach out for help right now:\n\n"
            "📞 AASRA: +91-9820466726\n"
            "📞 iCALL: 9152987821\n\n"
            "You matter. Talking to someone can really help."
        )

        save_chat(user_id, message, crisis_reply, "crisis", 1.0)

        word_count = len(crisis_reply.split())
        typing_delay = min(max(word_count * 0.04, 0.8), 3.0)

        return {
            "reply": crisis_reply,
            "emotion": "crisis",
            "confidence": 1.0,
            "crisis_detected": True,
            "typing_delay": typing_delay,
        }

    # 3️⃣ Fetch last few messages (now formatted similarly to old structure)
    history = get_recent_history(user_id)[-3:]

    # 4️⃣ Build conversation context
    conversation_context = ""
    for chat in history:
        if chat["message"]:
            conversation_context += f"User said: {chat['message']}\n"
        if chat["reply"]:
            conversation_context += f"You replied: {chat['reply']}\n"

    style_variations = [
        "Be slightly casual and relaxed.",
        "Be emotionally warm but minimal.",
        "Be gentle and reflective.",
        "Be supportive but conversational.",
    ]

    random_style = random.choice(style_variations)

    # 5️⃣ Build prompt with memory
    prompt = f"""You are a warm, emotionally intelligent friend having a real conversation.

Previous conversation:
{conversation_context}

Current user message:
{message}

Guidelines:
{tone_instruction}
{random_style}
{length_instruction}
- Keep responses short (2-4 sentences, under 80 words).
- Sound natural, not like a therapist.
- Use simple everyday language.
- Use contractions (I'm, it's, that's).
- Avoid phrases like "It sounds like..."
- No long explanations.
- No motivational speeches.
- Do not give advice unless asked.
- Occasionally ask a gentle follow-up question.
- Occasionally use very short replies (1 sentence).
- Sometimes respond without a follow-up question.
- No introduction.

Reply naturally like someone who genuinely cares.
"""

    # 6️⃣ Generate LLM response
    reply = generate_llm_response(prompt)

    logger.info("LLM response generated")

    # 7️⃣ Save chat (user message + bot reply + emotion on user message)
    save_chat(user_id, message, reply, emotion, confidence)

    word_count = len(reply.split())
    typing_delay = min(max(word_count * 0.04, 0.8), 3.0)

    return {
        "reply": reply,
        "emotion": emotion,
        "confidence": confidence,
        "crisis_detected": False,
        "typing_delay": typing_delay,
    }


def get_full_history(user_id: str):
    conv_response = (
        supabase.table("conversations")
        .select("id")
        .eq("user_id", user_id)
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
        .order("created_at", asc=True)
        .execute()
    )

    return response.data if response.data else []


def get_daily_mood(user_id: str):
    # We'll join messages → message_emotions
    response = (
        supabase.table("messages")
        .select(
            "messages.created_at, message_emotions.emotion, message_emotions.confidence"
        )
        .join("message_emotions", "messages.id", "message_emotions.message_id")
        .eq("messages.sender", "user")  # only user messages
        .eq("messages.user_id", user_id)  # wait — no user_id in messages!
        # Problem: messages don't have user_id → need to go through conversation
        # For simplicity we filter via recent conversations, but this query needs adjustment
    )

    # Alternative (safer but two steps):
    conv_ids = (
        supabase.table("conversations").select("id").eq("user_id", user_id).execute()
    ).data

    if not conv_ids:
        return {"message": "No mood data available."}

    conv_ids_list = [c["id"] for c in conv_ids]

    today = datetime.utcnow().date().isoformat()

    emotions_data = (
        supabase.table("messages")
        .select("created_at, message_emotions.emotion, message_emotions.confidence")
        .join("message_emotions", "messages.id", "message_emotions.message_id")
        .in_("conversation_id", conv_ids_list)
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
        emotions_today.append(row["message_emotions"]["emotion"])
        confidences.append(row["message_emotions"]["confidence"])

    dominant_emotion = max(set(emotions_today), key=emotions_today.count)
    avg_confidence = sum(confidences) / len(confidences)

    return {
        "date": today,
        "dominant_emotion": dominant_emotion,
        "average_confidence": round(avg_confidence, 3),
        "total_messages": len(emotions_today),
    }


def get_emotion_timeline(user_id: str):
    # Similar join logic — getting all user messages with emotions
    conv_response = (
        supabase.table("conversations").select("id").eq("user_id", user_id).execute()
    )
    if not conv_response.data:
        return {"message": "No emotion data available."}

    conv_ids = [c["id"] for c in conv_response.data]

    response = (
        supabase.table("messages")
        .select("created_at, message_emotions.emotion")
        .join("message_emotions", "messages.id", "message_emotions.message_id")
        .in_("conversation_id", conv_ids)
        .eq("sender", "user")
        .execute()
    )

    if not response.data:
        return {"message": "No emotion data available."}

    daily_emotions = defaultdict(list)

    for row in response.data:
        date = (
            datetime.fromisoformat(row["created_at"].replace("Z", ""))
            .date()
            .isoformat()
        )
        daily_emotions[date].append(row["message_emotions"]["emotion"])

    timeline = []
    for date, emotions in daily_emotions.items():
        dominant = max(set(emotions), key=emotions.count)
        timeline.append({"date": date, "dominant_emotion": dominant})

    timeline.sort(key=lambda x: x["date"])

    return timeline


def get_weekly_insight(user_id: str):
    # Similar approach — fetch last 7 days user messages + emotions
    today = datetime.utcnow()
    week_ago = today - timedelta(days=7)

    conv_response = (
        supabase.table("conversations").select("id").eq("user_id", user_id).execute()
    )
    if not conv_response.data:
        return {"message": "No weekly data available."}

    conv_ids = [c["id"] for c in conv_response.data]

    response = (
        supabase.table("messages")
        .select("created_at, message_emotions.emotion, message_emotions.confidence")
        .join("message_emotions", "messages.id", "message_emotions.message_id")
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
        weekly_emotions.append(row["message_emotions"]["emotion"])
        weekly_confidences.append(row["message_emotions"]["confidence"])

    emotion_counts = Counter(weekly_emotions)
    emotion_summary = "\n".join([f"{e}: {c}" for e, c in emotion_counts.items()])

    avg_confidence = sum(weekly_confidences) / len(weekly_confidences)

    prompt = f"""
You are an emotional wellness AI analyst.

User emotional data for the last 7 days:
{emotion_summary}

Average emotional intensity score: {round(avg_confidence, 3)}

Generate a compassionate weekly emotional insight.
Keep it supportive and reflective.
Do not introduce yourself.
"""

    insight = generate_llm_response(prompt)

    return {
        "weekly_emotion_counts": dict(emotion_counts),  # serializable
        "average_confidence": round(avg_confidence, 3),
        "weekly_insight": insight,
    }


def create_journal_entry(user_id: str, entry: str):
    emotion_data = detect_emotion(entry)
    emotion = emotion_data["emotion"]
    confidence = emotion_data["confidence"]

    prompt = f"""
You are an emotional reflection assistant.

User journal entry:
{entry}

Detected emotion: {emotion}

Generate a concise (4-5 sentence) supportive journal reflection.
Keep it grounded and emotionally intelligent.
Do not introduce yourself.
"""

    ai_summary = generate_llm_response(prompt)

    supabase.table("journal_entries").insert(
        {
            "user_id": user_id,
            "entry": entry,
            "emotion": emotion,
            "confidence": confidence,
            "ai_summary": ai_summary,
        }
    ).execute()

    return {"emotion": emotion, "confidence": confidence, "ai_summary": ai_summary}
