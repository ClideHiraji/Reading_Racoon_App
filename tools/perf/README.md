# Performance tour (NFR-01)

`perf_tour.gd` plays through the game the way a child does and times every frame, with vsync off so each frame's time is its real cost. It opens every screen, plays a lesson (a hint, an answer, right answers, the finish), switches Closet tabs, opens the games, the Library, Watch & Listen and the collections. It does all of this twice: the first pass is a child's first visit (loading, building), the second a revisit.

`summarize.py` prints each moment's frame count, mean, 95th percentile and worst frame, and how many frames went over 16.7 ms (one frame at 60 fps) and 33.3 ms (a visible hitch).

## Run it

Never on `reading-racoon/` while the Godot editor has it open: use a scratch copy. In PowerShell:

```powershell
robocopy reading-racoon <scratch>\rr /MIR /XD .godot tools
Copy-Item tools\perf\perf_tour.gd <scratch>\rr\
& "C:\Program Files\Godot\Godot.exe" --headless --path <scratch>\rr --import
& "C:\Program Files\Godot\Godot.exe" --path <scratch>\rr --resolution 576x1024 -s res://perf_tour.gd -- <scratch>\tour.json
python tools\perf\summarize.py <scratch>\tour.json
```

The tour opens a small Godot window for a few minutes. Read-aloud is switched off and the sound is muted.

## What it found (2026-11-17, laptop; D-025)

The worst frame at each moment, on the dev laptop:

| Moment | Before | After |
|---|---|---|
| Finishing a lesson | 237 ms | 15–21 ms |
| A lesson answer that cuts off the read-aloud (Windows) | +210 ms | none |
| Opening the Closet | 133–137 ms | 59–63 ms |
| Switching a Closet tab | 109–144 ms | 49–62 ms |
| First visit to a game (Rhyme Pop, Word Catch, Syllable Train) | 75–103 ms | 7–15 ms |
| First visit to Today, Words, Stickers, the Reader, the Player | 74–109 ms | 21–34 ms |
| First visit to Practice | 99 ms | 49 ms |

Steady frames in a lesson dropped from about 6.6 ms to 5.3 ms. A 2 GB phone is several times slower than the laptop, so these are relative numbers. The fixes are listed in `brain/decisions/D-025 Performance no freezes.md`.
