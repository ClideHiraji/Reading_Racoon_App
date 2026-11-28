"""Tier review pack: existing adventure items with their proposed tier, plus the new items.

Usage: python -I build_tiers.py <reading-racoon dir> <draft.json> <out.html>
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
draft = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
OUT_TIERS = pathlib.Path(sys.argv[3])
sys.argv = [sys.argv[0], sys.argv[1], str(OUT_TIERS)]
# Reuse the item layout from the first pack (everything before its main part).
_src = (HERE / "build_review.py").read_text(encoding="utf-8")
exec(_src.split("\npre, post = load")[0])
exec('CSS = """' + _src.split('CSS = """')[1].split('"""')[0] + '"""')

levels = load("levels.json")
for n in (3, 4, 5):
    d = load(f"levels_{n}.json")
    levels["items"] += d["items"]
    levels.setdefault("passages", {}).update(d.get("passages", {}))

tiers = draft["tiers"]
items = []
for i in levels["items"]:
    if i.get("recovery"):
        i["tier"] = 0
    else:
        assert i["id"] in tiers, f"no tier for {i['id']}"
        i["tier"] = tiers[i["id"]]
    items.append(i)
assert len(tiers) == sum(1 for i in items if not i.get("recovery")), "tier list has unknown ids"
ids = {i["id"] for i in items}
for n in draft["new_items"]:
    assert n["id"] not in ids, f"duplicate id {n['id']}"
    assert n.get("passage") is None or n["passage"] in levels["passages"], n["id"]
    items.append(n)

BADGE = {0: '<span class="b b0">RESCUE</span>', 1: '<span class="b b1">TIER 1 &middot; EASIER</span>',
         2: '<span class="b b2">TIER 2 &middot; HARDER</span>'}
order = list(SKILL)
cells = {}
for i in items:
    cells.setdefault((int(i["level"]), i["sub_skill"]), []).append(i)

rows = ""
for (lvl, sk) in sorted(cells, key=lambda k: (k[0], order.index(k[1]))):
    c = cells[(lvl, sk)]
    t1 = sum(1 for i in c if i["tier"] == 1)
    t2 = sum(1 for i in c if i["tier"] == 2)
    r = sum(1 for i in c if i["tier"] == 0)
    nw = sum(1 for i in c if i.get("new"))
    rows += (f"<tr><td>Level {lvl}</td><td>{SKILL[sk]}</td><td>{t1}</td><td>{t2}</td><td>{t1 + t2}</td>"
             f"<td>{r}</td><td>{nw}</td></tr>")

parts = []
for lvl in range(1, 6):
    parts.append(f"<h2>Level {lvl}</h2>")
    for sk in order:
        c = cells.get((lvl, sk))
        if not c:
            continue
        c.sort(key=lambda i: (i["tier"] == 0, i["tier"], i["id"]))
        parts.append(f'<h3>{SKILL[sk]} &middot; Level {lvl}</h3><div class="small">{draft["reasons"][sk]}</div>')
        shown, n = set(), 0
        for i in c:
            pk = i.get("passage")
            if pk and pk not in shown:
                shown.add(pk)
                parts.append(passage_html(pk, levels["passages"][pk]))
            n += 1
            new = '<span class="b bn">NEW</span>' if i.get("new") else ""
            agree = ('<div class="rate">Tier: &#9744; agree &nbsp; &#9744; should be tier 1 &nbsp; '
                     '&#9744; should be tier 2</div>' if i["tier"] else "")
            parts.append(f'<div class="tierbar">{BADGE[i["tier"]]} {new}</div>'
                         + item_html(n, i, False).replace('<div class="rate">', agree + '<div class="rate">', 1))

CSS2 = CSS + """
h3 { margin: 14px 0 2px; } .tierbar { margin: 10px 0 -6px; }
.b { display: inline-block; font-size: 8.5pt; font-weight: bold; padding: 1px 7px; border-radius: 9px; color: #fff; }
.b1 { background: #2a8a3a; } .b2 { background: #b5482b; } .b0 { background: #777; } .bn { background: #2b5fb5; }
"""
total_new = len(draft["new_items"])
cover = f"""<h1>Reading Racoon: easier and harder items</h1>
<div>Draft for review before it goes into the game &middot; adventure levels 1-5</div>
<h3>What changes</h3>
<p><b>1. Easier and harder items in every level.</b> Each adventure item gets a tier: <b>Tier 1 (easier)</b> or
<b>Tier 2 (harder)</b>. The game will choose:</p>
<ul><li>a <b>Tier 1</b> item right after a wrong answer, or when the child's mastery of that skill is still low
(below 0.50);</li>
<li>a <b>Tier 2</b> item when mastery is high (0.70 or more);</li>
<li>either tier in between.</li></ul>
<p>If a tier has no unused item left, the game uses the other tier. Rescue items (grey) stay as they are: they are
the 2-choice items for Roco's Rescue. Mastery is still counted the same way for both tiers.</p>
<p><b>2. Placement can skip further.</b> Today even a perfect pre-test starts a child at Level 2. After the change,
the pre-test's Level 3-5 items also count, so a strong reader can start at Level 3 or 4. Every skipped level is
still recorded as mastered, with the pre-test answers as the evidence.</p>
<p><b>3. Bigger item pools.</b> {total_new} new items (blue <b>NEW</b>) bring every skill at every level to
12 items plus rescue items, so a child who needs many tries sees fewer repeats. New items use Quarter 2 codes and the
school theme, and none repeat a pre-test or post-test item.</p>
<h3>Items per skill and level</h3>
<table><tr><th>Level</th><th>Skill</th><th>Tier 1</th><th>Tier 2</th><th>Total</th><th>Rescue</th><th>New</th></tr>
{rows}</table>
<h3>How to review</h3>
<p>For each item, tick whether you agree with its tier, then Approve or Revise it. Write a better word or picture
on the comment line. New items also need the usual check: one clear name for each picture, right answer, fair
wrong answers.</p>
<div class="warn"><b>Draft.</b> Nothing here is in the game yet. Languages follow the current plan (Levels 1-2 and 5
English, Levels 3-4 Filipino) until the teachers decide.</div>
<h3>Reviewer</h3><p>Name: ______________________ &nbsp; Date: __________ &nbsp; Signature: ______________________</p>"""
OUT_TIERS.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>Tier review pack</title>'
                     f'<style>{CSS2}</style></head><body>{cover}{"".join(parts)}</body></html>', encoding="utf-8")
print("items", len(items), "new", total_new)
