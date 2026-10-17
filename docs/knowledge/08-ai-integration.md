# 08 — AI (LLM) Integration

## Two LLM tasks
1. **Teacher report generation.** Turns a student's BKT mastery (5 sub-skills), session history and error patterns into a plain-language, MATATAG-aligned diagnostic summary (strengths, gaps, suggested intervention). Generated after each session and shown on the dashboard. Exportable to PDF.
2. **Companion dialogue generation.** Short, cheerful, age-appropriate raccoon lines for four states: **correct answer, incorrect answer, level up, session end**, plus hints when P(L) < 0.30 and encouragement during Heart Recovery. Shown in a speech bubble **within 2 seconds**.

## Prompt design (MLDLC Stage 3)
Each prompt template has a role definition, a BKT JSON data-injection block, and length/terminology constraints.

| Prompt | temperature | max_tokens | Output |
|---|---|---|---|
| Teacher Report | **0.3** | **250** | Two-paragraph MATATAG-aligned diagnostic summary |
| Companion Dialogue | **0.7** | **60** | One short raccoon-themed line |

## Machine Learning Development Life Cycle (6 stages)
1. **Problem definition**: the two tasks above.
2. **Data collection**: 50 sample BKT JSON inputs paired with teacher-written summaries; 120 researcher-written dialogue samples (4 states × 5 levels).
3. **Prompt engineering / fine-tuning**: system prompts, few-shot examples from the dataset.
4. **Evaluation**: teachers rate reports (accuracy, MATATAG alignment); researchers rate dialogue (age-appropriateness, tone) on a 5-point Likert scale. **Accept when weighted mean ≥ 4.0** per dimension, otherwise revise and retest. WM = Σ(scale × freq) / N.
5. **Integration**: async HTTP calls. Reports go after the session, dialogue at BKT decision points. A **local fallback dialogue library** covers offline play.
6. **Monitoring**: log every output with timestamp + input. Store outputs in the PostgreSQL `ai_logs` table. Prompts live on the server (Laravel), so they can be revised without rebuilding the app.

## Model and hosting (decided 2026-10-17, open issue 2)
- **Model:** Google **Gemini**, a cost-efficient **Flash / Flash-Lite** model. Pin the exact model ID from Google's current model list in `.env`, and don't rely on a "latest" alias, so outputs stay consistent during the study.
- **Billing:** the **Google Cloud credits included in the team's Google AI Pro subscription** (~US$10/month), applied to a **billing-enabled** Google Cloud project. Create the API key in Google AI Studio under that project.
- **Caller:** Laravel only. Unity calls our own API (`POST /api/companion/dialogue`), never Gemini. Thesis Stage 5 says Unity calls the LLM directly. Change that, because the key would ship inside the APK.

### Laravel config
Gemini offers an **OpenAI-compatible endpoint**, so the code stays provider-neutral:
```env
LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
LLM_API_KEY=...            # Gemini API key; never commit; never send to the client
LLM_MODEL=gemini-...       # exact Flash / Flash-Lite model ID from Google's model list
```
Use Laravel's `Http` facade (or `openai-php/laravel` with a custom base URL). Alternatively, call the native Gemini REST API (`generateContent`), which exposes Gemini-specific settings such as safety filters more directly. Changing provider later means changing these three values.

### Call patterns
| Task | How | Timeout | Fallback |
|---|---|---|---|
| Companion dialogue | Synchronous request from Unity → Laravel → Gemini | **~1.5 s** to the LLM, so the 2 s UI target holds | Random line from the bundled local library for that state + level |
| Teacher report | **Queued job** after a session syncs. Store in `ai_reports` | 30 s, 2 retries | Template report built from the BKT numbers |

### Gemini gotchas
- Some newer Gemini models **"think"** before answering. Thinking tokens add latency and can use up a small `max_tokens` budget (the thesis limits of 60 / 250). For dialogue, turn thinking off or to the minimum the model allows (on the OpenAI-compatible endpoint, `reasoning_effort: "low"`/`"none"` where supported). Leave `max_tokens` headroom, and enforce the visible length through the prompt plus server-side trimming. Keep the thesis temperatures (0.7 / 0.3).
- **Safety filters** may block some outputs. Treat an empty or blocked response as a failure and use the fallback.
- **Rate limits** apply per project. 62 students in one class can send bursts, so cache common dialogue (same state + level) for a few minutes and queue reports.
- Validate output before saving or showing it: non-empty, within the length limit, no names, sub-skill names and numbers match the input JSON (reports). If validation fails, use the fallback.

### Cost estimate (whole 4-month study)
Assume 62 students × ~3 sessions/week × ~16 weeks ≈ 3,000 reports (~1.75k tokens each) + ~60,000 dialogue calls (~0.5k tokens each) ≈ **30M input + 5M output tokens**. At typical Flash-Lite / Flash pricing that's a few US dollars in total, well inside ~$10/month of credits. Check the current price on Google's Gemini API pricing page before quoting a number in the thesis, and set a **budget alert** on the Cloud billing account.

### Privacy (RA 10173)
- Use **paid (billing-enabled) terms only**. Under Google's free-tier terms, prompts may be used to improve Google's products.
- Prompts carry **student codes + scores only**: no names, ages or free text from children.
- In the consent form and the Data Privacy section, say that anonymized performance data is processed by a third-party AI service (Google), possibly outside the Philippines. Check Google's current Gemini API data-use terms.
- Log every call in `ai_logs` (prompt version, input JSON, output, latency, model, timestamp).

## Guardrails
- Companion: curriculum task support only. No open-ended chat, no personal questions, no collecting the child's data in conversation.
- Teacher reports must cite actual numbers from the injected JSON. Validate the output against the input (sub-skill names, levels) before saving.
- Delgado's caution: avoid total AI dependence. Reports *support* teacher judgment, not replace it.
- Literature caution (Etkin et al., 2025): AI scaffolding helps low performers but can hurt high performers by removing productive struggle. Scale hints with mastery.
