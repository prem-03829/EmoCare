from transformers import pipeline
from app.core.logger import logger

_emotion_pipeline = None

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
        result = get_pipeline()(text)[0]
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
