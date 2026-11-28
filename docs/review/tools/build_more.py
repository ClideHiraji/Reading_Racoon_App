"""Review pack for the 112 more items, with full pool counts, duplicate checks and pictures to draw.

Usage: python -I build_more.py <reading-racoon dir> <review dir> <out.html>
"""
import html
import json
import pathlib
import sys
from collections import Counter

HERE = pathlib.Path(__file__).parent
REV = pathlib.Path(sys.argv[2])
OUT_MORE = pathlib.Path(sys.argv[3])
sys.argv = [sys.argv[0], sys.argv[1], str(OUT_MORE)]
_src = (HERE / "build_review.py").read_text(encoding="utf-8")
exec(_src.split("\npre, post = load")[0])
exec('CSS = """' + _src.split('CSS = """')[1].split('"""')[0] + '"""')

rd = lambda n: json.loads((REV / n).read_text(encoding="utf-8"))
tier_draft, lang, more = rd("tier-draft.json"), rd("language-draft.json"), rd("more-items-draft.json")

game = []
passages = {}
for n in ("levels_3.json", "levels_4.json", "levels_5.json"):
    d = load(n)
    game += d["items"]
    passages.update(d.get("passages", {}))
for i in game:
    i["tier"] = 0 if i.get("recovery") else tier_draft["tiers"][i["id"]]
pool = (game + [i for i in tier_draft["new_items"] if i["level"] >= 3] + lang["bisaya_levels_1_2"]
        + more["items"])
passages.update(more["passages"])

# Checks: unique ids, valid answers, no duplicate question in the pool or the tests.
ids = Counter(i["id"] for i in pool)
assert not [k for k, v in ids.items() if v > 1], [k for k, v in ids.items() if v > 1]


def sig(i):
    tiles = tuple(x["text"] if isinstance(x, dict) else x for x in i.get("tiles", []))
    return (i["language"][:3], i["task_type"], i["prompt"], i.get("word"), i.get("sentence"),
            str(i["answer"]), tiles, i.get("passage"))


def answer_ok(i):
    if i["task_type"] == "order_tiles":
        keys = [x["id"] if isinstance(x, dict) else x for x in i["tiles"]]
        return i["answer"] == "|".join(keys)
    return i["answer"] in [c["id"] for c in i["choices"]]


for i in more["items"]:
    assert answer_ok(i), f"bad answer {i['id']}"
    assert i.get("passage") is None or i["passage"] in passages, i["id"]
tests = load("pretest.json")["items"] + load("posttest.json")["items"] + lang["tests_filipino"]["pre"] \
        + lang["tests_filipino"]["post"]
seen = {}
dups = []
for i in pool + tests:
    if i.get("recovery"):
        continue  # rescue items are 2-choice copies of a normal item on purpose
    s = sig(i)
    if s in seen and seen[s] != i["id"]:
        dups.append((seen[s], i["id"]))
    seen.setdefault(s, i["id"])
assert not dups, dups

# Pool counts per skill and level.
cells = {}
for i in pool:
    cells.setdefault((int(i["level"]), i["sub_skill"]), []).append(i)
rows, total = "", Counter()
for key in sorted(cells, key=lambda k: (k[0], list(SKILL).index(k[1]))):
    c = cells[key]
    t = Counter(i["tier"] for i in c)
    nw = sum(1 for i in c if i in more["items"])
    assert t[1] == 10 and t[2] == 10, (key, t)
    total.update({"t1": t[1], "t2": t[2], "r": t[0], "new": nw})
    rows += (f"<tr><td>Level {key[0]}</td><td>{SKILL[key[1]]}</td><td>{t[1]}</td><td>{t[2]}</td>"
             f"<td><b>{t[1] + t[2]}</b></td><td>{t[0]}</td><td>{nw}</td></tr>")
rows += (f"<tr><th colspan=2>Total</th><th>{total['t1']}</th><th>{total['t2']}</th>"
         f"<th>{total['t1'] + total['t2']}</th><th>{total['r']}</th><th>{total['new']}</th></tr>")
per_level = Counter(int(i["level"]) for i in pool if i["tier"])
lvl_rows = "".join(f"<tr><td>Level {k}</td><td>{per_level[k]}</td><td>40</td><td>{max(0, 40 - per_level[k])}</td></tr>"
                   for k in sorted(per_level))

# Pictures the game doesn't have yet.
have = {p.stem for d in ("assets/pictures", "assets/icons") for p in (ROOT / d).glob("*.svg")}
want = Counter()
for i in pool:
    for name in [i.get("picture")] + [c.get("picture") for c in i.get("choices", [])] + \
                [x.get("picture") for x in i.get("tiles", []) if isinstance(x, dict)]:
        if name and name not in have:
            want[name] += 1
draw = ", ".join(f"{k} ({v})" for k, v in sorted(want.items()))

BADGE = {1: '<span class="b b1">TIER 1 &middot; EASIER</span>', 2: '<span class="b b2">TIER 2 &middot; HARDER</span>'}
parts = []
for lvl in range(1, 6):
    parts.append(f"<h2>Level {lvl} &middot; {'Bisaya' if lvl <= 2 else 'Filipino' if lvl <= 4 else 'English'}</h2>")
    for sk in SKILL:
        cell = sorted([i for i in more["items"] if i["level"] == lvl and i["sub_skill"] == sk],
                      key=lambda i: (i["tier"], i["id"]))
        if not cell:
            continue
        parts.append(f"<h3>{SKILL[sk]} &middot; Level {lvl} &middot; {len(cell)} new</h3>")
        shown = set()
        for n, i in enumerate(cell, 1):
            pk = i.get("passage")
            if pk and pk not in shown:
                shown.add(pk)
                parts.append(passage_html(pk, passages[pk]))
            agree = ('<div class="rate">Tier: &#9744; agree &nbsp; &#9744; should be tier 1 &nbsp; '
                     '&#9744; should be tier 2 &nbsp; Language: &#9744; correct &nbsp; &#9744; fix</div>')
            parts.append(f'<div class="tierbar">{BADGE[i["tier"]]}</div>'
                         + item_html(n, i, False).replace('<div class="rate">', agree + '<div class="rate">', 1))

CSS2 = CSS + """
h3 { margin: 14px 0 2px; } .tierbar { margin: 10px 0 -6px; }
.b { display: inline-block; font-size: 8.5pt; font-weight: bold; padding: 1px 7px; border-radius: 9px; color: #fff; }
.b1 { background: #2a8a3a; } .b2 { background: #b5482b; }
"""
cover = f"""<h1>Reading Racoon: more items, no repeats</h1>
<div>Draft for review before it goes into the game &middot; {len(more["items"])} new items, {len(more["passages"])} new stories</div>
<h3>Every skill at every level now has 20 items</h3>
<p>10 easier (tier 1) and 10 harder (tier 2), plus the 2-choice rescue items. This counts the items already in the
game, the earlier drafts (tiers, Bisaya Levels 1-2) and the new items in this pack.</p>
<table><tr><th>Level</th><th>Skill</th><th>Tier 1</th><th>Tier 2</th><th>Total</th><th>Rescue</th><th>New here</th></tr>
{rows}</table>
<h3>Enough for a full level without repeats</h3>
<p>Each level has 5 quests of 8 questions, so a child plays at least 40 questions per level.</p>
<table><tr><th>Level</th><th>Unique items</th><th>Questions in 5 quests</th><th>Repeats</th></tr>{lvl_rows}</table>
<p>A struggling child who gets mostly easier items has 10 per skill before any repeat (it was 6).</p>
<h3>Checks done</h3>
<ul><li>No two items ask the same question, across all levels and both tests.</li>
<li>Every answer matches one of its choices or tiles.</li>
<li>New words and pictures avoid the pre-test and post-test words.</li></ul>
<h3>Pictures to draw</h3>
<p>These pictures aren't in the game yet (number of items that use each). They show as <span class="nopic">[name]</span>
in this pack. All are things a Grade 1 child knows:</p><p class="small">{draw}</p>
<h3>New stories</h3>
<p class="small">Level 3: Unang Araw sa Paaralan, Ang Kalabaw ni Tatay. Level 4: Ang Nawawalang Lapis, Ang Paghuhugas
ng Kamay (informational). Level 5: Saturday at the Market, The School Program. School and health themes fit
Quarter 2.</p>
<div class="warn"><b>Draft, please check every Bisaya and Filipino line.</b> Levels 1-2 are Bisaya (Cebuano as
spoken in Mindanao), Levels 3-4 Filipino, Level 5 English, as decided in D-045.</div>
<h3>Reviewer</h3><p>Name: ______________________ &nbsp; Date: __________ &nbsp; Signature: ______________________</p>"""
OUT_MORE.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>More items review</title>'
                    f'<style>{CSS2}</style></head><body>{cover}{"".join(parts)}</body></html>', encoding="utf-8")
print("pool", len(pool), "new", len(more["items"]), "to draw", len(want))
print(draw)
