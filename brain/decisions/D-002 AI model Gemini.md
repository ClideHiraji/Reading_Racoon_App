---
type: decision
status: decided
date: 2026-10-17
issue: 2
graphify: submitted
tags: [decision, ai]
---

# D-002 AI model: Google Gemini

**Decision:** the **Google Gemini API** with a Flash / Flash-Lite model (exact model ID pinned in `.env`). It's paid with the ~US$10/month Google Cloud credits in our Google AI Pro subscription and called **only from Laravel**, through Gemini's OpenAI-compatible endpoint.

**Why**
- We already pay for Google AI Pro, so the AI costs about nothing. The whole study needs roughly US$5 of usage.
- It's fast and handles English and Filipino well.

**Rules**
- Never call the AI from the Godot app. The key would ship inside the APK.
- Use paid (billing-enabled) terms, not the free tier, because this is children's data under RA 10173.
- Prompts carry student codes and scores only, never names.
- Raccoon lines time out at about 1.5 s and fall back to a built-in library. Teacher reports run as background jobs with a template fallback.

**Superseded:** gpt-oss-20b on Groq (picked earlier the same day).

Details: [[08-ai-integration]], [[Gemini subscription vs API credits]], [[10-open-issues]] issue 2.
