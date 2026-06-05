# 🍛 Sarvam Indic Voice-to-UI

Speak naturally in **Hindi / Hinglish** and watch your cart update instantly.

---
## Architecture
```
┌─────────────────────┐      WAV file       ┌──────────────────────┐
│   Flutter App       │ ──POST /process──▶  │  FastAPI Backend     │
│                     │                     │                      │
│  • Food Grid UI     │ ◀── JSON response ─ │  • Sarvam STT call   │
│  • Mic FAB          │                     │  • Keyword parser    │
│  • Activity Log     │                     │  • Returns cart JSON │
└─────────────────────┘                     └──────────────────────┘
                                                        │
                                                        ▼
                                             ┌──────────────────────┐
                                             │  Sarvam AI STT API   │
                                             │  saarika:v2.5 (hi-IN)│
                                             └──────────────────────┘
```

## 1 — File Structure

```
sarvam_indic_voice/
├── backend/
│   ├── main.py              ← FastAPI server 
│   └── requirements.txt
│
└── flutter_app/
    ├── pubspec.yaml
    ├── lib/
        ├── main.dart            
        ├── cart_model.dart      
        ├── voice_controller.dart 
        └── home_screen.dart     
```

---

## Sarvam AI APIs Used

| API | Model | Purpose |
|-----|-------|---------|
| Speech-to-Text | `saarika:v2.5` | Hindi audio → transcript |

Docs: https://docs.sarvam.ai
