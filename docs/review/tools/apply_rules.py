"""Merge every draft into one full content draft (v2) and apply the review rules.

Rules (user review 2026-11-27):
- Sounds, letter names and words to find are heard (speaker button), not shown.
- Rhymes and spin wheels say the word (spoken and on the speaker, never written); other picture tasks
  never say or show the name (it comes in the hint).
- No written words next to a picture: comprehension cards and story tiles show the picture; the buddy reads
  the card aloud when it's tapped.
- Picture cards in sound, letter and vocabulary tasks have no labels (numbers stay).
- Harder spin items become a combination lock: two rings of 8 syllables.
Usage: python -I apply_rules.py <reading-racoon dir> <review dir> <out.json>
"""
import copy
import json
import pathlib
import re
import sys

ROOT, REV, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
rd = lambda p: json.loads(pathlib.Path(p).read_text(encoding="utf-8"))
tier_draft = rd(REV / "tier-draft.json")
lang = rd(REV / "language-draft.json")
more = rd(REV / "more-items-draft.json")

levels, passages = [], {}
for n in ("levels_3.json", "levels_4.json", "levels_5.json"):
    d = rd(ROOT / "content" / n)
    levels += d["items"]
    passages.update(d.get("passages", {}))
for i in levels:
    i["tier"] = 0 if i.get("recovery") else tier_draft["tiers"][i["id"]]
levels += [i for i in tier_draft["new_items"] if i["level"] >= 3]
levels += lang["bisaya_levels_1_2"] + more["items"]
passages.update(more["passages"])
levels = copy.deepcopy(levels)


def test(kind):
    d = rd(ROOT / "content" / f"{kind}test.json")
    repl = {i["id"]: i for i in lang["tests_filipino"][kind]}
    items = [copy.deepcopy(repl.get(i["id"], i)) for i in d["items"]]
    ps = dict(d["passages"])
    ps.update({k: v for k, v in lang["test_passages"].items() if k in ps})
    return {"kind": kind, "items": items, "passages": ps}


tests = {"pre": test("pre"), "post": test("post")}

# ---------- content fixes from the review ----------
by_id = {i["id"]: i for i in levels}
fix = by_id["pa1-b14"]          # tasa rhymes with kalabasa, not lamesa
fix["choices"] = [{"id": "dog", "label": "iro", "picture": "dog"},
                  {"id": "pumpkin", "label": "kalabasa", "picture": "pumpkin"},
                  {"id": "hat", "label": "kalo", "picture": "hat"}]
fix["answer"] = "pumpkin"
fix = by_id["pa1-b15"]          # mangga/ilaga was a weak rhyme: unggoy/baboy
fix.update({"picture": "monkey", "word": "unggoy", "answer": "pig",
            "choices": [{"id": "banana", "label": "saging", "picture": "banana"},
                        {"id": "ball", "label": "bola", "picture": "ball"},
                        {"id": "pig", "label": "baboy", "picture": "pig"},
                        {"id": "sun", "label": "adlaw", "picture": "sun"}]})

# Harder spin items -> combination lock (two rings of 8 syllables).
LOCKS = {
    "ph2-b03": ("hat", ["ka", "ki", "ko", "ku", "ba", "la", "ma", "sa"], ["lo", "la", "li", "lu", "so", "to", "bo", "mo"], "ka|lo"),
    "ph2-b04": ("frog", ["ba", "bi", "bo", "bu", "ka", "da", "pa", "ta"], ["ki", "ka", "ko", "ku", "ti", "li", "si", "ni"], "ba|ki"),
    "ph3-08": ("bear", ["o", "a", "i", "u", "ba", "ka", "ma", "la"], ["so", "sa", "si", "su", "to", "lo", "ko", "no"], "o|so"),
    "ph3-09": ("duck", ["pa", "pi", "po", "pu", "ba", "ma", "ta", "ka"], ["to", "ta", "ti", "tu", "so", "lo", "ko", "bo"], "pa|to"),
    "ph3-20": ("balloon", ["lo", "la", "li", "lu", "bo", "ko", "mo", "so"], ["bo", "ba", "bi", "bu", "lo", "so", "to", "ko"], "lo|bo"),
}
for iid, (pic, r1, r2, ans) in LOCKS.items():
    i = by_id[iid]
    for k in ("choices", "rime", "variant"):
        i.pop(k, None)
    i.update({"task_type": "combo_lock", "picture": pic, "rings": [r1, r2], "answer": ans,
              "name": ans.replace("|", ""), "competency": "RL1PWS-II-4"})

# ---------- the rules ----------
TXT = {
    "bis": dict(
        rhyme=("Asa ang katugma sa pulong nga imong nadungog?", "Asa ang katugma sa {w}?"),
        sound=("Asa ang nagsugod sa tingog nga imong nadungog?",
               "Pindota ang speaker aron maminaw sa tingog. Asa ang nagsugod niini nga tingog?"),
        letter_sound=("Unsang letra ang tingog nga imong nadungog?",
                      "Pindota ang speaker aron maminaw. Unsang letra ang naay ingon ani nga tingog?"),
        letter_name=("Pindota ang letra nga imong nadungog.",
                     "Pindota ang speaker aron maminaw. Pindota ang letra nga imong nadungog."),
        word=("Pindota ang pulong nga imong nadungog.",
              "Pindota ang speaker aron maminaw. Pindota ang pulong nga imong nadungog."),
        first=("Nagsugod kini sa unsang letra?", "Tan-awa ang hulagway. Nagsugod ang ngalan niini sa unsang letra?"),
        clap=("Pila ka pantig ang ngalan niini?", "Isulti ang ngalan niini samtang mopakpak. Pila ka pakpak?"),
        build=("Buhata ang ngalan niini.", "Pindota ang mga pantig aron mahimo ang ngalan niini."),
        spin=("Tuyoka aron mahimo ang pulong nga imong nadungog.", "{W}. Tuyoka ang ligid aron mahimo ang pulong {w}."),
        drag=("Himoa ang ngalan niini.", "Ibalhin ang kulang nga letra aron mahimo ang ngalan niini nga hulagway."),
        lock=("Ablihi ang kandado: himoa ang pulong nga imong nadungog.",
              "{W}. Tuyoka ang duha ka ligid aron mahimo ang pulong {w}."),
        name="Ang ngalan niini kay {w}."),
    "fil": dict(
        rhyme=("Alin ang katugma ng salitang narinig mo?", "Alin ang katugma ng {w}?"),
        sound=("Alin ang nagsisimula sa tunog na narinig mo?",
               "Pindutin ang speaker para marinig ang tunog. Alin ang nagsisimula sa tunog na ito?"),
        letter_sound=("Aling titik ang tunog na narinig mo?",
                      "Pindutin ang speaker para makinig. Aling titik ang may ganitong tunog?"),
        letter_name=("Pindutin ang titik na narinig mo.", "Pindutin ang speaker para makinig. Pindutin ang titik na narinig mo."),
        word=("Pindutin ang salitang narinig mo.", "Pindutin ang speaker para makinig. Pindutin ang salitang narinig mo."),
        first=("Nagsisimula ito sa anong titik?", "Tingnan ang larawan. Sa anong titik nagsisimula ang pangalan nito?"),
        clap=("Ilang pantig ang pangalan nito?", "Sabihin ang pangalan nito habang pumapalakpak. Ilang palakpak?"),
        build=("Buuin ang pangalan nito.", "Pindutin ang mga pantig para mabuo ang pangalan nito."),
        spin=("Paikutin para mabuo ang salitang narinig mo.", "{W}. Paikutin ang gulong para mabuo ang salitang {w}."),
        drag=("Buuin ang pangalan nito.", "Ilipat ang kulang na titik para mabuo ang pangalan nito."),
        lock=("Buksan ang kandado: buuin ang salitang narinig mo.",
              "{W}. Paikutin ang dalawang gulong para mabuo ang salitang {w}."),
        name="Ang pangalan nito ay {w}."),
}
WORD_FIND = [r"^Asa ang pulong (\S+?)\?$", r"^Pindota ang pulong (\S+?)\.$", r"^Pindutin ang salitang (\S+?)\.$"]
LETTER = r"(?:letra|titik|letter) ([a-zñ])\.?$"
FIRST = [r"^Ang (\S+) nagsugod sa unsang letra", r"^(\S+) starts with which letter"]
counts = {}


def name_of(i, old_prompt):
    if i.get("word"):
        return i["word"]
    t = i["task_type"]
    if t == "order_tiles" and i.get("variant") == "syllables":
        return "".join(i["answer"].split("|"))
    if t == "drag_letter":
        return "".join(i["answer"] if x == "_" else x for x in i["pattern"])
    if t == "spin_words":
        return i["answer"] + i["rime"]
    if t == "combo_lock":
        return i["name"]
    for rx in FIRST:
        m = re.match(rx, old_prompt)
        if m:
            return m.group(1).lower()
    return None


def apply(i):
    lg = i["language"][:3]
    if lg not in TXT:
        return
    T, p, code, t = TXT[lg], i["prompt"], i["competency"], i["task_type"]
    kind = None
    if code.startswith("RL1PA-I-5"):
        kind, i["audio"] = "sound", {"kind": "sound", "value": re.search(r"/([a-zñ]+)/", p).group(1)}
    elif "/" in p and code.startswith("RL1PWS"):
        kind, i["audio"] = "letter_sound", {"kind": "sound", "value": re.search(r"/([a-zñ]+)/", p).group(1)}
    elif re.search(LETTER, p) and t == "tap_choice":
        kind, i["audio"] = "letter_name", {"kind": "letter", "value": re.search(LETTER, p).group(1)}
    elif any(re.match(rx, p) for rx in WORD_FIND) and t == "tap_choice" and not i["choices"][0].get("picture"):
        w = next(re.match(rx, p).group(1) for rx in WORD_FIND if re.match(rx, p))
        kind, i["audio"] = "word", {"kind": "word", "value": w}
    elif code.startswith(("RL1PA-I-3", "RL1PA-I-4")) and i.get("picture"):
        kind = "rhyme"
    elif code.startswith("RL1PA-I-2") and t == "tap_choice":
        kind = "clap"
    elif t == "order_tiles" and i.get("variant") == "syllables":
        kind = "build"
    elif t == "spin_words":
        kind = "spin"
    elif t == "combo_lock":
        kind = "lock"
    elif t == "drag_letter":
        kind = "drag"
    elif code.startswith("RL1PWS") and t == "tap_choice" and i.get("picture"):
        kind = "first"
    if not kind:
        return
    name = name_of(i, p)
    i["prompt"], i["tts_text"] = (x.format(w=name, W=(name or "").capitalize()) for x in T[kind])
    counts[kind] = counts.get(kind, 0) + 1
    # Rhymes and word-making wheels say the word; the other picture tasks let the child name it.
    if kind in ("clap", "rhyme", "spin", "lock"):
        i.pop("word", None)
    if kind in ("rhyme", "spin", "lock") and name:
        i["audio"] = {"kind": "word", "value": name}
    if name and not i.get("hint") and kind in ("first", "clap", "build", "drag"):
        i["hint"] = T["name"].format(w=name)
        i["explain"] = T["name"].format(w=name)
    if name:
        i["picture_name"] = name


def strip_labels(i):
    if i["sub_skill"] == "literal_comprehension":
        for c in i.get("choices", []):
            if c.get("picture") and c.get("label"):
                c["say"] = c.pop("label")
        tiles = [x for x in i.get("tiles", []) if isinstance(x, dict)]
        if tiles and all(x.get("picture") for x in tiles):
            for x in tiles:
                x["say"] = x.pop("text")
        else:
            for x in tiles:  # some tiles have no picture: keep words, drop pictures
                x.pop("picture", None)
    if i["sub_skill"] in ("phonological_awareness", "phonics", "vocabulary") and i["task_type"] == "tap_choice":
        for c in i.get("choices", []):
            if c.get("picture") and "label" in c and not str(c["label"]).isdigit():
                c.pop("label")


for i in levels + tests["pre"]["items"] + tests["post"]["items"]:
    apply(i)
    strip_labels(i)

json.dump({"note": "FULL CONTENT DRAFT v2 for teacher review (D-045 languages, tiers, no repeats, review rules of "
                   "2026-11-27). Not in the game yet.",
           "levels": {"items": levels, "passages": passages}, "pretest": tests["pre"], "posttest": tests["post"]},
          open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
print(len(levels), "adventure items;", "rewritten:", counts)
