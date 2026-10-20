# Reading Racoon (Godot 4.7 game client)

The student app: a Duolingo-style learning path for Grade 1 reading (decision D-007). It plays fully offline. Saving to the Laravel server comes in a later slice.

Spec and decisions live in [`docs/knowledge/`](../docs/knowledge/README.md) and [`brain/`](../brain/Home.md).

## Run it
Open this folder in Godot 4.7 and press **F5**. The window is portrait (450×800 on desktop, 720×1280 design size).
The **↺** button on the path (debug builds only) resets progress.

## Test it
From the repo root (run the import once after cloning or adding a `class_name`):
```bash
"/c/Program Files/Godot/Godot.exe" --headless --path reading-racoon --import
"/c/Program Files/Godot/Godot.exe" --headless --path reading-racoon -s res://tests/run_tests.gd
"/c/Program Files/Godot/Godot.exe" --headless --path reading-racoon -s res://tests/ui_smoke.gd -- --profile=smoke --fresh
```
`tests/ui_shots.gd` saves screenshots of key moments (needs a window; see the comment at its top).

## Layout
| Path | What |
|---|---|
| `scripts/core/` | Game rules with no UI: `bkt.gd`, `student_model.gd` (D-003), `heart_system.gd` (D-004), `lesson_session.gd`, `path_progress.gd`, `question_bank.gd`, `save_store.gd` |
| `scripts/autoload/` | `GameState` (profile, wallet, saving), `Sfx` (synthesized sounds), `Speech` (device TTS) |
| `scenes/` | `main` start screen, `path/` learning path, `lesson/` lesson + lesson complete, `tasks/` task types, `companion/` the raccoon |
| `content/` | `levels.json` task items (**English placeholders**, open issue 15) and `companion_lines.json` |
| `ui/` | `theme.tres` and `ChunkyButton` |
| `assets/fonts/` | Nunito (UI) and Andika (reading text), both SIL OFL |

## Adding a task item
Add an object to `content/levels.json` with `id, sub_skill, level, competency, language, task_type, prompt, tts_text, choices, answer, recovery`. `tests/run_tests.gd` checks that every item is well-formed.

Debug command-line flags (after `--`): `--profile=<name>`, `--fresh`, `--demo`, `--scene=res://...`, `--shot=<png path>`, `--shot-delay=<sec>`.
