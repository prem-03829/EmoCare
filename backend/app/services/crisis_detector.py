from sentence_transformers import SentenceTransformer, util
import torch

# Load model once (important)
model = SentenceTransformer('all-MiniLM-L6-v2')

CRISIS_EXAMPLES = [
    "I want to kill myself",
    "I don't want to live anymore",
    "Life is not worth living",
    "I feel like ending everything",
    "I wish I could disappear",
    "There is no reason to live",
    "I feel hopeless and trapped",
]

example_embeddings = model.encode(CRISIS_EXAMPLES, convert_to_tensor=True)


def is_crisis(message: str, threshold: float = 0.75) -> bool:
    message_embedding = model.encode(message, convert_to_tensor=True)
    scores = util.cos_sim(message_embedding, example_embeddings)
    max_score = torch.max(scores).item()
    return max_score > threshold
