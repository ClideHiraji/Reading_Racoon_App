"""Build the teacher review pack (HTML) from the game's content JSON.

Usage: python -I build_review.py <reading-racoon dir> <out.html>
"""
import html
import json
import pathlib
import re
import sys
from collections import Counter

ROOT = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
C = ROOT / "content"

SKILL = {
    "phonological_awareness": "Phonological Awareness",
    "phonics": "Phonics and Word Study",
    "vocabulary": "Vocabulary",
    "fluency": "Reading Fluency",
    "literal_comprehension": "Literal Comprehension",
}
TASK = {
    "tap_choice": "Tap the right card",
    "drag_letter": "Drag the missing letter",
    "order_tiles": "Put the tiles in order",
    "spin_words": "Spin the wheel to make the word",
}
VARIANT = {"rhyme_pop": "balloons", "word_catch": "falling words", "syllables": "syllables",
           "sentence": "words of a sentence", "sequence": "story events"}
# Story-comprehension letters: the Q1-style tags the game uses -> Quarter 2 codes.
CAT = {"2a": "RL1CAT-II-1a", "2b": "RL1CAT-II-1b", "2c": "RL1CAT-II-1c", "2d": "RL1CAT-II-1d",
       "2e": "RL1CAT-II-1e", "2f": "RL1CAT-II-1f", "2g": "RL1CAT-III-2g",
       "3a": "RL1CAT-II-2a", "3b": "RL1CAT-II-2b"}
CAT_TEXT = {"2a": "story details (character, setting, events)", "2b": "sequence 3 events",
            "2c": "infer feelings and traits", "2d": "predict the ending", "2f": "cause and effect",
            "2g": "problem and solution in a story", "3a": "informational text details",
            "3b": "problem and solution (informational)"}


def q2(code: str, level: int) -> tuple[str, list[str]]:
    """Proposed Quarter 2 code and review notes for one item."""
    notes = []
    m = re.match(r"RL1CAT-I-(\d[a-g])", code)
    if code.startswith("RL1PA"):
        new = code
        notes.append("Phonological awareness is a Q1 competency: kept as review.")
    elif m:
        new = CAT.get(m.group(1), code)
        notes.append("Competency: " + CAT_TEXT.get(m.group(1), m.group(1)) + ".")
        if m.group(1) == "2f":
            notes.append("In Q2 cause and effect is listening and speaking only: keep the story narrated.")
        if m.group(1) == "2g":
            notes.append("Starts in Q3.")
    elif code.startswith("RL1BPK-I-3"):
        new = "RL1BPK-II-3"
    else:
        new = code.replace("-I-", "-II-")
    if new.startswith("RL1VWK-II-1"):
        notes.append("Q2 vocabulary theme is school: check the word fits.")
    if level >= 5:
        notes.append("Level 5 is an extension beyond Q2 (Q3-Q4 skills).")
    return new, notes


def pic(name):
    if not name:
        return ""
    for folder in ("assets/pictures", "assets/icons"):
        p = ROOT / folder / f"{name}.svg"
        if p.exists():
            return f'<img class="pic" src="{p.as_uri()}" alt="{html.escape(name)}">'
    return f'<span class="nopic">[{html.escape(name)}]</span>'


def card(label, picture, correct):
    cls = "card ok" if correct else "card"
    mark = '<span class="tick">&#10004;</span>' if correct else ""
    return f'<div class="{cls}">{pic(picture)}<div>{html.escape(str(label or ""))}</div>{mark}</div>'


def body(i):
    t, ans = i["task_type"], i["answer"]
    stim = ""
    if i.get("picture") or i.get("word"):
        stim = f'<div class="stim">{pic(i.get("picture"))}<b>{html.escape(i.get("word", ""))}</b></div>'
    if i.get("sentence"):
        stim += f'<div class="sent">{html.escape(i["sentence"])}</div>'
    if t == "tap_choice":
        cards = "".join(card(c.get("label"), c.get("picture"), c["id"] == ans) for c in i["choices"])
        return stim + f'<div class="cards">{cards}</div>'
    if t == "drag_letter":
        pat = " ".join("__" if x == "_" else html.escape(x) for x in i["pattern"])
        cards = "".join(card(c.get("label"), c.get("picture"), c["id"] == ans) for c in i["choices"])
        return stim + f'<div class="sent">{pat}</div><div class="cards">{cards}</div>'
    if t == "spin_words":
        cards = "".join(card(c.get("label") + "-" + i["rime"], None, c["id"] == ans) for c in i["choices"])
        return stim + f'<div class="sent">Word ending: -{html.escape(i["rime"])}</div><div class="cards">{cards}</div>'
    if t == "order_tiles":
        tiles = i["tiles"]
        if tiles and isinstance(tiles[0], dict):
            by_id = {x["id"]: x for x in tiles}
            order = [by_id[k] for k in ans.split("|")]
            cards = "".join(card(f'{n}. {x["text"]}', x.get("picture"), False) for n, x in enumerate(order, 1))
        else:
            cards = "".join(card(f"{n}. {x}", None, False) for n, x in enumerate(ans.split("|"), 1))
        return stim + f'<div class="small">Correct order:</div><div class="cards">{cards}</div>'
    return stim + f"<div>Answer: {html.escape(str(ans))}</div>"


def item_html(n, i, rate):
    lvl = int(i["level"])
    new, notes = q2(i["competency"], lvl)
    task = TASK.get(i["task_type"], i["task_type"])
    if i.get("variant"):
        task += f' ({VARIANT.get(i["variant"], i["variant"])})'
    code = html.escape(i["competency"])
    code = code if new == i["competency"] else f'<s>{code}</s> &rarr; <b>{html.escape(new)}</b>'
    extra = ""
    if i.get("hint"):
        extra += f'<div class="small"><b>Hint after a wrong answer:</b> {html.escape(i["hint"])}</div>'
    if i.get("explain"):
        extra += f'<div class="small"><b>Explanation:</b> {html.escape(i["explain"])}</div>'
    if notes:
        extra += '<div class="note">' + " ".join(html.escape(x) for x in notes) + "</div>"
    lang = i.get("language", "").replace("-placeholder", "")
    review = ('<div class="rate">Relevance: &#9744;1 &#9744;2 &#9744;3 &#9744;4</div>' if rate else
              '<div class="rate">&#9744; Approve &nbsp; &#9744; Revise</div>')
    return f"""<div class="item">
<div class="head"><span class="num">{n}</span> <b>{html.escape(i["id"])}</b> &middot; Level {lvl}
 &middot; {SKILL.get(i["sub_skill"], i["sub_skill"])} &middot; {task} &middot; {lang.upper()} &middot; {code}</div>
<div class="say"><b>Child sees:</b> {html.escape(i["prompt"])} &nbsp; <b>Child hears:</b> <i>{html.escape(i["tts_text"])}</i></div>
{body(i)}{extra}{review}<div class="lines">Comments: ______________________________________________</div></div>"""


def passage_html(key, p):
    lang = p.get("language", "").replace("-placeholder", "").upper()
    return f"""<div class="passage"><div class="ptitle">Story: {html.escape(p["title"])}
 <span class="small">({key}, Level {int(p["level"])}, {lang}, {len(p["text"].split())} words)</span></div>
<p>{html.escape(p["text"])}</p>
<div class="rate">&#9744; Approve &nbsp; &#9744; Revise &nbsp; Comments: ______________________________</div></div>"""


def section(title, intro, data, rate):
    out = [f'<h2>{title}</h2><p>{intro}</p>']
    shown, n = set(), 0
    for i in data["items"]:
        pk = i.get("passage")
        if pk and pk not in shown:
            shown.add(pk)
            out.append(passage_html(pk, data["passages"][pk]))
        n += 1
        out.append(item_html(n, i, rate))
    return "\n".join(out)


def blueprint(data):
    c = Counter(i["sub_skill"] for i in data["items"])
    rows = "".join(f"<tr><td>{SKILL[k]}</td><td>{c.get(k, 0)}</td></tr>" for k in SKILL)
    return f'<table class="bp"><tr><th>Sub-skill</th><th>Items</th></tr>{rows}<tr><th>Total</th><th>{sum(c.values())}</th></tr></table>'


def load(name):
    return json.loads((C / name).read_text(encoding="utf-8"))


pre, post = load("pretest.json"), load("posttest.json")
levels = load("levels.json")
for n in (3, 4, 5):
    d = load(f"levels_{n}.json")
    levels["items"] += d["items"]
    levels.setdefault("passages", {}).update(d.get("passages", {}))

parts = [
    section("Part A. Pre-test (Form A)",
            "20 items in the thesis blueprint, played as the Reading Adventure: no hearts, neutral feedback. "
            "Rate how relevant each item is to its competency (1 not relevant, 2 somewhat, 3 quite, 4 highly "
            "relevant). Items rated 3 or 4 count toward the content validity index (I-CVI = number of 3s and "
            "4s / number of raters; keep an item at 0.78 or higher).", pre, True) + blueprint(pre),
    section("Part B. Post-test (Form B, parallel form)",
            "Same blueprint, levels and task types as the pre-test, with different items and stories. "
            "Rate it the same way, and check it is about as hard as the pre-test.", post, True) + blueprint(post),
]
for lvl, name in [(1, "Foundational (ARAL Basic)"), (2, "Emerging (ARAL Basic / Plus)"),
                  (3, "Developing (ARAL Plus): the Quarter 2 core"), (4, "Approaching Proficient"),
                  (5, "Proficient: extension beyond Quarter 2")]:
    d = {"items": [i for i in levels["items"] if int(i["level"]) == lvl], "passages": levels["passages"]}
    parts.append(section(f"Part C{lvl}. Adventure Level {lvl}: {name}",
                         f"{len(d['items'])} items. The game picks from these by each child's mastery, so a child "
                         "won't see all of them. Mark each item Approve or Revise.", d, False))

counts = Counter(int(i["level"]) for i in levels["items"])
summary = "".join(f"<tr><td>Level {k}</td><td>{counts[k]}</td></tr>" for k in sorted(counts))
CSS = """
@page { size: A4; margin: 14mm 12mm; }
body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 10.5pt; color: #222; }
h1 { font-size: 20pt; margin: 0 0 4px; } h2 { font-size: 15pt; border-bottom: 2px solid #c63; padding-bottom: 3px;
 margin-top: 18px; page-break-before: always; } h3 { font-size: 12pt; }
.item { border: 1px solid #bbb; border-radius: 6px; padding: 7px 9px; margin: 8px 0; page-break-inside: avoid; }
.head { font-size: 9.5pt; color: #333; } .num { display: inline-block; background: #c63; color: #fff;
 border-radius: 10px; padding: 0 7px; font-weight: bold; }
.say { margin: 4px 0; } .cards { display: flex; flex-wrap: wrap; gap: 6px; margin: 4px 0; }
.card { border: 1px solid #ccc; border-radius: 5px; padding: 4px 8px; min-width: 60px; text-align: center; position: relative; }
.card.ok { border: 2px solid #2a8a3a; background: #eef8ef; } .tick { color: #2a8a3a; font-weight: bold; }
.pic { width: 46px; height: 46px; display: block; margin: 0 auto 2px; } .nopic { color: #a33; font-size: 9pt; }
.stim { display: flex; align-items: center; gap: 8px; } .stim .pic { margin: 0; }
.sent { font-size: 13pt; letter-spacing: 1px; margin: 3px 0; } .small { font-size: 9pt; color: #444; }
.note { font-size: 9pt; background: #fff6e0; border-left: 3px solid #e0a000; padding: 2px 6px; margin: 3px 0; }
.rate { font-size: 10pt; margin-top: 4px; } .lines { font-size: 9pt; color: #555; margin-top: 3px; }
.passage { background: #f3f6fb; border: 1px solid #9ab; border-radius: 6px; padding: 8px 10px; margin: 10px 0; page-break-inside: avoid; }
.passage p { font-size: 13pt; line-height: 1.5; margin: 4px 0; } .ptitle { font-weight: bold; }
table { border-collapse: collapse; margin: 6px 0; } td, th { border: 1px solid #999; padding: 3px 8px; font-size: 10pt; }
.warn { background: #fdecea; border: 1px solid #d9534f; padding: 8px 10px; border-radius: 6px; }
"""
cover = f"""<h1>Reading Racoon: content review pack</h1>
<div>Draft for teacher review before the 3-day pilot (Tuesday 1 to Thursday 3 December 2026), Quarter 2</div>
<h3>What is in this pack</h3>
<table><tr><th>Part</th><th>Content</th><th>Items</th></tr>
<tr><td>A</td><td>Pre-test (Form A)</td><td>{len(pre["items"])}</td></tr>
<tr><td>B</td><td>Post-test (Form B)</td><td>{len(post["items"])}</td></tr>
<tr><td>C1-C5</td><td>Adventure levels 1-5</td><td>{len(levels["items"])}</td></tr></table>
<table><tr><th>Adventure level</th><th>Items</th></tr>{summary}</table>
<h3>How to read each item</h3>
<p><b>Child sees</b> is the text on screen, <b>Child hears</b> is what the buddy says. Choices with a green border and
&#10004; are the correct answer. Pictures are the ones the game shows. Check that each picture has one clear name in
the item's language.</p>
<p>The competency code shows the code in the game now, crossed out, and the proposed <b>Quarter 2</b> code from the
MATATAG Grade 1 Reading and Literacy guide. Yellow notes flag something to check.</p>
<div class="warn"><b>Draft content.</b> Every item is still a placeholder until teachers approve it. Levels 1-2 and the
level-5 items are in English, levels 3-4 in Filipino. MATATAG Grade 1 reading is taught in the learner's first
language, so please confirm the language of each part in writing.</div>
<h3>Reviewer</h3><p>Name: ______________________ &nbsp; Role: ______________________ &nbsp; Date: __________</p>
<p>Signature: ______________________</p>"""

OUT.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>Content review pack</title>'
               f'<style>{CSS}</style></head><body>{cover}{"".join(parts)}</body></html>', encoding="utf-8")
print("items", len(pre["items"]) + len(post["items"]) + len(levels["items"]))
