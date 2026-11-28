"""Full content review pack v2 from content-draft-v2.json.

Usage: python -I build_v2.py <reading-racoon dir> <content-draft-v2.json> <out.html>
"""
import html
import json
import pathlib
import sys
from collections import Counter

HERE = pathlib.Path(__file__).parent
draft = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
OUT_V2 = pathlib.Path(sys.argv[3])
sys.argv = [sys.argv[0], sys.argv[1], str(OUT_V2)]
_src = (HERE / "build_review.py").read_text(encoding="utf-8")
exec(_src.split("\npre, post = load")[0])
exec('CSS = """' + _src.split('CSS = """')[1].split('"""')[0] + '"""')
TASK["combo_lock"] = "Combination lock: spin two rings"


def card(label, picture, correct, repeat=1, say=None):
    cls = "card ok" if correct else "card"
    mark = '<span class="tick">&#10004;</span>' if correct else ""
    pics = "".join(pic(picture) for _ in range(int(repeat or 1))) if picture else ""
    if int(repeat or 1) > 1:
        small = pics.replace('class="pic"', 'class="pic sm"')
        pics = f'<div class="many">{small}</div>'
    said = f'<div class="said">&#128264; {html.escape(say)}</div>' if say else ''
    return f'<div class="{cls}">{pics}<div>{html.escape(str(label or ""))}</div>{said}{mark}</div>'


def choices_html(i, fmt=lambda c: c.get("label")):
    return "".join(card(fmt(c), c.get("picture"), c["id"] == i["answer"], c.get("repeat", 1), c.get("say"))
                   for c in i["choices"])


AUDIO = {"sound": "the sound", "letter": "the letter name", "word": "the word"}


def body(i):
    t, ans = i["task_type"], i["answer"]
    out = ""
    if i.get("audio"):
        a = i["audio"]
        shown = f"/{a['value']}/" if a["kind"] == "sound" else a["value"]
        out += (f'<div class="audio">&#128264; Speaker button plays {AUDIO[a["kind"]]} <b>{html.escape(shown)}</b> '
                f'(not shown on screen)</div>')
    if i.get("picture") or i.get("word"):
        out += f'<div class="stim">{pic(i.get("picture"))}<b>{html.escape(i.get("word", ""))}</b></div>'
    if i.get("picture_name") and not i.get("word") and (i.get("audio") or {}).get("kind") != "word":
        out += f'<div class="small">Picture name (for checking, not shown or said): <b>{html.escape(i["picture_name"])}</b></div>'
    if i.get("sentence"):
        out += f'<div class="sent">{html.escape(i["sentence"])}</div>'
    if t == "tap_choice":
        return out + f'<div class="cards">{choices_html(i)}</div>'
    if t == "drag_letter":
        pat = " ".join("__" if x == "_" else html.escape(x) for x in i["pattern"])
        return out + f'<div class="sent">{pat}</div><div class="cards">{choices_html(i)}</div>'
    if t == "spin_words":
        return out + (f'<div class="sent">Wheel of 4 + ending -{html.escape(i["rime"])}</div>'
                      f'<div class="cards">{choices_html(i, lambda c: c.get("label") + "-" + i["rime"])}</div>')
    if t == "combo_lock":
        a1, a2 = ans.split("|")
        rings = "".join(
            f'<div class="small">Ring {n}:</div><div class="cards">'
            + "".join(card(x, None, x == a) for x in ring) + "</div>"
            for n, (ring, a) in enumerate(zip(i["rings"], (a1, a2)), 1))
        return out + rings + f'<div class="small">Opens with <b>{a1} + {a2} = {a1 + a2}</b> (8 &times; 8 = 64 combinations)</div>'
    if t == "order_tiles":
        tiles = i["tiles"]
        if tiles and isinstance(tiles[0], dict):
            by_id = {x["id"]: x for x in tiles}
            order = [by_id[k] for k in ans.split("|")]
            cards = "".join(card(f'{n}. {x.get("text", "")}', x.get("picture"), False, 1, x.get("say"))
                            for n, x in enumerate(order, 1))
        else:
            cards = "".join(card(f"{n}. {x}", None, False) for n, x in enumerate(ans.split("|"), 1))
        return out + f'<div class="small">Correct order:</div><div class="cards">{cards}</div>'
    return out + f"<div>Answer: {html.escape(str(ans))}</div>"


# Uniqueness: same task, picture, audio, sentence, answer and story = same question.
def sig(i):
    tiles = tuple((x.get("text") or x.get("say")) if isinstance(x, dict) else x for x in i.get("tiles", []))
    return (i["language"][:3], i["task_type"], i["prompt"], i.get("picture"), json.dumps(i.get("audio")),
            i.get("word"), i.get("sentence"), str(i["answer"]), tiles, i.get("passage"))


items = draft["levels"]["items"]
seen, dups = {}, []
for i in items + draft["pretest"]["items"] + draft["posttest"]["items"]:
    if i.get("recovery"):
        continue
    s = sig(i)
    if s in seen:
        dups.append((seen[s], i["id"]))
    seen.setdefault(s, i["id"])
assert not dups, dups

BADGE = {0: '<span class="b b0">RESCUE</span>', 1: '<span class="b b1">TIER 1 &middot; EASIER</span>',
         2: '<span class="b b2">TIER 2 &middot; HARDER</span>'}
LANGS = {1: "Bisaya", 2: "Bisaya", 3: "Filipino", 4: "Filipino", 5: "English"}
parts = []
for key, title in (("pretest", "Pre-test (Form A)"), ("posttest", "Post-test (Form B)")):
    d = draft[key]
    parts.append(f'<h2>{title} &middot; Filipino</h2><p>20 items. Rate relevance 1-4 (I-CVI: keep items rated 3-4 by '
                 f'at least 78% of raters).</p>')
    shown = set()
    for n, i in enumerate(d["items"], 1):
        pk = i.get("passage")
        if pk and pk not in shown:
            shown.add(pk)
            parts.append(passage_html(pk, d["passages"][pk]))
        parts.append(item_html(n, i, True))

rows = ""
for lvl in range(1, 6):
    parts.append(f"<h2>Adventure Level {lvl} &middot; {LANGS[lvl]}</h2>")
    for sk in SKILL:
        cell = sorted([i for i in items if int(i["level"]) == lvl and i["sub_skill"] == sk],
                      key=lambda i: (i["tier"] == 0, i["tier"], i["id"]))
        if not cell:
            continue
        t = Counter(i["tier"] for i in cell)
        rows += f"<tr><td>Level {lvl}</td><td>{SKILL[sk]}</td><td>{t[1]}</td><td>{t[2]}</td><td>{t[0]}</td></tr>"
        parts.append(f"<h3>{SKILL[sk]} &middot; Level {lvl}</h3>")
        shown = set()
        for n, i in enumerate(cell, 1):
            pk = i.get("passage")
            if pk and pk not in shown:
                shown.add(pk)
                parts.append(passage_html(pk, draft["levels"]["passages"][pk]))
            agree = ('<div class="rate">Tier: &#9744; agree &nbsp; &#9744; should be tier 1 &nbsp; &#9744; should be '
                     'tier 2 &nbsp; Language: &#9744; correct &nbsp; &#9744; fix</div>' if i["tier"] else
                     '<div class="rate">Language: &#9744; correct &nbsp; &#9744; fix</div>')
            parts.append(f'<div class="tierbar">{BADGE[i["tier"]]}</div>'
                         + item_html(n, i, False).replace('<div class="rate">', agree + '<div class="rate">', 1))

have = {p.stem for d in ("assets/pictures", "assets/icons") for p in (ROOT / d).glob("*.svg")}
want = Counter()
for i in items + draft["pretest"]["items"] + draft["posttest"]["items"]:
    names = [i.get("picture")] + [c.get("picture") for c in i.get("choices", [])] + \
            [x.get("picture") for x in i.get("tiles", []) if isinstance(x, dict)]
    want.update(n for n in names if n and n not in have)
draw = ", ".join(f"{k} ({v})" for k, v in sorted(want.items()))
audio = Counter(i["audio"]["kind"] for i in items + draft["pretest"]["items"] + draft["posttest"]["items"]
                if i.get("audio"))
clips = sorted({(i["language"][:3], i["audio"]["kind"], i["audio"]["value"])
                for i in items + draft["pretest"]["items"] + draft["posttest"]["items"] if i.get("audio")})
clip_list = ", ".join(f"{lg.upper()} {k} {v}" for lg, k, v in clips)

CSS2 = CSS + """
h3 { margin: 14px 0 2px; } .tierbar { margin: 10px 0 -6px; }
.b { display: inline-block; font-size: 8.5pt; font-weight: bold; padding: 1px 7px; border-radius: 9px; color: #fff; }
.b1 { background: #2a8a3a; } .b2 { background: #b5482b; } .b0 { background: #777; }
.audio { font-size: 10pt; background: #eaf4ff; border: 1px dashed #2b5fb5; border-radius: 5px; padding: 3px 7px; margin: 3px 0; }
.many { display: flex; flex-wrap: wrap; gap: 2px; justify-content: center; max-width: 120px; }
.pic.sm { width: 26px; height: 26px; margin: 0; }
.said { font-size: 8pt; color: #2b5fb5; font-style: italic; }
"""
cover = f"""<h1>Reading Racoon: full content, version 2</h1>
<div>Draft for teacher review &middot; pre-test, post-test and all 5 adventure levels &middot; not in the game yet</div>
<h3>What changed since the last packs</h3>
<ul>
<li><b>Sounds, letters and words to find are heard, not shown.</b> The screen shows a speaker button; the buddy says
"tap the speaker to listen". So "/s/", "the letter b" or the word to find never appear as text
(the blue dashed box tells the reviewer what the button plays).</li>
<li><b>When the word is said.</b> Rhymes say the word ("Asa ang katugma sa baboy?") and spin wheels and locks say
the word to make ("Tuyoka aron mahimo ang pulong kahoy"). For the other picture tasks (first letter, clapping
syllables, building or completing a word) the child names the picture: the name only comes in the hint after a wrong
answer, as comfort support. Answer cards never have labels, so the spelling never gives the answer away.</li>
<li><b>No written words next to a picture.</b> Comprehension answer cards and story-order tiles show only the picture; the buddy reads the card aloud when the child taps it (shown in small blue italics, &#128264;). In rhymes and spin wheels the word is spoken and replayed by the speaker button, never written.</li>
<li><b>Counting items</b> show each picture as many times as its number.</li>
<li><b>Rhymes fixed:</b> tasa rhymes with kalabasa (not lamesa), unggoy with baboy (not mangga with ilaga).</li>
<li><b>Combination lock (new task):</b> two rings of 8 syllables, 64 combinations, the child spins both to make the
picture's name. It replaces the harder spin items; the 4-option wheel stays as the easier version.</li>
</ul>
<h3>Items per skill and level</h3>
<table><tr><th>Level</th><th>Skill</th><th>Tier 1</th><th>Tier 2</th><th>Rescue</th></tr>{rows}</table>
<p>Each level: 5 quests &times; 8 questions = 40. Every level has at least 40 different items, so no question repeats
in a level. No two items ask the same question anywhere, tests included.</p>
<h3>Sounds to record</h3>
<p class="small">{sum(audio.values())} items use the speaker ({audio["sound"]} sounds, {audio["letter"]} letter
names, {audio["word"]} words). Clips needed: {clip_list}.</p>
<h3>Pictures to draw</h3><p class="small">{draw}</p>
<div class="warn"><b>Check every Bisaya and Filipino line, and that each picture has one clear name</b> the children
use, because the children now name the pictures themselves.</div>
<h3>Reviewer</h3><p>Name: ______________________ &nbsp; Date: __________ &nbsp; Signature: ______________________</p>"""
OUT_V2.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>Full content v2</title>'
                  f'<style>{CSS2}</style></head><body>{cover}{"".join(parts)}</body></html>', encoding="utf-8")
print("items", len(items), "audio", dict(audio), "to draw", len(want))
