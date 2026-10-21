---
type: decision
status: decided
date: 2026-10-21
issue: 23
graphify: submitted
tags: [decision, ai, backend, teacher]
---

# D-018 Gemini teacher report

**Decision:** Gemini writes the **two summary paragraphs** of the teacher report; the lists under them (strengths, needs support, classroom activities) and the sub-skill table stay rule-based. A queued job writes the report and stores it; the report page only ever shows a stored, checked AI version or the template.

| Part | Choice |
|---|---|
| Seam | `App\Reports\DiagnosticReportWriter` (D-012). Pages get `StoredReportWriter`; the job `App\Jobs\WriteAiReport` calls `GeminiReportWriter`. No LLM call during a page view. |
| When | 10 minutes after a sync that stored new events (`LLM_REPORT_DELAY_MINUTES`). The job is unique per learner, so later syncs in that window don't queue another: one report per play session. A teacher opening a report with no AI version for the current numbers queues one too. |
| Same numbers | `ai_reports` is keyed by a hash of the prompt JSON + prompt version. Same numbers = the stored text, no new call. New numbers = template until the new version is written. |
| Prompt | `App\Reports\ReportPrompt` (`report-v1`): role, BKT legend, rules, then the JSON. Temperature 0.3 (thesis). The prompt asks for ≤ 150 words; `max_tokens` 600 leaves room for thinking tokens. The JSON is student code + numbers + the template's strengths/needs split; **no names, ages or dates**. |
| Checks (`AiReportCheck`) | Exactly two plain paragraphs, 40–180 words, no list or heading; no other learner's code; **every number must be in the JSON** (or a BKT threshold: 0.95, 5 answers, 0.30); every needs-support sub-skill is named. Also refused: empty, safety-blocked (`content_filter`) or cut off (`finish_reason: length`). |
| Retries | Up to 3 calls, 2 s then 4 s apart, for timeouts, 429, 5xx and refused text. A bad key, model or request (other 4xx) isn't retried. Then the template, plus an `ai.report_fallback` warning in the system log. A failed set of numbers isn't sent again until the numbers change. |
| Logging (FR-21) | `ai_logs`: every call with task, prompt version, model, the injected JSON, the reply, status (`ok`/`invalid`/`blocked`/`error`), reason, latency, tokens. The admin portal has an **AI calls** tab. |
| Consent | **Only learners with parental consent on file** are ever sent; without it they get the template. Removing a learner deletes their `ai_logs` and `ai_reports`. |
| Off switch | Without `LLM_BASE_URL`, `LLM_API_KEY` and `LLM_MODEL` nothing is queued or sent. `php artisan report:write <code>` checks the settings without playing. |

**Why**
- Thesis: reports are written "after each session" with temperature 0.3 and must cite the real numbers ([[08-ai-integration]]). A queued job keeps the page fast and the cost to one call per session.
- Letting the AI write only the prose keeps every list and number rule-based, so the checks can be strict and a refused reply loses little.
- The numbers check is simple to explain in the thesis and catches the main LLM risk here: invented or miscalculated scores.
- Consent: the consent form must say that anonymised scores go to a third-party AI (Google). Without that consent, sending them would break RA 10173.

**Consequences**
- The server needs a queue worker (`php artisan queue:work`, or `composer dev` locally). Without one, reports stay on the template.
- Teachers see the template while a learner is still playing, and the AI version about 10 minutes after the last sync.
- Changing the prompt wording means bumping `ReportPrompt::VERSION`; old reports then count as stale and are rewritten on the next view or sync.
- The study's report ratings (MLDLC Stage 4) can use `report:write --force` to produce fresh samples; every sample is in `ai_logs`.

**Rejected:** calling Gemini on every page view (slow, costly, rate limits); letting the AI write the lists too (harder to check, more to lose on a refusal); JSON output mode (uses more of the token budget and gets cut off more).

Details: `backend/README.md` ("Gemini teacher report"), [[D-002 AI model Gemini]], [[D-012 Teacher web dashboard]], [[10-open-issues]] issue 23.
