from rapidfuzz import fuzz

THRESHOLD = 60

DANGER_PHRASES = [
    "suicide",
    "kill myself",
    "i want to die",
    "end my life",
    "take my life",
    "self harm",
    "hurt myself",
    "cut myself",
    "hang myself",
    "poison myself",
    "i dont want to live",
    "life is pointless",
    "no reason to live",
    "i give up on life",
    "i cant live anymore",
    "better off dead",
    "wish i was dead",
    "i feel hopeless",
    "i feel empty",
    "i hate my life",
    "nothing matters",
    "i am tired of living"
]

def is_sensitive(text):
    text = text.lower().strip()
    words = text.split()

    # 🔹 Check full phrases first
    for phrase in DANGER_PHRASES:
        if fuzz.partial_ratio(text, phrase) >= THRESHOLD:
            return True

    # 🔹 Check individual words (important for "sucidie")
    for word in words:
        if fuzz.ratio(word, "suicide") >= THRESHOLD:
            return True

    return False
