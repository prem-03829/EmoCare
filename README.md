## EmoCare

EmoCare is a emotion aware mental wellness assistant that uses ML/LLM to suggest basic mental activities when input given through text or voice.
- a Flutter client (`frontend/app`)
- a FastAPI backend (`backend`)
- Supabase for auth and data
- local AI services for chat, emotion detection, translation, and voice transcription

## Features

- Text chat with emotionally adaptive replies
- Voice-to-chat flow (Whisper STT)
- Emotion detection on user messages
- Multilingual language handling and translation fallback
- Crisis keyword safety response
- Mood insights:
  - today’s dominant mood
  - emotion timeline
  - weekly summary insight
- Supabase login in the app (guest mode also supported)

## Tech Stack

### Frontend: 
- Flutter (Dart)
### Backend: 
- FastAPI
- Uvicorn
- Pydantic
### AI/ NLP:
- Hugging face transformers
- Ollama (phi-3 local LLM)
- Sentences-Transformers
- PyTorch
- spaCy
- Whisper
### Database: 
- Supabase (PostgreSQL)
### Tools:
- Python
- Git
- dotenv

## Project Structure

```text
EmoCare-final/
│
├── backend/
│   ├── app/
│   │   ├── api/                  # FastAPI routes + Ollama integration
│   │   ├── services/             # Chat, voice, translation logic
│   │   ├── core/                 # Config, logger, Supabase client
│   │   ├── models.py
│   │   └── main.py               # FastAPI entry point
│   │
│   ├── pyproject.toml
│   ├── requirements.txt
│   └── .env
│
├── frontend/
│   └── app/
│       ├── assets/
│       │   └── Logo.png
│       │
│       ├── lib/
│       │   ├── config/           # App configuration
│       │   ├── screens/          # Chat, Settings, Splash
│       │   ├── services/         # API + voice services
│       │   ├── utils/            # Helper functions
│       |   └── main.dart
│       │    
│       ├── pubspec.yaml
│
└── README.md
```

## Prerequisites

- Python 3.11+
- Flutter SDK (compatible with Dart `>=3.2.0 <4.0.0`)
- FFmpeg (for audio transcription)
- Ollama running locally (`http://localhost:11434`)
- Supabase project (URL + service key for backend)

## Backend Setup (FastAPI)

From `backend/`:

1. Create environment and install deps:
```bash
# Option A: uv (recommended if installed)
uv sync

# Option B: pip
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirement.txt
```

2. Create `.env` in `backend/`:
```env
APP_NAME=Emotion AI Backend
DEBUG=true

OLLAMA_MODEL=phi3
OLLAMA_TIMEOUT_SECONDS=300
OLLAMA_MAX_TOKENS=120
CHAT_HISTORY_LIMIT=4

WHISPER_MODEL=base
FFMPEG_PATH=C:\ffmpeg\bin

SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_service_role_key
SUPABASE_JWT_SECRET=your_jwt_secret_if_used
```

3. Start backend:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

4. (Optional) Install Argos translation packages:
```bash
python -m app.models
```

## Frontend Setup (Flutter)

From `frontend/app/`:

1. Install dependencies:
```bash
flutter pub get
```

2. Run app (set backend URL):
```bash
flutter run --dart-define=API_BASE_URL=http://<YOUR_LOCAL_IP>:8000
```

Optional override:
```bash
flutter run --dart-define=API_USER_ID=prem
```

## API Overview

Base URL: `http://localhost:8000`

- `GET /` -> service info
- `GET /ping` -> health ping
- `GET /time` -> server time

Chat:
- `POST /chat` (or `/chat/send`) body: `{ "user_id": "...", "message": "..." }`
- `GET /chat/history?user_id=...`
- `GET /chat/mood/today?user_id=...`
- `GET /chat/timeline?user_id=...`
- `GET /chat/weekly-insight?user_id=...`
- `GET /chat/auto-journal?user_id=...`

Voice:
- `POST /` multipart form: `user_id`, `file`

## Supabase Tables Used

Backend code expects these tables:
- `users` (`id`, `username`)
- `conversations` (`id`, `user_id`, `started_at`)
- `messages` (`id`, `conversation_id`, `sender`, `content`, `created_at`)
- `message_emotions` (`message_id`, `emotion`, `confidence`)

## Notes

- Current frontend includes hardcoded Supabase URL/anon key in `frontend/app/lib/config/supabase_config.dart`.
- For production, move secrets/config to secure environment management.
- Ensure Ollama model is pulled before use:
```bash
ollama pull phi3
```

## License

MIT (see `LICENSE`).
