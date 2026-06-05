import os
import re
import json
import httpx                      # async-friendly HTTP client
import tempfile
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# ─── App Bootstrap ────────────────────────────────────────────────────────────

app = FastAPI(
    title="Sarvam Indic Voice-to-UI Bridge",
    description="Accepts audio from Flutter, calls Sarvam STT, parses Hindi/Hinglish food orders.",
    version="1.0.0",
)

# ─── CORS — allow Flutter (mobile / web) and local dev ────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # ⚠️ Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Config / Secrets (use env-vars; never hardcode in production) ─────────────
SARVAM_API_KEY: str = os.getenv("SARVAM_API_KEY", "YOUR_API_SUBSCRIPTION_KEY_HERE")


SARVAM_STT_URL: str = "https://api.sarvam.ai/speech-to-text"

# ─── Menu Catalogue ───────────────────────────────────────────────────────────
# Maps every keyword/alias a user might say (Hindi or English) to a canonical
# item name that Flutter will render in the cart.
#
# Extend this dict to add more menu items instantly.
MENU_KEYWORDS: dict[str, str] = {
    # ── Biryani ──────────────────────────────────────────────────────────
    "biryani":          "Chicken Biryani",
    "biriyani":         "Chicken Biryani",
    "chicken biryani":  "Chicken Biryani",
    "चिकन बिरयानी":    "Chicken Biryani",
    "चिकन बिरियानी":   "Chicken Biryani",
    "बिरयानी":          "Chicken Biryani",
    "बिरियानी":         "Chicken Biryani",
    "veg biryani":      "Veg Biryani",
    "वेज बिरयानी":      "Veg Biryani",

    # ── Pizza ─────────────────────────────────────────────────────────────
    "pizza":            "Veg Pizza",
    "veg pizza":        "Veg Pizza",
    "पिज्जा":           "Veg Pizza",
    "वेज पिज्जा":       "Veg Pizza",
    "paneer pizza":     "Paneer Pizza",
    "पनीर पिज्जा":      "Paneer Pizza",

    # ── Drinks ────────────────────────────────────────────────────────────
    "coke":             "Coca-Cola",
    "coca cola":        "Coca-Cola",
    "cola":             "Coca-Cola",
    "कोक":              "Coca-Cola",
    "कोला":             "Coca-Cola",
    "pepsi":            "Pepsi",
    "पेप्सी":           "Pepsi",
    "lassi":            "Mango Lassi",
    "mango lassi":      "Mango Lassi",
    "लस्सी":            "Mango Lassi",
    "मैंगो लस्सी":      "Mango Lassi",

    # ── Burger ────────────────────────────────────────────────────────────
    "burger":           "Veg Burger",
    "veg burger":       "Veg Burger",
    "बर्गर":            "Veg Burger",
    "वेज बर्गर":        "Veg Burger",
    "chicken burger":   "Chicken Burger",
    "चिकन बर्गर":       "Chicken Burger",

    # ── Wraps ─────────────────────────────────────────────────────────────
    "wrap":             "Paneer Wrap",
    "paneer wrap":      "Paneer Wrap",
    "रैप":              "Paneer Wrap",
    "पनीर रैप":         "Paneer Wrap",

    # ── Sides ─────────────────────────────────────────────────────────────
    "fries":            "French Fries",
    "french fries":     "French Fries",
    "फ्राइज":           "French Fries",
    "naan":             "Butter Naan",
    "नान":              "Butter Naan",
    "butter naan":      "Butter Naan",
    "बटर नान":          "Butter Naan",
    "roti":             "Tandoori Roti",
    "रोटी":             "Tandoori Roti",
    "dal":              "Dal Makhani",
    "दाल":              "Dal Makhani",
    "dal makhani":      "Dal Makhani",
    "दाल मखनी":         "Dal Makhani",
    "paneer":           "Paneer Butter Masala",
    "पनीर":             "Paneer Butter Masala",

    # ── Desserts ──────────────────────────────────────────────────────────
    "gulab jamun":      "Gulab Jamun",
    "गुलाब जामुन":      "Gulab Jamun",
    "ice cream":        "Ice Cream",
    "आइसक्रीम":         "Ice Cream",
    "आइस क्रीम":        "Ice Cream",
}

# ─── Hindi/Hinglish Number Words ──────────────────────────────────────────────
# Maps spoken Hindi number words to integers.
HINDI_NUMBERS: dict[str, int] = {
    "ek":    1,   "एक":   1,
    "do":    2,   "दो":   2,
    "teen":  3,   "तीन":  3,
    "char":  4,   "चार":  4,
    "paanch":5,   "पांच": 5,
    "chhe":  6,   "छह":   6,
    "saat":  7,   "सात":  7,
    "aath":  8,   "आठ":   8,
    "nau":   9,   "नौ":   9,
    "das":  10,   "दस":  10,
    "ek ek": 1,   # colloquial "one each"
}

# ─── Response Schema ──────────────────────────────────────────────────────────

class VoiceResponse(BaseModel):
    success: bool
    detected_item: Optional[str] = None
    quantity: int = 1
    raw_transcript: str = ""
    message: str = ""
    # Extra diagnostics shown in the Flutter "Activity Log" drawer
    all_detected_items: list[dict] = []   # [{item, qty}, ...] — full parse
    sarvam_model: str = ""                # model returned by Sarvam
    audio_duration_sec: Optional[float] = None

# ─── Keyword Parser ───────────────────────────────────────────────────────────

def parse_transcript(transcript: str) -> list[dict]:
    """
    Scans the STT transcript for food item keywords and their quantities.

    Strategy:
      1. Lowercase + normalise the transcript.
      2. Try to find a NUMBER token (Hindi or digit) immediately BEFORE a
         menu keyword.  If found, use that as the quantity.
      3. If no number precedes the item, default quantity = 1.
      4. Longer keyword phrases are matched first (greedy match) so
         "chicken biryani" beats a standalone "biryani" match.

    Returns a list like:
        [{"item": "Chicken Biryani", "quantity": 2}, ...]
    """
    text = transcript.lower().strip()
    results: list[dict] = []
    already_matched_spans: list[tuple[int, int]] = []

    # Sort keywords longest-first so multi-word phrases get priority
    sorted_keywords = sorted(MENU_KEYWORDS.keys(), key=len, reverse=True)

    for keyword in sorted_keywords:
        # Build a word-boundary-aware regex for the keyword
        pattern = re.compile(r'\b' + re.escape(keyword) + r'\b')
        for match in pattern.finditer(text):
            span = match.span()

            # Skip if this span is already covered by a longer match
            if any(s <= span[0] and span[1] <= e for s, e in already_matched_spans):
                continue

            # --- Quantity detection ---
            # Look at the 30 characters BEFORE the keyword for a number token
            prefix = text[max(0, span[0] - 30): span[0]]
            quantity = _extract_number(prefix)

            canonical_name = MENU_KEYWORDS[keyword]
            results.append({"item": canonical_name, "quantity": quantity})
            already_matched_spans.append(span)

    return results


def _extract_number(text_snippet: str) -> int:
    """
    Extracts the LAST number token found in a short text snippet.
    Checks Hindi word-numbers first, then Arabic digits.
    Returns 1 (default) if nothing is found.
    """
    tokens = text_snippet.split()

    # Walk tokens in reverse to find the closest number before the item
    for token in reversed(tokens):
        token_clean = re.sub(r'[^\w]', '', token)
        if token_clean in HINDI_NUMBERS:
            return HINDI_NUMBERS[token_clean]
        if token_clean.isdigit():
            return int(token_clean)

    return 1  # default quantity


# ─── Sarvam STT Helper ────────────────────────────────────────────────────────

async def call_sarvam_stt(audio_bytes: bytes, filename: str) -> dict:
    """
    Sends audio bytes to Sarvam AI's Speech-to-Text API.

    Sarvam STT API reference:
      POST https://api.sarvam.ai/speech-to-text
      Headers:
        api-subscription-key: <YOUR_KEY>
      Body (multipart/form-data):
        file:        <audio file>
        model:       saarika:v2.5   (Hindi-optimised model)
        language_code: hi-IN
        with_timestamps: false

    Returns the parsed JSON body on success.
    Raises HTTPException on failure.
    """
    headers = {
        "api-subscription-key": SARVAM_API_KEY,
    }

    # Determine MIME type from file extension
    mime = "audio/wav"
    if filename.lower().endswith(".m4a"):
        mime = "audio/m4a"
    elif filename.lower().endswith(".mp3"):
        mime = "audio/mpeg"
    elif filename.lower().endswith(".ogg"):
        mime = "audio/ogg"

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            SARVAM_STT_URL,
            headers=headers,
            files={
                "file": (filename, audio_bytes, mime),
            },
            data={
                "model": "saarika:v2.5",          # Sarvam's Hindi-optimised model
                "language_code": "hi-IN",        # Explicitly request Hindi
                "with_timestamps": "false",
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Sarvam STT API error {response.status_code}: {response.text}",
        )

    return response.json()


# ─── Main Endpoint ────────────────────────────────────────────────────────────

@app.post("/process-voice", response_model=VoiceResponse)
async def process_voice(file: UploadFile = File(...)):
    """
    Main endpoint consumed by the Flutter app.

    Flow:
      1. Read uploaded audio bytes.
      2. Call Sarvam STT API → get Hindi transcript.
      3. Run keyword parser on transcript.
      4. Return structured JSON to Flutter.

    Expected multipart field name: "file"
    """
    # --- 1. Read audio bytes from the upload --------------------------------
    audio_bytes = await file.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded audio file is empty.")

    # --- 2. Call Sarvam STT -------------------------------------------------
    try:
        sarvam_response = await call_sarvam_stt(audio_bytes, file.filename or "audio.wav")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"STT call failed: {str(exc)}")

    # Sarvam returns: {"transcript": "...", "language_code": "hi-IN", "model": "..."}
    transcript: str = sarvam_response.get("transcript", "")
    model_used: str = sarvam_response.get("model", "saarika:v2.5")

    if not transcript:
        return VoiceResponse(
            success=False,
            raw_transcript="",
            message="Sarvam STT returned an empty transcript. Please speak clearly and retry.",
        )

    # --- 3. Parse transcript for food items ---------------------------------
    detected_items = parse_transcript(transcript)

    if not detected_items:
        return VoiceResponse(
            success=False,
            raw_transcript=transcript,
            message="No menu items detected in the transcript. Try saying items like biryani, pizza, coke.",
            sarvam_model=model_used,
        )

    # Primary item = first detected (most prominent in the utterance)
    primary = detected_items[0]

    return VoiceResponse(
        success=True,
        detected_item=primary["item"],
        quantity=primary["quantity"],
        raw_transcript=transcript,
        message=f"Detected {len(detected_items)} item(s) in your order.",
        all_detected_items=detected_items,
        sarvam_model=model_used,
    )


# ─── Health Check ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Simple liveness probe — useful for Docker / GCP health checks."""
    return {"status": "ok", "service": "sarvam-indic-voice-bridge"}


# ─── Dev runner ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    # Run with:  python main.py
    # Or:        uvicorn main:app --reload --host 0.0.0.0 --port 8000
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
