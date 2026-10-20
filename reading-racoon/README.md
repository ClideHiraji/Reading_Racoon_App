# Reading Racoon (Godot 4.7 game client)

The student app: a Duolingo-style learning path for Grade 1 reading (D-007) in a Butuan paper-cut storybook style (D-009). It plays fully offline and syncs to the Laravel API in `backend/` when a grown-up connects the device.

## What's in it
- **Reading Adventure** pre-test on first launch places the child on the path (FR-02); **Big Reading Day** post-test when the teacher opens it (FR-10).
- Five worlds, levels 1-5: tap-choice, drag-the-letter, **Spin the Words**, syllable and sentence building, **stories** with who/what/where/when, sequence and prediction questions. Levels 3-4 in Filipino, level 5 in English (placeholders for teacher review).
- BKT per skill-level (D-003), hearts and Racoon's Rescue (D-004), stars, XP and coins.
- **Racoon's Closet** shop: hats (salakot!), scarves, glasses, pins (FR-07).
- **Play-time limits**: class window, after-school 30 min/day, weekends, friendly lock screens (FR-12).
- **Grown-ups** screen behind a times-table gate: connect to the server with a student login code, sync now, open the post-test.

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
| `scripts/core/` | Rules with no UI, all unit-tested: `bkt.gd`, `student_model.gd` (D-003, placement), `heart_system.gd` (D-004), `lesson_session.gd`, `assessment_session.gd` (pre/post-test), `path_progress.gd`, `question_bank.gd`, `wardrobe.gd` (shop), `access_policy.gd` (play time), `sync_protocol.gd` (D-008), `save_store.gd` |
| `scripts/autoload/` | `GameState` (profile, wallet, outfit, tests, play time, saving), `Sync` (Laravel API), `Sfx` (synthesized sounds), `Speech` (device TTS, English + Filipino voices) |
| `scenes/` | `main` start screen, `path/` learning path, `lesson/` lessons and tests, `tasks/` task types + story page, `shop/` closet, `lock/` play-time lock screen, `settings/` grown-ups, `companion/` the raccoon |
| `content/` | `levels.json` (L1-2, English placeholders, open issue 15), `levels_3.json`/`levels_4.json` (Filipino), `levels_5.json` (English), `pretest.json`/`posttest.json`, `companion_lines.json` |
| `ui/` | Storybook look (D-009): `palette.gd`, `icons.gd`, `theme.tres`, `ChunkyButton`, `PaperScenery` (Butuan landscapes), `PictureCard`, `Sunburst`, `paper.gdshader` |
| `assets/fonts/` | Nunito (UI) and Andika (reading text), both SIL OFL |
| `assets/icons/` | SVG silhouettes from game-icons.net, CC BY 3.0, see `assets/icons/CREDITS.md`. No emoji anywhere (tests check it) |

## Adding a task item
Add an object to `content/levels.json` with `id, sub_skill, level, competency, language, task_type, prompt, tts_text, choices, answer, recovery`. Pictures are icon names (`"picture": "cat"`) from `assets/icons/`; add a color for new ones in `ui/icons.gd`. `tests/run_tests.gd` checks that every item is well-formed.

Stories live in a file's `passages` map; items point at them with `"passage": "<id>"`. Other task types: `order_tiles` (`variant` syllables / sentence / sequence, `tiles`, answer = tile keys joined by `|`) and `spin_words` (`rime` + `choices` of first sounds).

Debug command-line flags (after `--`): `--profile=<name>`, `--fresh`, `--demo`, `--scene=res://...`, `--shot=<png path>`, `--shot-delay=<sec>`, `--schedule` (use the default school schedule), `--now=<weekday 0-6>:<HH>:<MM>` (fake the clock).

## Android export (to do)
Add `*.json` to the export resource filter so `content/` ships, and enable the INTERNET permission for sync.
