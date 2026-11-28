"""Language review pack (D-045): Bisaya Levels 1-2 and the Filipino test items.

Usage: python -I build_lang.py <reading-racoon dir> <language-draft.json> <out.html>
"""
import html
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
draft = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
OUT_LANG = pathlib.Path(sys.argv[3])
sys.argv = [sys.argv[0], sys.argv[1], str(OUT_LANG)]
_src = (HERE / "build_review.py").read_text(encoding="utf-8")
exec(_src.split("\npre, post = load")[0])
exec('CSS = """' + _src.split('CSS = """')[1].split('"""')[0] + '"""')

bis = draft["bisaya_levels_1_2"]
ids = [i["id"] for i in bis]
assert len(ids) == len(set(ids)), "duplicate Bisaya id"
for i in bis:
    assert i["answer"] in [c["id"] for c in i.get("choices", [])] or i["task_type"] == "order_tiles", i["id"]
    if i["task_type"] == "order_tiles":
        assert i["answer"] == "|".join(i["tiles"]), i["id"]

BADGE = {0: '<span class="b b0">RESCUE</span>', 1: '<span class="b b1">TIER 1 &middot; EASIER</span>',
         2: '<span class="b b2">TIER 2 &middot; HARDER</span>'}
REASON = {
    "phonological_awareness": "Tier 1: a common rhyme or a long first sound (m, s, a). Tier 2: more choices, "
                              "stop sounds (b), vowels that sound alike (i, o, u), more syllables.",
    "phonics": "Tier 1: the first letter or a letter's sound. Tier 2: look-alike letters (b, d, p), the middle or "
               "last letter, near-miss words.",
    "vocabulary": "Tier 1: listen and tap a picture. Tier 2: read the word yourself, describing words, "
                  "sight words among look-alikes.",
}
WORDS = ("iring cat, iro dog, isda fish, saging banana, manok hen, baki frog, kalo hat, kahon box, bituon star, "
         "bulan moon, adlaw sun, sakayan boat, kanding goat, gunting scissors, libro book, lapis pencil, bola ball, "
         "ubas grapes, peras pear, oso bear, ilaga mouse, hulmigas ant, bitin snake, elepante elephant, "
         "alibangbang butterfly, mansanas apple, awto car")

parts = []
for lvl in (1, 2):
    parts.append(f"<h2>Part {'AB'[lvl - 1]}. Level {lvl} in Bisaya</h2>")
    for sk in SKILL:
        cell = sorted([i for i in bis if i["level"] == lvl and i["sub_skill"] == sk],
                      key=lambda i: (i["tier"] == 0, i["tier"], i["id"]))
        if not cell:
            continue
        parts.append(f'<h3>{SKILL[sk]} &middot; Level {lvl}</h3><div class="small">{REASON[sk]}</div>')
        for n, i in enumerate(cell, 1):
            agree = ('<div class="rate">Tier: &#9744; agree &nbsp; &#9744; should be tier 1 &nbsp; '
                     '&#9744; should be tier 2 &nbsp; Bisaya: &#9744; correct &nbsp; &#9744; fix</div>'
                     if i["tier"] else '<div class="rate">Bisaya: &#9744; correct &nbsp; &#9744; fix</div>')
            parts.append(f'<div class="tierbar">{BADGE[i["tier"]]}</div>'
                         + item_html(n, i, False).replace('<div class="rate">', agree + '<div class="rate">', 1))

for key, title, part in (("pre", "Pre-test (Form A)", "C"), ("post", "Post-test (Form B)", "D")):
    old = {i["id"]: i for i in load(f"{key}test.json")["items"]}
    passages = draft["test_passages"]
    parts.append(f"<h2>Part {part}. {title}: items now in Filipino</h2><p>These replace the English items with the "
                 "same id. The other test items are already Filipino and don't change. Rate relevance 1-4 as before.</p>")
    shown = set()
    for n, i in enumerate(draft["tests_filipino"][key], 1):
        pk = i.get("passage")
        if pk and pk not in shown:
            shown.add(pk)
            parts.append(passage_html(pk, passages[pk]))
        was = old[i["id"]]
        note = (f'<div class="was"><b>Replaces (English):</b> {html.escape(was["prompt"])} '
                f'&rarr; answer <i>{html.escape(str(was["answer"]))}</i></div>')
        parts.append(item_html(n, i, True).replace('<div class="rate">', note + '<div class="rate">', 1))

CSS2 = CSS + """
h3 { margin: 14px 0 2px; } .tierbar { margin: 10px 0 -6px; }
.b { display: inline-block; font-size: 8.5pt; font-weight: bold; padding: 1px 7px; border-radius: 9px; color: #fff; }
.b1 { background: #2a8a3a; } .b2 { background: #b5482b; } .b0 { background: #777; }
.was { font-size: 9pt; background: #eef2fb; border-left: 3px solid #2b5fb5; padding: 2px 6px; margin: 3px 0; }
"""
n1 = sum(1 for i in bis if i["level"] == 1)
n2 = len(bis) - n1
cover = f"""<h1>Reading Racoon: lesson language</h1>
<div>Draft for review before it goes into the game &middot; decision D-045</div>
<h3>What changes</h3>
<table><tr><th>Part of the game</th><th>Before</th><th>After</th></tr>
<tr><td>Levels 1-2</td><td>English</td><td><b>Bisaya</b> (learners' first language)</td></tr>
<tr><td>Levels 3-4</td><td>Filipino</td><td>Filipino (no change)</td></tr>
<tr><td>Level 5</td><td>English</td><td>English, adventure extension only</td></tr>
<tr><td>Pre-test and post-test</td><td>Mixed (about 10 English items each)</td><td><b>All Filipino</b></td></tr></table>
<p><b>Why.</b> MATATAG Grade 1 Reading and Literacy is taught in the learner's first language, and ARAL KS1 teaches
Filipino before English. An English item can be failed for not knowing English instead of for not reading, which
would weaken the pre/post results.</p>
<p><b>Levels 1-2 are rewritten, not translated.</b> Bisaya reading works by syllables (pantig), so the items follow
ARAL's letter order (m, s, a, i, o, b, u in Level 1, then k, l, t, n, g, p in Level 2): first sounds, letters,
rhymes, clapping syllables, building words from syllables, spinning syllables, and Bisaya sight words (ang, si, sa,
ug, mga). Level 2 vocabulary uses school words for Quarter 2. Each skill has 12 items, 6 easier and 6 harder, plus
the 2-choice rescue items. In total: {n1} items in Level 1 and {n2} in Level 2.</p>
<p><b>The English Level 1-2 items retire</b>, including the English new items in the earlier tier pack.</p>
<p><b>No item repeats a test word.</b> The tests use different pictures and words from the Bisaya lessons
(for example the tests rhyme puso/aso and ibon/kahon; the lessons rhyme iring/saging and kahon/bituon).</p>
<h3>Picture names used</h3><p class="small">{WORDS}. Please mark any picture whose Bisaya name isn't the one
the children use at home.</p>
<div class="warn"><b>Draft, please check every Bisaya and Filipino line.</b> The Bisaya is Cebuano as spoken in
Mindanao; Butuanon words may differ. <b>No lesson or test line has a recorded voice yet</b> (in any language), so
the buddy doesn't read these prompts aloud: a teacher or helper must read them for non-readers, or the lines
need recording before Tuesday.</div>
<h3>Reviewer</h3><p>Name: ______________________ &nbsp; Date: __________ &nbsp; Signature: ______________________</p>"""
OUT_LANG.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>Lesson language review</title>'
                    f'<style>{CSS2}</style></head><body>{cover}{"".join(parts)}</body></html>', encoding="utf-8")
print("Bisaya", len(bis), "tests", sum(len(v) for v in draft["tests_filipino"].values()))
