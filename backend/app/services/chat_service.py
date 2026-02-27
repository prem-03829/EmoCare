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
    "hurt myself"
]


TONE_MAP = {
    "sadness": "Be soft and comforting.",
    "anger": "Be calm and grounding.",
    "joy": "Match their excitement.",
    "fear": "Be reassuring and steady."
}

def is_crisis(message: str) -> bool:
    message_lower = message.lower()
    return any(keyword in message_lower for keyword in CRISIS_KEYWORDS)


def get_recent_history(user_id: str):
    response = (
        supabase.table("chat_history")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(settings.CHAT_HISTORY_LIMIT)
        .execute()
    )

    if response.data:
        # reverse so oldest comes first
        return list(reversed(response.data))

    return []


def save_chat(user_id, message, reply, emotion, confidence):
    supabase.table("chat_history").insert({
        "user_id": user_id,
        "message": message,
        "reply": reply,
        "emotion": emotion,
        "confidence": confidence
    }).execute()

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


    tone_instruction = TONE_MAP.get(emotion,"Be emotionally present and natural.")
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
            "typing_delay": typing_delay
        }


    # 3️⃣ Fetch last 5 messages
    history = get_recent_history(user_id)[-3:]

    # 4️⃣ Build conversation context
    conversation_context = ""
    for chat in history:
        conversation_context += f"User said: {chat['message']}\n"
        conversation_context += f"You replied: {chat['reply']}\n"

    style_variations = [
        "Be slightly casual and relaxed.",
        "Be emotionally warm but minimal.",
        "Be gentle and reflective.",
        "Be supportive but conversational."
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

    # 7️⃣ Save chat to database
    save_chat(user_id, message, reply, emotion, confidence)

    word_count = len(reply.split())
    typing_delay = min(max(word_count * 0.04, 0.8), 3.0)

    return {
        "reply": reply,
        "emotion": emotion,
        "confidence": confidence,
        "crisis_detected": False,
        "typing_delay" : typing_delay
    }


def get_full_history(user_id: str):
    response = (
        supabase.table("chat_history")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=False)
        .execute()
    )

    return response.data if response.data else []    


def get_daily_mood(user_id: str):
    response = (
        supabase.table("chat_history")
        .select("emotion, confidence, created_at")
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        return {"message": "No mood data available."}

    today = datetime.utcnow().date()

    emotions_today = []
    confidences = []

    for row in response.data:
        created_date = datetime.fromisoformat(row["created_at"].replace("Z", "")).date()

        if created_date == today:
            emotions_today.append(row["emotion"])
            confidences.append(row["confidence"])

    if not emotions_today:
        return {"message": "No mood data for today."}

    dominant_emotion = max(set(emotions_today), key=emotions_today.count)
    avg_confidence = sum(confidences) / len(confidences)

    return {
        "date": str(today),
        "dominant_emotion": dominant_emotion,
        "average_confidence": round(avg_confidence, 3),
        "total_messages": len(emotions_today)
    }



def get_emotion_timeline(user_id: str):

    response = (
        supabase.table("chat_history")
        .select("emotion, created_at")
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        return {"message": "No emotion data available."}

    daily_emotions = defaultdict(list)

    for row in response.data:
        date = datetime.fromisoformat(
            row["created_at"].replace("Z", "")
        ).date()

        daily_emotions[str(date)].append(row["emotion"])

    timeline = []

    for date, emotions in daily_emotions.items():
        dominant_emotion = max(set(emotions), key=emotions.count)

        timeline.append({
            "date": date,
            "dominant_emotion": dominant_emotion
        })

    timeline.sort(key=lambda x: x["date"])

    return timeline




def get_weekly_insight(user_id: str):

    response = (
        supabase.table("chat_history")
        .select("emotion, confidence, created_at")
        .eq("user_id", user_id)
        .execute()
    )

    if not response.data:
        return {"message": "No weekly data available."}

    today = datetime.utcnow()
    week_ago = today - timedelta(days=7)

    weekly_emotions = []
    weekly_confidences = []

    for row in response.data:
        created_at = datetime.fromisoformat(
            row["created_at"].replace("Z", "")
        )

        if created_at >= week_ago:
            weekly_emotions.append(row["emotion"])
            weekly_confidences.append(row["confidence"])

    if not weekly_emotions:
        return {"message": "No activity in last 7 days."}

    emotion_counts = Counter(weekly_emotions)

    emotion_summary = "\n".join(
        [f"{emotion}: {count}" for emotion, count in emotion_counts.items()]
    )

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
        "weekly_emotion_counts": emotion_counts,
        "average_confidence": round(avg_confidence, 3),
        "weekly_insight": insight
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

    supabase.table("journal_entries").insert({
        "user_id": user_id,
        "entry": entry,
        "emotion": emotion,
        "confidence": confidence,
        "ai_summary": ai_summary
    }).execute()

    return {
        "emotion": emotion,
        "confidence": confidence,
        "ai_summary": ai_summary
    }

