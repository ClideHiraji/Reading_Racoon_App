"""Language draft (D-045): Bisaya Levels 1-2, and the English test items in Filipino.

Usage: python -I make_lang.py <out.json>
"""
import json
import sys

BIS, FIL = "bis-placeholder", "fil-placeholder"
PA, PH, VO, FL, LC = ("phonological_awareness", "phonics", "vocabulary", "fluency", "literal_comprehension")
TAP, DRAG, ORDER, SPIN = "tap_choice", "drag_letter", "order_tiles", "spin_words"


def ch(cid, label=None, picture=None, repeat=None):
    c = {"id": cid}
    if label is not None:
        c["label"] = label
    if picture:
        c["picture"] = picture
    if repeat:
        c["repeat"] = repeat
    return c


def it(id, skill, level, code, tier, task, prompt, tts, answer, choices=None, lang=BIS, rescue=False, **extra):
    d = {"id": id, "sub_skill": skill, "level": level, "competency": code, "language": lang,
         "task_type": task, "prompt": prompt, "tts_text": tts}
    d.update(extra)
    if choices is not None:
        d["choices"] = choices
    d["answer"] = answer
    if lang == BIS:
        d.update({"recovery": rescue, "tier": 0 if rescue else tier, "new": True})
    return d


def p(name, word):
    """A picture card with its Bisaya or Filipino name."""
    return ch(name, word, name)


def letters(*xs):
    return [ch(x, x) for x in xs]


def claps(n, *opts):
    return [ch(str(k), str(k), "hand", k) for k in opts]


T1, T2 = 1, 2
bis = [
    # ---------- Level 1, phonological awareness: rhyme and first sounds ----------
    it("pa1-b01", PA, 1, "RL1PA-I-3", T1, TAP, "Asa ang katugma sa iring?", "Asa ang katugma sa iring?", "banana",
       [p("banana", "saging"), p("dog", "iro"), p("sun", "adlaw")], picture="cat", word="iring"),
    it("pa1-b02", PA, 1, "RL1PA-I-3", T1, TAP, "Asa ang katugma sa kahon?", "Asa ang katugma sa kahon?", "star",
       [p("fish", "isda"), p("star", "bituon"), p("hen", "manok")], picture="box", word="kahon", variant="rhyme_pop"),
    it("pa1-b03", PA, 1, "RL1PA-I-3", T1, TAP, "Asa ang katugma sa ubas?", "Asa ang katugma sa ubas?", "pear",
       [p("frog", "baki"), p("hat", "kalo"), p("pear", "peras")], picture="grapes", word="ubas"),
    it("pa1-b04", PA, 1, "RL1PA-I-3", T2, TAP, "Asa ang katugma sa bulan?", "Asa ang katugma sa bulan?", "boat",
       [p("dog", "iro"), p("boat", "sakayan"), p("box", "kahon"), p("ball", "bola")], picture="moon", word="bulan"),
    it("pa1-b05", PA, 1, "RL1PA-I-3", T2, TAP, "Asa ang katugma sa kanding?", "Asa ang katugma sa kanding?",
       "scissors", [p("ball", "bola"), p("fish", "isda"), p("scissors", "gunting"), p("sun", "adlaw")],
       picture="goat", word="kanding", variant="rhyme_pop"),
    it("pa1-b06", PA, 1, "RL1PA-I-3", T2, TAP, "Asa ang katugma sa iro?", "Asa ang katugma sa iro?", "book",
       [p("hen", "manok"), p("grapes", "ubas"), p("book", "libro"), p("moon", "bulan")], picture="dog", word="iro"),
    it("pa1-b07", PA, 1, "RL1PA-I-5", T1, TAP, "Asa ang nagsugod sa /m/?",
       "Asa ang nagsugod sa tingog mmm, sama sa mama?", "hen", [p("hen", "manok"), p("dog", "iro"), p("sun", "adlaw")]),
    it("pa1-b08", PA, 1, "RL1PA-I-5", T1, TAP, "Asa ang nagsugod sa /s/?",
       "Asa ang nagsugod sa tingog sss, sama sa sapatos?", "banana",
       [p("hat", "kalo"), p("banana", "saging"), p("ball", "bola")]),
    it("pa1-b09", PA, 1, "RL1PA-I-5", T1, TAP, "Asa ang nagsugod sa /a/?",
       "Asa ang nagsugod sa tingog a, sama sa amahan?", "sun",
       [p("fish", "isda"), p("bear", "oso"), p("sun", "adlaw")]),
    it("pa1-b10", PA, 1, "RL1PA-I-5", T2, TAP, "Asa ang nagsugod sa /b/?",
       "Asa ang nagsugod sa tingog b, sama sa baboy?", "frog",
       [p("pear", "peras"), p("frog", "baki"), p("hen", "manok")]),
    it("pa1-b11", PA, 1, "RL1PA-I-5", T2, TAP, "Asa ang nagsugod sa /i/?",
       "Asa ang nagsugod sa tingog i, sama sa ilong?", "fish",
       [p("grapes", "ubas"), p("bear", "oso"), p("fish", "isda")]),
    it("pa1-b12", PA, 1, "RL1PA-I-5", T2, TAP, "Asa ang nagsugod sa /o/?",
       "Asa ang nagsugod sa tingog o, sama sa okra?", "bear",
       [p("bear", "oso"), p("grapes", "ubas"), p("fish", "isda")]),
    it("pa1-br1", PA, 1, "RL1PA-I-3", 0, TAP, "Asa ang katugma sa iring?", "Asa ang katugma sa iring?", "banana",
       [p("banana", "saging"), p("dog", "iro")], rescue=True, picture="cat", word="iring"),
    it("pa1-br2", PA, 1, "RL1PA-I-5", 0, TAP, "Asa ang nagsugod sa /m/?",
       "Asa ang nagsugod sa tingog mmm, sama sa mama?", "hen", [p("hen", "manok"), p("fish", "isda")], rescue=True),
    it("pa1-br3", PA, 1, "RL1PA-I-5", 0, TAP, "Asa ang nagsugod sa /s/?",
       "Asa ang nagsugod sa tingog sss, sama sa sapatos?", "banana", [p("ball", "bola"), p("banana", "saging")],
       rescue=True),
    # ---------- Level 1, phonics: letters m s a i o b u ----------
    it("ph1-b01", PH, 1, "RL1PWS-II-1", T1, TAP, "Unsang letra ang naay tingog /m/?",
       "Unsang letra ang naay tingog mmm?", "m", letters("m", "s", "a")),
    it("ph1-b02", PH, 1, "RL1PWS-II-1", T1, TAP, "Unsang letra ang naay tingog /s/?",
       "Unsang letra ang naay tingog sss?", "s", letters("s", "m", "b")),
    it("ph1-b03", PH, 1, "RL1PWS-II-2", T1, TAP, "Pindota ang letra a.", "Pindota ang letra a.", "a",
       letters("o", "a", "u")),
    it("ph1-b04", PH, 1, "RL1PWS-II-3", T1, TAP, "Ang manok nagsugod sa unsang letra?",
       "Manok. Ang manok nagsugod sa unsang letra?", "m", letters("m", "s", "b"), picture="hen"),
    it("ph1-b05", PH, 1, "RL1PWS-II-3", T1, TAP, "Ang saging nagsugod sa unsang letra?",
       "Saging. Ang saging nagsugod sa unsang letra?", "s", letters("a", "s", "m"), picture="banana"),
    it("ph1-b06", PH, 1, "RL1PWS-II-3", T1, TAP, "Ang isda nagsugod sa unsang letra?",
       "Isda. Ang isda nagsugod sa unsang letra?", "i", letters("i", "o", "a"), picture="fish"),
    it("ph1-b07", PH, 1, "RL1PWS-II-2", T2, TAP, "Pindota ang letra b.", "Pindota ang letra b.", "b",
       letters("d", "b", "p")),
    it("ph1-b08", PH, 1, "RL1PWS-II-3", T2, TAP, "Ang oso nagsugod sa unsang letra?",
       "Oso. Ang oso nagsugod sa unsang letra?", "o", letters("u", "a", "o"), picture="bear"),
    it("ph1-b09", PH, 1, "RL1PWS-II-3", T2, TAP, "Ang ubas nagsugod sa unsang letra?",
       "Ubas. Ang ubas nagsugod sa unsang letra?", "u", letters("o", "u", "i"), picture="grapes"),
    it("ph1-b10", PH, 1, "RL1PWS-II-3", T2, DRAG, "Himoa ang pulong kalo.",
       "Kalo. Ibalhin ang kulang nga letra aron mahimo ang kalo.", "a", letters("o", "a", "u"),
       picture="hat", pattern=["k", "_", "l", "o"]),
    it("ph1-b11", PH, 1, "RL1PWS-II-3", T2, DRAG, "Himoa ang pulong saging.",
       "Saging. Ibalhin ang kulang nga letra aron mahimo ang saging.", "i", letters("a", "u", "i"),
       picture="banana", pattern=["s", "a", "g", "_", "n", "g"]),
    it("ph1-b12", PH, 1, "RL1PWS-II-3", T2, DRAG, "Himoa ang pulong oso.",
       "Oso. Ibalhin ang kulang nga letra aron mahimo ang oso.", "o", letters("a", "o", "u"),
       picture="bear", pattern=["o", "s", "_"]),
    it("ph1-br1", PH, 1, "RL1PWS-II-1", 0, TAP, "Unsang letra ang naay tingog /m/?",
       "Unsang letra ang naay tingog mmm?", "m", letters("m", "s"), rescue=True),
    it("ph1-br2", PH, 1, "RL1PWS-II-3", 0, TAP, "Ang manok nagsugod sa unsang letra?",
       "Manok. Ang manok nagsugod sa unsang letra?", "m", letters("b", "m"), rescue=True, picture="hen"),
    it("ph1-br3", PH, 1, "RL1PWS-II-2", 0, TAP, "Pindota ang letra a.", "Pindota ang letra a.", "a",
       letters("a", "o"), rescue=True),
    # ---------- Level 2, phonological awareness: syllables (pantig) and rhyme ----------
    it("pa2-b01", PA, 2, "RL1PA-I-2", T1, TAP, "Pila ka pantig ang iro?", "Pakpak uban nako. I. Ro. Pila ka pakpak?",
       "2", claps(2, 1, 2, 3), picture="dog", word="iro",
       hint="Pakpak uban nako: i, ro. Ihapa ang matag pakpak.", explain="I-ro adunay 2 ka pakpak."),
    it("pa2-b02", PA, 2, "RL1PA-I-2", T1, TAP, "Pila ka pantig ang isda?",
       "Pakpak uban nako. Is. Da. Pila ka pakpak?", "2", claps(2, 1, 2, 3), picture="fish", word="isda",
       hint="Pakpak uban nako: is, da. Ihapa ang matag pakpak.", explain="Is-da adunay 2 ka pakpak."),
    it("pa2-b03", PA, 2, "RL1PA-I-2", T1, TAP, "Pila ka pantig ang bola?",
       "Pakpak uban nako. Bo. La. Pila ka pakpak?", "2", claps(2, 1, 2, 3), picture="ball", word="bola",
       hint="Pakpak uban nako: bo, la. Ihapa ang matag pakpak.", explain="Bo-la adunay 2 ka pakpak."),
    it("pa2-b04", PA, 2, "RL1PA-I-2", T2, TAP, "Pila ka pantig ang mansanas?",
       "Pakpak uban nako. Man. Sa. Nas. Pila ka pakpak?", "3", claps(3, 1, 2, 3), picture="apple",
       word="mansanas", hint="Pakpak uban nako: man, sa, nas. Ihapa ang matag pakpak.",
       explain="Man-sa-nas adunay 3 ka pakpak."),
    it("pa2-b05", PA, 2, "RL1PA-I-2", T2, TAP, "Pila ka pantig ang elepante?",
       "Pakpak uban nako. E. Le. Pan. Te. Pila ka pakpak?", "4", claps(4, 2, 3, 4), picture="elephant",
       word="elepante", hint="Pakpak uban nako: e, le, pan, te. Ihapa ang matag pakpak.",
       explain="E-le-pan-te adunay 4 ka pakpak."),
    it("pa2-b06", PA, 2, "RL1PA-I-2", T2, TAP, "Pila ka pantig ang alibangbang?",
       "Pakpak uban nako. A. Li. Bang. Bang. Pila ka pakpak?", "4", claps(4, 2, 3, 4), picture="butterfly",
       word="alibangbang", hint="Pakpak uban nako: a, li, bang, bang. Ihapa ang matag pakpak.",
       explain="A-li-bang-bang adunay 4 ka pakpak."),
    it("pa2-b07", PA, 2, "RL1PA-I-2", T1, ORDER, "Buhata ang pulong baki.",
       "Ba. Ki. Pindota ang mga pantig aron mahimo ang baki.", "ba|ki", picture="frog", variant="syllables",
       tiles=["ba", "ki"]),
    it("pa2-b08", PA, 2, "RL1PA-I-2", T2, ORDER, "Buhata ang pulong kanding.",
       "Kan. Ding. Pindota ang mga pantig aron mahimo ang kanding.", "kan|ding", picture="goat",
       variant="syllables", tiles=["kan", "ding"]),
    it("pa2-b09", PA, 2, "RL1PA-I-2", T2, ORDER, "Buhata ang pulong ilaga.",
       "I. La. Ga. Pindota ang mga pantig aron mahimo ang ilaga.", "i|la|ga", picture="mouse",
       variant="syllables", tiles=["i", "la", "ga"]),
    it("pa2-b10", PA, 2, "RL1PA-I-4", T1, TAP, "Asa ang katugma sa bituon?", "Asa ang katugma sa bituon?", "box",
       [p("box", "kahon"), p("fish", "isda"), p("hen", "manok"), p("ball", "bola")], picture="star", word="bituon"),
    it("pa2-b11", PA, 2, "RL1PA-I-4", T1, TAP, "Asa ang katugma sa peras?", "Asa ang katugma sa peras?", "grapes",
       [p("dog", "iro"), p("grapes", "ubas"), p("hat", "kalo"), p("frog", "baki")], picture="pear", word="peras"),
    it("pa2-b12", PA, 2, "RL1PA-I-4", T2, TAP, "Asa ang katugma sa sakayan?", "Asa ang katugma sa sakayan?", "moon",
       [p("banana", "saging"), p("bear", "oso"), p("moon", "bulan"), p("book", "libro")], picture="boat",
       word="sakayan"),
    # ---------- Level 2, phonics: syllables, sound swaps, sounding out (k l t n g p) ----------
    it("ph2-b01", PH, 2, "RL1PWS-II-4", T1, SPIN, "Tuyoka aron mahimo ang iro.",
       "Iro. Tuyoka ang ligid aron mahimo ang pulong iro.", "i", letters("a", "i", "u", "o"), picture="dog",
       rime="ro"),
    it("ph2-b02", PH, 2, "RL1PWS-II-4", T1, SPIN, "Tuyoka aron mahimo ang bola.",
       "Bola. Tuyoka ang ligid aron mahimo ang pulong bola.", "bo", letters("ba", "bi", "bo", "bu"),
       picture="ball", rime="la"),
    it("ph2-b03", PH, 2, "RL1PWS-II-4", T2, SPIN, "Tuyoka aron mahimo ang kalo.",
       "Kalo. Tuyoka ang ligid aron mahimo ang pulong kalo.", "ka", letters("ki", "ka", "ko", "ku"),
       picture="hat", rime="lo"),
    it("ph2-b04", PH, 2, "RL1PWS-II-4", T2, SPIN, "Tuyoka aron mahimo ang baki.",
       "Baki. Tuyoka ang ligid aron mahimo ang pulong baki.", "ba", letters("bi", "bo", "ba", "bu"),
       picture="frog", rime="ki"),
    it("ph2-b05", PH, 2, "RL1PWS-II-5", T1, DRAG, "Himoa ang pulong manok.",
       "Manok. Ibalhin ang kulang nga letra aron mahimo ang manok.", "m", letters("s", "m", "b"),
       picture="hen", pattern=["_", "a", "n", "o", "k"]),
    it("ph2-b06", PH, 2, "RL1PWS-II-5", T1, DRAG, "Himoa ang pulong lapis.",
       "Lapis. Ibalhin ang kulang nga letra aron mahimo ang lapis.", "l", letters("l", "k", "t"),
       picture="pencil", pattern=["_", "a", "p", "i", "s"]),
    it("ph2-b07", PH, 2, "RL1PWS-II-5", T2, DRAG, "Himoa ang pulong kahon.",
       "Kahon. Ibalhin ang kulang nga letra aron mahimo ang kahon.", "o", letters("u", "a", "o"),
       picture="box", pattern=["k", "a", "h", "_", "n"]),
    it("ph2-b08", PH, 2, "RL1PWS-II-5", T2, DRAG, "Himoa ang pulong bitin.",
       "Bitin. Ibalhin ang kulang nga letra aron mahimo ang bitin.", "i", letters("e", "a", "i"),
       picture="snake", pattern=["b", "_", "t", "i", "n"]),
    it("ph2-b09", PH, 2, "RL1PWS-II-5", T1, TAP, "Asa ang pulong isda?", "Pangitaa ang pulong isda.", "isda",
       [ch("iro", "iro"), ch("isda", "isda"), ch("ilaga", "ilaga")], variant="word_catch"),
    it("ph2-b10", PH, 2, "RL1PWS-II-5", T2, TAP, "Asa ang pulong baki?", "Pangitaa ang pulong baki.", "baki",
       [ch("bata", "bata"), ch("bako", "bako"), ch("baki", "baki")], variant="word_catch"),
    it("ph2-b11", PH, 2, "RL1PWS-II-5", T2, TAP, "Asa ang pulong kalo?", "Pangitaa ang pulong kalo.", "kalo",
       [ch("kalo", "kalo"), ch("lako", "lako"), ch("kato", "kato")]),
    it("ph2-b12", PH, 2, "RL1PWS-II-4", T1, SPIN, "Tuyoka aron mahimo ang manok.",
       "Manok. Tuyoka ang ligid aron mahimo ang pulong manok.", "ma", letters("mi", "mu", "ma", "mo"),
       picture="hen", rime="nok"),
    # ---------- Level 2, vocabulary: school words, naming and describing, sight words ----------
    it("vo2-b01", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang libro.", "Pindota ang libro.", "book",
       [p("book", "libro"), p("pencil", "lapis"), p("ball", "bola")]),
    it("vo2-b02", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang lapis.", "Pindota ang lapis.", "pencil",
       [p("book", "libro"), p("scissors", "gunting"), p("pencil", "lapis")]),
    it("vo2-b03", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang sticker.", "Pindota ang sticker.", "sticker",
       [p("pencil", "lapis"), p("sticker", "sticker"), p("book", "libro")]),
    it("vo2-b04", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang bus.", "Pindota ang bus nga mosakay ta paingon sa eskwelahan.",
       "bus", [p("car", "awto"), p("bus", "bus"), p("boat", "sakayan")]),
    it("vo2-b05", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang bituon.", "Gihatagan ka ni Titser og bituon. Pindota ang bituon.",
       "star", [p("moon", "bulan"), p("sun", "adlaw"), p("star", "bituon")]),
    it("vo2-b06", VO, 2, "RL1VWK-II-2a", T2, TAP, "Basaha ang pulong. Pindota ang hulagway.",
       "Basaha ang pulong. Pindota ang hulagway.", "cat",
       [ch("cat", picture="cat"), ch("dog", picture="dog"), ch("bear", picture="bear")], word="iring"),
    it("vo2-b07", VO, 2, "RL1VWK-II-2a", T2, TAP, "Basaha ang pulong. Pindota ang hulagway.",
       "Basaha ang pulong. Pindota ang hulagway.", "banana",
       [ch("apple", picture="apple"), ch("banana", picture="banana"), ch("grapes", picture="grapes")], word="saging"),
    it("vo2-b08", VO, 2, "RL1VWK-II-2b", T2, TAP, "Asa ang dako?", "Asa ang dako?", "elephant",
       [p("ant", "hulmigas"), p("elephant", "elepante"), p("mouse", "ilaga")],
       hint="Tan-awa pag-ayo. Asa ang labing dako?", explain="Ang elepante ang dako."),
    it("vo2-b09", VO, 2, "RL1VWK-II-2b", T2, TAP, "Asa ang gamay?", "Asa ang gamay?", "ant",
       [p("bear", "oso"), p("elephant", "elepante"), p("ant", "hulmigas")],
       hint="Tan-awa pag-ayo. Asa ang labing gamay?", explain="Ang hulmigas ang gamay."),
    it("vo2-b10", VO, 2, "RL1VWK-II-3", T2, TAP, "Pindota ang pulong ang.", "Pindota ang pulong ang.", "ang",
       [ch("ug", "ug"), ch("ang", "ang"), ch("sa", "sa"), ch("si", "si")], variant="word_catch"),
    it("vo2-b11", VO, 2, "RL1VWK-II-3", T1, TAP, "Pindota ang pulong si.", "Pindota ang pulong si.", "si",
       [ch("si", "si"), ch("sa", "sa"), ch("mga", "mga")]),
    it("vo2-b12", VO, 2, "RL1VWK-II-3", T2, TAP, "Pindota ang pulong mga.", "Pindota ang pulong mga.", "mga",
       [ch("ang", "ang"), ch("ug", "ug"), ch("mga", "mga")]),
    it("vo2-br1", VO, 2, "RL1VWK-II-1", 0, TAP, "Pindota ang libro.", "Pindota ang libro.", "book",
       [p("book", "libro"), p("dog", "iro")], rescue=True),
    it("vo2-br2", VO, 2, "RL1VWK-II-3", 0, TAP, "Pindota ang pulong ang.", "Pindota ang pulong ang.", "ang",
       [ch("ang", "ang"), ch("ug", "ug")], rescue=True),
    it("vo2-br3", VO, 2, "RL1VWK-II-2a", 0, TAP, "Basaha ang pulong. Pindota ang hulagway.",
       "Basaha ang pulong. Pindota ang hulagway.", "cat", [ch("cat", picture="cat"), ch("car", picture="car")],
       rescue=True, word="iring"),
]


def t(id, skill, level, code, task, prompt, tts, answer, choices=None, **extra):
    return it(id, skill, level, code, 0, task, prompt, tts, answer, choices, lang=FIL, **extra)


tests = {
    "pre": [
        t("pre-pa1", PA, 1, "RL1PA-I-3", TAP, "Alin ang katugma ng puso?", "Alin ang katugma ng puso?", "dog",
          [p("dog", "aso"), p("fish", "isda"), p("bird", "ibon")], picture="heart", word="puso"),
        t("pre-pa2", PA, 1, "RL1PA-I-5", TAP, "Alin ang nagsisimula sa /b/?",
          "Alin ang nagsisimula sa tunog b, gaya ng baso?", "ball",
          [p("fish", "isda"), p("ball", "bola"), p("dog", "aso")]),
        t("pre-pa3", PA, 2, "RL1PA-I-2", TAP, "Ilang pantig ang palaka?",
          "Pumalakpak kasama ko. Pa. La. Ka. Ilang palakpak?", "3", claps(3, 1, 2, 3), picture="frog", word="palaka"),
        t("pre-ph1", PH, 1, "RL1PWS-II-1", TAP, "Aling titik ang may tunog na /t/?",
          "Aling titik ang may tunog na t, gaya ng tatay?", "t", letters("p", "d", "t")),
        t("pre-ph2", PH, 2, "RL1PWS-II-5", DRAG, "Buuin ang salitang bahay.",
          "Bahay. Ilipat ang kulang na titik para mabuo ang bahay.", "a", letters("o", "a", "u"),
          picture="house", pattern=["b", "_", "h", "a", "y"]),
        t("pre-vo1", VO, 2, "RL1VWK-II-1", TAP, "Pindutin ang bag.", "Pindutin ang bag.", "bag",
          [ch("book", picture="book"), ch("ball", picture="ball"), ch("bag", picture="bag")]),
        t("pre-fl3", FL, 5, "RL1BPK-II-3", ORDER, "Ayusin ang mga salita.",
          "Natutulog ang aso sa ilalim ng mesa. Ayusin ang mga salita.", "Natutulog|ang|aso|sa|ilalim|ng|mesa.",
          picture="dog", variant="sentence", tiles=["Natutulog", "ang", "aso", "sa", "ilalim", "ng", "mesa."]),
        t("pre-lc5", LC, 5, "RL1CAT-II-1a", TAP, "Kailan nangingisda si Lolo Ben?", "Kailan nangingisda si Lolo Ben?",
          "sunday", [ch("monday", "tuwing Lunes"), ch("sunday", "tuwing Linggo"), ch("night", "tuwing gabi")],
          passage="pre-fishing"),
        t("pre-lc6", LC, 5, "RL1CAT-II-1a", TAP, "Ilang isda ang nahuli nila?", "Ilang isda ang nahuli nila?", "five",
          [ch("two", "dalawa"), ch("ten", "sampu"), ch("five", "lima")], passage="pre-fishing"),
        t("pre-lc7", LC, 5, "RL1CAT-II-1f", TAP, "Bakit kailangan ni Lolo ang tulong ni Paolo?",
          "Bakit kailangan ni Lolo ang tulong ni Paolo?", "heavy",
          [ch("heavy", "Mabigat ang lambat dahil sa isda."), ch("sink", "Lumulubog ang bangka."),
           ch("sleepy", "Inaantok si Lolo.")], passage="pre-fishing"),
        t("pre-lc8", LC, 5, "RL1CAT-II-1c", TAP, "Ano ang naramdaman ni Aling Rosa?",
          "Ano ang naramdaman ni Aling Rosa?", "happy",
          [ch("angry", "galit"), ch("happy", "masaya at nagpapasalamat"), ch("sad", "malungkot")],
          passage="pre-fishing"),
    ],
    "post": [
        t("post-pa1", PA, 1, "RL1PA-I-3", TAP, "Alin ang katugma ng ibon?", "Alin ang katugma ng ibon?", "box",
          [p("hen", "manok"), p("box", "kahon"), p("ball", "bola")], picture="bird", word="ibon"),
        t("post-pa2", PA, 1, "RL1PA-I-5", TAP, "Alin ang nagsisimula sa /k/?",
          "Alin ang nagsisimula sa tunog k, gaya ng kama?", "rabbit",
          [p("rabbit", "kuneho"), p("fish", "isda"), p("dog", "aso")]),
        t("post-pa3", PA, 2, "RL1PA-I-2", TAP, "Ilang pantig ang bubuyog?",
          "Pumalakpak kasama ko. Bu. Bu. Yog. Ilang palakpak?", "3", claps(3, 1, 2, 3), picture="bee",
          word="bubuyog"),
        t("post-ph1", PH, 1, "RL1PWS-II-1", TAP, "Aling titik ang may tunog na /l/?",
          "Aling titik ang may tunog na l, gaya ng lola?", "l", letters("n", "l", "t")),
        t("post-ph2", PH, 2, "RL1PWS-II-5", DRAG, "Buuin ang salitang pusa.",
          "Pusa. Ilipat ang kulang na titik para mabuo ang pusa.", "u", letters("a", "o", "u"),
          picture="cat", pattern=["p", "_", "s", "a"]),
        t("post-vo1", VO, 2, "RL1VWK-II-1", TAP, "Pindutin ang gunting.", "Pindutin ang gunting.", "scissors",
          [ch("pencil", picture="pencil"), ch("scissors", picture="scissors"), ch("bag", picture="bag")]),
        t("post-fl3", FL, 5, "RL1BPK-II-3", ORDER, "Ayusin ang mga salita.",
          "Umiinom ang pusa ng mainit na gatas. Ayusin ang mga salita.", "Umiinom|ang|pusa|ng|mainit|na|gatas.",
          picture="cat", variant="sentence", tiles=["Umiinom", "ang", "pusa", "ng", "mainit", "na", "gatas."]),
        t("post-lc5", LC, 5, "RL1CAT-II-1a", TAP, "Saan ang hardin?", "Saan ang hardin?", "school",
          [ch("school", "sa likod ng paaralan"), ch("river", "malapit sa ilog"), ch("house", "sa loob ng bahay")],
          passage="post-garden"),
        t("post-lc6", LC, 5, "RL1CAT-II-1a", TAP, "Kailan dinidiligan ni Kim ang halaman niya?",
          "Kailan dinidiligan ni Kim ang halaman niya?", "morning",
          [ch("night", "tuwing gabi"), ch("morning", "tuwing umaga"), ch("month", "isang beses sa isang buwan")],
          passage="post-garden"),
        t("post-lc7", LC, 5, "RL1CAT-II-1f", TAP, "Bakit napatalon si Kim?", "Bakit napatalon si Kim?", "leaf",
          [ch("leaf", "Nakita niya ang maliit na dahon."), ch("snake", "May nakita siyang ahas."),
           ch("late", "Nahuli siya sa klase.")], passage="post-garden"),
        t("post-lc8", LC, 5, "RL1CAT-II-1d", TAP, "Ano ang malamang gagawin ng klase sa susunod na buwan?",
          "Ano ang malamang gagawin ng klase sa susunod na buwan?", "plant",
          [ch("stop", "Titigil sa paghahalaman."), ch("plant", "Magtatanim muli."),
           ch("close", "Isasara ang paaralan.")], passage="post-garden"),
    ],
}
passages = {
    "pre-fishing": {"level": 5, "language": FIL, "scene": "river", "title": "Ang Pangingisda ni Lolo",
                    "text": "Tuwing Linggo, nangingisda si Lolo Ben sa Ilog Agusan. Maaga siyang gumigising at "
                            "nagdadala ng kanin, isang bote ng tubig, at lambat. Sumasama sa kanya ang apo niyang si "
                            "Paolo. Umuupo si Paolo sa unahan ng maliit na bangka. Tahimik at payapa ang ilog. "
                            "Pagkalipas ng isang oras, naramdaman ni Lolo ang malakas na hila sa lambat. Tinulungan "
                            "siya ni Paolo na hilahin ito. Nakahuli sila ng limang malalaking isda! Pauwi, binigyan "
                            "nila ng dalawang isda ang kapitbahay nilang si Aling Rosa. Nagpasalamat siya nang may "
                            "malaking ngiti."},
    "post-garden": {"level": 5, "language": FIL, "scene": "grove", "title": "Ang Hardin ng Paaralan",
                    "text": "Nagtanim ng hardin ang klase ni Titser Liza sa likod ng paaralan. Bawat bata ay may "
                            "isang maliit na paso. Nagtanim si Kim ng buto ng okra. Dinidiligan niya ito tuwing umaga "
                            "bago magklase. Pagkalipas ng isang linggo, may lumabas na maliit na berdeng dahon. "
                            "Napatalon si Kim at tinawag ang mga kaibigan niya para makita ito. Lalong tumaas ang "
                            "mga halaman. Sa katapusan ng buwan, pinitas ng klase ang okra at niluto nila ito kasama "
                            "si Titser Liza. Gusto ng lahat na magtanim muli sa susunod na buwan."},
}
json.dump({"note": "DRAFT (D-045) for teacher review. Not in the game yet. Bisaya Levels 1-2 replace the English "
                   "Level 1-2 items; the test items replace the English ones with the same ids.",
           "bisaya_levels_1_2": bis, "tests_filipino": tests, "test_passages": passages},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
print(len(bis), "Bisaya items,", len(tests["pre"]), "+", len(tests["post"]), "test items")
