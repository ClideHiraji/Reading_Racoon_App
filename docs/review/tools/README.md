# Review pack scripts

Build the teacher review PDFs in `docs/review/` from the game's content and the draft JSON files.
Run from the repo root with Python 3.11+ (`pip install pypdf` only for counting pages). PDFs are printed with
headless Edge.

## Run order (full content v2, the current pack)

```powershell
$R = "docs/review"; $T = "$R/tools"; $G = "reading-racoon"
python -I $T/make_draft.py $R/tier-draft.json            # tiers + 38 new Level 3-5 items
python -I $T/make_lang.py  $R/language-draft.json        # Bisaya Levels 1-2 + Filipino test items (D-045)
python -I $T/make_more.py  $R/more-items-draft.json      # 112 more items -> 20 per skill per level
python -I $T/apply_rules.py $G $R $R/content-draft-v2.json   # merge all + review rules
python -I $T/build_v2.py   $G $R/content-draft-v2.json $env:TEMP/v2.html
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --no-pdf-header-footer --allow-file-access-from-files `
  --print-to-pdf="$PWD\docs\review\content-review-pack-v2.pdf" "file:///$env:TEMP/v2.html"
```

Teacher edits go into the `make_*.py` files (the item lists), then rerun from that step down.

## Files

| Script | Makes |
|---|---|
| `build_review.py` | First pack (current game items + proposed Q2 codes); its item layout is reused by the others |
| `make_draft.py`, `build_tiers.py` | `tier-draft.json`, tier pack |
| `make_lang.py`, `build_lang.py` | `language-draft.json`, language pack |
| `make_more.py`, `build_more.py` | `more-items-draft.json`, more-items pack (checks 10 easier + 10 harder per skill) |
| `apply_rules.py` | `content-draft-v2.json`: everything merged; speaker audio for sounds/letters/words; no written words next to pictures; tasa/kalabasa, unggoy/baboy; combination lock |
| `build_v2.py` | Full v2 pack; fails if two items ask the same question |
