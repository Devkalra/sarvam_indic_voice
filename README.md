# 🍛 Sarvam Indic Voice-to-UI — Food Delivery Clone
> **Proof-of-Work** for Sarvam AI DevRel Interview

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
                                             │  saarika:v2 (hi-IN)  │
                                             └──────────────────────┘
```

---

## 1 — Backend Setup

```bash
cd backend/

# Create virtual environment
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set your Sarvam API key (get it from https://dashboard.sarvam.ai)
export SARVAM_API_KEY="your_key_here"

# Run the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Visit **http://localhost:8000/docs** for interactive Swagger UI.

Test the endpoint manually:
```bash
curl -X POST http://localhost:8000/process-voice \
  -F "file=@sample_hindi.wav"
```

---

## 2 — Flutter App Setup

```bash
cd flutter_app/

# Get dependencies
flutter pub get

# Run on Android emulator (uses 10.0.2.2 to reach host localhost)
flutter run

# Run on physical device (change kBackendBaseUrl in voice_controller.dart)
# e.g., const kBackendBaseUrl = 'http://192.168.1.100:8000';
```

### Android Permissions
Copy the permissions from `android_manifest_reference.xml` into:
`android/app/src/main/AndroidManifest.xml`

Required:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
And add `android:usesCleartextTraffic="true"` to the `<application>` tag for local HTTP.

### iOS Permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Needed to capture your Hindi voice order</string>
```

---

## 3 — File Structure

```
sarvam_indic_voice/
├── backend/
│   ├── main.py              ← FastAPI server (heavily commented)
│   └── requirements.txt
│
└── flutter_app/
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart            ← App entry, theme setup
    │   ├── cart_model.dart      ← State: CartModel + MenuItem catalogue
    │   ├── voice_controller.dart ← Audio recording + API calls
    │   └── home_screen.dart     ← All UI widgets
    └── android_manifest_reference.xml
```

---

## 4 — Demo Script (for interview)

1. Launch backend: `uvicorn main:app --reload`
2. Launch Flutter app on emulator
3. Say: **"Ek chicken biryani aur do coke add kar do"**
4. The grid cards highlight with animated badges
5. Open the **Activity Log** (terminal icon, top-right) to show raw JSON:
   ```json
   {
     "success": true,
     "detected_item": "Chicken Biryani",
     "quantity": 1,
     "raw_transcript": "एक चिकन बिरयानी और दो कोक ऐड कर दो",
     "all_detected_items": [
       {"item": "Chicken Biryani", "quantity": 1},
       {"item": "Coca-Cola", "quantity": 2}
     ],
     "sarvam_model": "saarika:v2"
   }
   ```

---

## 5 — Extending the App

| What | Where |
|------|-------|
| Add menu items | `kMenuItems` list in `cart_model.dart` |
| Add food keywords | `MENU_KEYWORDS` dict in `main.py` |
| Add Hindi numbers | `HINDI_NUMBERS` dict in `main.py` |
| Change backend URL | `kBackendBaseUrl` in `voice_controller.dart` |
| Change STT language | `language_code` in `call_sarvam_stt()` in `main.py` |

---

## Sarvam AI APIs Used

| API | Model | Purpose |
|-----|-------|---------|
| Speech-to-Text | `saarika:v2` | Hindi audio → transcript |

Docs: https://docs.sarvam.ai


## To Restart the backend:
cd backend
.venv\Scripts\Activate.ps1
$env:SARVAM_API_KEY="your_actual_key_here"
uvicorn main:app --reload --host 0.0.0.0 --port 8000