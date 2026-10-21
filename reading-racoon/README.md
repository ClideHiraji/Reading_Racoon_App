# Reading Racoon (Godot 4.7 game client)

The student app: a Duolingo-style learning path for Grade 1 reading (D-007) in a Butuan paper-cut storybook style (D-009) and the thesis colors: light blue, cream, yellow and orange, with dark text on every colored button (D-016). It plays fully offline. A student signs in once with the login code from the teacher, and from then on it syncs to the Laravel API in `backend/` by itself whenever there is internet (D-010).

## What's in it
- **Home hub** (D-015): a game-lobby screen with Racoon in the middle, the child's level, coins and XP on top, Shop and Today on the left, "For you" picks on the right, Closet, Stickers and Words tabs, and a big **PLAY** button that opens a diamond **Play picker** (Adventure, Library, Practice, Watch & Listen, Big Test). Behind it (D-017): **Practice** (Rhyme Pop, Memory Match, Spin the Words, Syllable Train, Story Shuffle, Word Catch; no BKT), the **Library** (8 picture books in English, Filipino and Bisaya with a read-along reader), **Watch & Listen** (songs, chants, read-alongs; teacher videos once downloaded), the **Sticker Album**, **My Word Book** and **Today**'s goals.
- **Reading Adventure** pre-test on first launch places the child on the path (FR-02); **Big Reading Day** post-test when the teacher opens it (FR-10).
- Five worlds, levels 1-5: tap-choice, drag-the-letter, **Spin the Words**, syllable and sentence building, **stories** with who/what/where/when, sequence and prediction questions. Levels 3-4 in Filipino, level 5 in English (placeholders for teacher review).
- BKT per skill-level (D-003), hearts and Racoon's Rescue (D-004), stars, XP and coins.
- **Racoon's Closet** shop: hats (salakot!), scarves, glasses, pins (FR-07).
- **Play-time limits** (FR-12, D-015): only Adventure follows the class window, after-school 30 min/day and weekends. Practice, Library and Watch share a 45-minute daily free-play timer outside Reading time. Everything sleeps at night (9 PM–6 AM) behind a friendly lock screen.
- **Login** once per device with the student's code on a big keypad; "Switch student" on the start screen (only when everything is uploaded).
- **Automatic sync**: after lessons, on start and resume, every 2 minutes; backs off when offline; never during a lesson; file and JSON work on a worker thread.

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
`tests/ui_shots.gd`, `tests/hub_shots.gd` and `tests/section_shots.gd` save screenshots of key moments and of the hub in each time state (need a window; see the comment at their top).

## Layout
| Path | What |
|---|---|
| `scripts/core/` | Rules with no UI, all unit-tested: `bkt.gd`, `student_model.gd` (D-003, placement), `heart_system.gd` (D-004), `lesson_session.gd`, `assessment_session.gd` (pre/post-test), `path_progress.gd`, `question_bank.gd`, `wardrobe.gd` (shop), `access_policy.gd` (play time), `hub_sections.gd` (hub destinations and their time rule), `collection.gd` (stickers, words, goals), `practice_pool.gd`, `media_library.gd`, `sync_protocol.gd` (D-008), `login_code.gd`, `save_store.gd` |
| `scripts/autoload/` | `GameState` (profile, wallet, outfit, tests, play time, saving), `Sync` (automatic, threaded sync with the Laravel API), `Sfx` (synthesized sounds), `Speech` (device TTS, English + Filipino voices) |
| `scenes/` | `main` start screen, `hub/` home hub, Play picker and coming-soon page, `practice/` games, `library/` bookshelf and reader, `watch/` list and player, `collection/` stickers, words, today, `path/` learning path, `lesson/` lessons and tests, `tasks/` task types + story page, `login/` sign-in, `shop/` closet, `lock/` play-time lock screen, `companion/` the raccoon |
| `content/` | `library.json` (Library books), `watch.json` (songs and read-alongs), `levels.json` (L1-2, English placeholders, open issue 15), `levels_3.json`/`levels_4.json` (Filipino), `levels_5.json` (English), `pretest.json`/`posttest.json`, `companion_lines.json` |
| `ui/` | Storybook look (D-009): `palette.gd`, `icons.gd`, `theme.tres`, `ChunkyButton`, `PlayButton`, `DiamondTile`, `BanigMat`, `Kit` (shared screen builders), `ReadAlong`, `Balloon`, `PaperScenery` (Butuan landscapes), `PictureCard`, `Sunburst`, `paper.gdshader` |
| `assets/fonts/` | Nunito (UI) and Andika (reading text), both SIL OFL |
| `assets/icons/` | SVG silhouettes from game-icons.net, CC BY 3.0, see `assets/icons/CREDITS.md`. No emoji anywhere (tests check it) |

## Adding a task item
Add an object to `content/levels.json` with `id, sub_skill, level, competency, language, task_type, prompt, tts_text, choices, answer, recovery`. Pictures are icon names (`"picture": "cat"`) from `assets/icons/`; add a color for new ones in `ui/icons.gd`. `tests/run_tests.gd` checks that every item is well-formed.

Stories live in a file's `passages` map; items point at them with `"passage": "<id>"`. Other task types: `order_tiles` (`variant` syllables / sentence / sequence, `tiles`, answer = tile keys joined by `|`) and `spin_words` (`rime` + `choices` of first sounds).

Debug command-line flags (after `--`): `--profile=<name>`, `--fresh`, `--demo`, `--scene=res://...`, `--shot=<png path>`, `--shot-delay=<sec>`, `--schedule` (use the default school schedule), `--now=<weekday 0-6>:<HH>:<MM>` (fake the clock).

## Server address
Set `reading_racoon/server_url` in `project.godot` (Project Settings > Reading Racoon) before building the APK; it is `http://127.0.0.1:8000` for desktop development with `php artisan serve`. Use HTTPS for the real server. Debug builds also accept `--server=<url>`.

## Teacher books and videos (D-020)
`Sync` downloads what the teacher picked (server `GET /api/content/manifest`, D-019) into `user://content/`: only on Wi-Fi, never during a lesson, each file checked against its SHA-256 before use. `tests/content_e2e.gd` checks it against a running server (see the comment at its top). Debug builds can pretend to be on mobile data with `--metered`.

## Android export (to do)
Add `*.json` to the export resource filter so `content/` ships, and enable the INTERNET and ACCESS_NETWORK_STATE permissions (sync, and the Wi-Fi check for downloads).
