from transformers import pipeline
from app.core.logger import logger

_emotion_pipeline = None

GREETINGS = {"hi", "hello", "hey", "hii", "yo", "sup", "ok", "okay", "hmm"}

def get_pipeline():
    global _emotion_pipeline
    if _emotion_pipeline is None:
        logger.info("Loading emotion model...")
        _emotion_pipeline = pipeline(
            "text-classification",
            model="nateraw/bert-base-uncased-emotion"
        )
    return _emotion_pipeline


def detect_emotion(text: str):
    try:
        text_clean = text.strip().lower()

        # 🔹 1. Ignore empty or very short text
        if len(text_clean) < 8:
            return {
                "emotion": "neutral",
                "confidence": 0.0
            }

        # 🔹 2. Ignore 1-2 word messages
        if len(text_clean.split()) < 3:
            return {
                "emotion": "neutral",
                "confidence": 0.0
            }

        # 🔹 3. Ignore greetings
        if text_clean in GREETINGS:
            return {
                "emotion": "neutral",
                "confidence": 0.0
            }

        # 🔹 4. Run model
        result = get_pipeline()(text_clean)[0]

        # 🔹 5. Confidence threshold (very important)
        if result["score"] < 0.6:
            return {
                "emotion": "neutral",
                "confidence": round(result["score"], 3)
            }

        return {
            "emotion": result["label"].lower(),
            "confidence": round(result["score"], 3)
        }

    except Exception as e:
        logger.error(f"Emotion detection failed: {e}")
        return {
            "emotion": "unknown",
            "confidence": 0.0
        }
"""    
from transformers import pipeline

emotion_classifier = pipeline(
    "text-classification",
    model="j-hartmann/emotion-english-distilroberta-base",
    return_all_scores=False
)

def detect_emotion(text: str):
    result = emotion_classifier(text)[0]
    return {
        "emotion": result["label"],
        "confidence": round(result["score"], 3)
    }

"""


