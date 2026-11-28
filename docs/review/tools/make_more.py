"""112 more items so every skill at every level has 20 (10 easier, 10 harder), plus 6 stories.

Levels 1-2 Bisaya, 3-4 Filipino, 5 English (D-045). Usage: python -I make_more.py <out.json>
"""
import json
import sys

BIS, FIL, EN = "bis-placeholder", "fil-placeholder", "en-placeholder"
LANG = {1: BIS, 2: BIS, 3: FIL, 4: FIL, 5: EN}
PA, PH, VO, FL, LC = ("phonological_awareness", "phonics", "vocabulary", "fluency", "literal_comprehension")
TAP, DRAG, ORDER, SPIN = "tap_choice", "drag_letter", "order_tiles", "spin_words"
T1, T2 = 1, 2


def ch(cid, label=None, picture=None, repeat=None):
    c = {"id": cid}
    if label is not None:
        c["label"] = label
    if picture:
        c["picture"] = picture
    if repeat:
        c["repeat"] = repeat
    return c


def it(id, skill, level, code, tier, task, prompt, tts, answer, choices=None, **extra):
    d = {"id": id, "sub_skill": skill, "level": level, "competency": code, "language": LANG[level],
         "task_type": task, "prompt": prompt, "tts_text": tts}
    d.update(extra)
    if choices is not None:
        d["choices"] = choices
    d.update({"answer": answer, "recovery": False, "tier": tier, "new": True})
    return d


def p(pic, word):
    return ch(pic, word, pic)


def L(*xs):
    return [ch(x, x) for x in xs]


def W(*xs):
    return [ch(x, x) for x in xs]


def claps(*opts):
    return [ch(str(k), str(k), "hand", k) for k in opts]


def clap_bis(id, tier, word, pic, parts):
    n = len(parts)
    opts = (1, 2, 3) if n <= 3 else (2, 3, 4)
    said = ". ".join(x.capitalize() for x in parts)
    return it(id, PA, 2, "RL1PA-I-2", tier, TAP, f"Pila ka pantig ang {word}?",
              f"Pakpak uban nako. {said}. Pila ka pakpak?", str(n), claps(*opts), picture=pic, word=word,
              hint=f"Pakpak uban nako: {', '.join(parts)}. Ihapa ang matag pakpak.",
              explain=f"{'-'.join(parts).capitalize()} adunay {n} ka pakpak.")


def build(id, skill, level, code, tier, word, pic, parts, say, ask):
    said = ". ".join(x.capitalize() for x in parts)
    return it(id, skill, level, code, tier, ORDER, ask.format(word=word), say.format(said=said, word=word),
              "|".join(parts), picture=pic, variant="syllables", tiles=list(parts))


def sentence(id, level, tier, words, pic=None, ask="Ayusin ang mga salita."):
    extra = {"picture": pic} if pic else {}
    return it(id, FL, level, "RL1BPK-II-3", tier, ORDER, ask, " ".join(words) + " " + ask, "|".join(words),
              variant="sentence", tiles=list(words), **extra)


def fill(id, level, tier, text, say, answer, opts, pic=None, ask="Ano ang kulang?"):
    extra = {"picture": pic} if pic else {}
    return it(id, FL, level, "RL1PWS-II-5", tier, TAP, ask, say, answer, W(*opts), sentence=text, **extra)


def q(id, level, code, tier, passage, prompt, answer, opts, hint=None, explain=None):
    extra = {"passage": passage}
    if hint:
        extra.update({"hint": hint, "explain": explain})
    return it(id, LC, level, code, tier, TAP, prompt, prompt, answer, [ch(k, v) for k, v in opts], **extra)


def seq(id, level, tier, passage, ask, say, events):
    tiles = [{"id": k, "text": t, **({"picture": pic} if pic else {})} for k, t, pic in events]
    return it(id, LC, level, "RL1CAT-II-1b", tier, ORDER, ask, say, "|".join(k for k, _, _ in events),
              passage=passage, variant="sequence", tiles=tiles)


BS = "{said}. Pindota ang mga pantig aron mahimo ang {word}."
BA = "Buhata ang pulong {word}."
FS = "{said}. Pindutin ang mga pantig para mabuo ang {word}."
FA = "Buuin ang salitang {word}."

items = [
    # ===== Level 1 (Bisaya): phonological awareness +8 =====
    it("pa1-b13", PA, 1, "RL1PA-I-3", T1, TAP, "Asa ang katugma sa baboy?", "Asa ang katugma sa baboy?", "tree",
       [p("tree", "kahoy"), p("cat", "iring"), p("moon", "bulan")], picture="pig", word="baboy"),
    it("pa1-b14", PA, 1, "RL1PA-I-3", T1, TAP, "Asa ang katugma sa tasa?", "Asa ang katugma sa tasa?", "table",
       [p("dog", "iro"), p("table", "lamesa"), p("hat", "kalo")], picture="cup", word="tasa", variant="rhyme_pop"),
    it("pa1-b15", PA, 1, "RL1PA-I-3", T2, TAP, "Asa ang katugma sa mangga?", "Asa ang katugma sa mangga?", "mouse",
       [p("banana", "saging"), p("ball", "bola"), p("mouse", "ilaga"), p("sun", "adlaw")], picture="mango",
       word="mangga"),
    it("pa1-b16", PA, 1, "RL1PA-I-3", T2, TAP, "Asa ang katugma sa balay?", "Asa ang katugma sa balay?", "bread",
       [p("book", "libro"), p("goat", "kanding"), p("fish", "isda"), p("bread", "tinapay")], picture="house",
       word="balay"),
    it("pa1-b17", PA, 1, "RL1PA-I-5", T1, TAP, "Asa ang nagsugod sa /s/?",
       "Asa ang nagsugod sa tingog sss, sama sa sabon?", "shoes",
       [p("shoes", "sapatos"), p("table", "lamesa"), p("dog", "iro")]),
    it("pa1-b18", PA, 1, "RL1PA-I-5", T1, TAP, "Asa ang nagsugod sa /m/?",
       "Asa ang nagsugod sa tingog mmm, sama sa mata?", "corn",
       [p("tree", "kahoy"), p("corn", "mais"), p("dog", "iro")]),
    it("pa1-b19", PA, 1, "RL1PA-I-5", T2, TAP, "Asa ang nagsugod sa /u/?",
       "Asa ang nagsugod sa tingog u, sama sa ulo?", "monkey",
       [p("bear", "oso"), p("sun", "adlaw"), p("monkey", "unggoy")]),
    it("pa1-b20", PA, 1, "RL1PA-I-5", T2, TAP, "Asa ang nagsugod sa /b/?",
       "Asa ang nagsugod sa tingog b, sama sa bata?", "pig",
       [p("pear", "peras"), p("corn", "mais"), p("pig", "baboy")]),
    # ===== Level 1 (Bisaya): phonics +8 =====
    it("ph1-b13", PH, 1, "RL1PWS-II-1", T1, TAP, "Unsang letra ang naay tingog /b/?", "Unsang letra ang naay tingog b?",
       "b", L("m", "b", "s")),
    it("ph1-b14", PH, 1, "RL1PWS-II-2", T1, TAP, "Pindota ang letra s.", "Pindota ang letra s.", "s", L("s", "m", "o")),
    it("ph1-b15", PH, 1, "RL1PWS-II-3", T1, TAP, "Ang mais nagsugod sa unsang letra?",
       "Mais. Ang mais nagsugod sa unsang letra?", "m", L("s", "b", "m"), picture="corn"),
    it("ph1-b16", PH, 1, "RL1PWS-II-3", T1, TAP, "Ang baboy nagsugod sa unsang letra?",
       "Baboy. Ang baboy nagsugod sa unsang letra?", "b", L("b", "a", "s"), picture="pig"),
    it("ph1-b17", PH, 1, "RL1PWS-II-2", T2, TAP, "Pindota ang letra u.", "Pindota ang letra u.", "u", L("o", "a", "u")),
    it("ph1-b18", PH, 1, "RL1PWS-II-3", T2, TAP, "Ang unggoy nagsugod sa unsang letra?",
       "Unggoy. Ang unggoy nagsugod sa unsang letra?", "u", L("o", "u", "i"), picture="monkey"),
    it("ph1-b19", PH, 1, "RL1PWS-II-3", T2, DRAG, "Himoa ang pulong mais.",
       "Mais. Ibalhin ang kulang nga letra aron mahimo ang mais.", "a", L("o", "u", "a"), picture="corn",
       pattern=["m", "_", "i", "s"]),
    it("ph1-b20", PH, 1, "RL1PWS-II-3", T2, DRAG, "Himoa ang pulong baso.",
       "Baso. Ibalhin ang kulang nga letra aron mahimo ang baso.", "o", L("u", "o", "a"), picture="glass",
       pattern=["b", "a", "s", "_"]),
    # ===== Level 2 (Bisaya): phonological awareness +8 =====
    clap_bis("pa2-b13", T1, "lubi", "coconut", ["lu", "bi"]),
    clap_bis("pa2-b14", T1, "mais", "corn", ["ma", "is"]),
    build("pa2-b15", PA, 2, "RL1PA-I-2", T1, "baboy", "pig", ["ba", "boy"], BS, BA),
    it("pa2-b16", PA, 2, "RL1PA-I-4", T1, TAP, "Asa ang katugma sa dahon?", "Asa ang katugma sa dahon?", "box",
       [p("dog", "iro"), p("box", "kahon"), p("corn", "mais"), p("ball", "bola")], picture="leaf", word="dahon"),
    clap_bis("pa2-b17", T2, "lamesa", "table", ["la", "me", "sa"]),
    clap_bis("pa2-b18", T2, "tinapay", "bread", ["ti", "na", "pay"]),
    build("pa2-b19", PA, 2, "RL1PA-I-2", T2, "sapatos", "shoes", ["sa", "pa", "tos"], BS, BA),
    it("pa2-b20", PA, 2, "RL1PA-I-4", T2, TAP, "Asa ang katugma sa baso?", "Asa ang katugma sa baso?", "bear",
       [p("book", "libro"), p("hat", "kalo"), p("bear", "oso"), p("dog", "iro")], picture="glass", word="baso"),
    # ===== Level 2 (Bisaya): phonics +8 =====
    it("ph2-b13", PH, 2, "RL1PWS-II-4", T1, SPIN, "Tuyoka aron mahimo ang lubi.",
       "Lubi. Tuyoka ang ligid aron mahimo ang pulong lubi.", "lu", L("la", "li", "lu", "lo"), picture="coconut",
       rime="bi"),
    it("ph2-b14", PH, 2, "RL1PWS-II-5", T1, DRAG, "Himoa ang pulong tasa.",
       "Tasa. Ibalhin ang kulang nga letra aron mahimo ang tasa.", "t", L("k", "t", "p"), picture="cup",
       pattern=["_", "a", "s", "a"]),
    it("ph2-b15", PH, 2, "RL1PWS-II-5", T1, TAP, "Asa ang pulong mais?", "Pangitaa ang pulong mais.", "mais",
       W("mata", "mais", "lubi"), variant="word_catch"),
    it("ph2-b16", PH, 2, "RL1PWS-II-4", T1, SPIN, "Tuyoka aron mahimo ang kahoy.",
       "Kahoy. Tuyoka ang ligid aron mahimo ang pulong kahoy.", "ka", L("ki", "ku", "ka", "ko"), picture="tree",
       rime="hoy"),
    it("ph2-b17", PH, 2, "RL1PWS-II-5", T2, DRAG, "Himoa ang pulong lubi.",
       "Lubi. Ibalhin ang kulang nga letra aron mahimo ang lubi.", "u", L("o", "a", "u"), picture="coconut",
       pattern=["l", "_", "b", "i"]),
    it("ph2-b18", PH, 2, "RL1PWS-II-5", T2, DRAG, "Himoa ang pulong tubig.",
       "Tubig. Ibalhin ang kulang nga letra aron mahimo ang tubig.", "i", L("e", "a", "i"), picture="water",
       pattern=["t", "u", "b", "_", "g"]),
    it("ph2-b19", PH, 2, "RL1PWS-II-5", T2, TAP, "Asa ang pulong tasa?", "Pangitaa ang pulong tasa.", "tasa",
       W("sata", "tasa", "taas"), variant="word_catch"),
    it("ph2-b20", PH, 2, "RL1PWS-II-5", T2, TAP, "Asa ang pulong kabaw?", "Pangitaa ang pulong kabaw.", "kabaw",
       W("kawab", "baka", "kabaw")),
    # ===== Level 2 (Bisaya): vocabulary +8 =====
    it("vo2-b13", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang lamesa.", "Pindota ang lamesa.", "table",
       [p("table", "lamesa"), p("chair", "lingkoranan"), p("blackboard", "pisara")]),
    it("vo2-b14", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang lingkoranan.", "Pindota ang lingkoranan.", "chair",
       [p("book", "libro"), p("ball", "bola"), p("chair", "lingkoranan")]),
    it("vo2-b15", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang pisara.", "Pindota ang pisara.", "blackboard",
       [p("blackboard", "pisara"), p("book", "libro"), p("ball", "bola")]),
    it("vo2-b16", VO, 2, "RL1VWK-II-1", T1, TAP, "Pindota ang titser.", "Pindota ang titser.", "teacher",
       [p("doctor", "doktor"), p("teacher", "titser"), p("farmer", "mag-uuma")]),
    it("vo2-b17", VO, 2, "RL1VWK-II-2a", T2, TAP, "Basaha ang pulong. Pindota ang hulagway.",
       "Basaha ang pulong. Pindota ang hulagway.", "table",
       [ch("chair", picture="chair"), ch("table", picture="table"), ch("bag", picture="bag")], word="lamesa"),
    it("vo2-b18", VO, 2, "RL1VWK-II-2b", T2, TAP, "Asa ang taas?", "Asa ang taas?", "tree",
       [p("flower", "bulak"), p("grass", "sagbot"), p("tree", "kahoy")],
       hint="Tan-awa pag-ayo. Asa ang labing taas?", explain="Ang kahoy ang taas."),
    it("vo2-b19", VO, 2, "RL1VWK-II-3", T2, TAP, "Pindota ang pulong ug.", "Pindota ang pulong ug.", "ug",
       W("ang", "ug", "sa", "ni"), variant="word_catch"),
    it("vo2-b20", VO, 2, "RL1VWK-II-3", T2, TAP, "Pindota ang pulong kini.", "Pindota ang pulong kini.", "kini",
       W("kana", "ani", "kini")),
    # ===== Level 3 (Filipino): phonics +8 =====
    build("ph3-13", PH, 3, "RL1PWS-II-5", T1, "mais", "corn", ["ma", "is"], FS, FA),
    build("ph3-14", PH, 3, "RL1PWS-II-5", T1, "baso", "glass", ["ba", "so"], FS, FA),
    it("ph3-15", PH, 3, "RL1PWS-II-4", T1, SPIN, "Paikutin para mabuo ang baka.",
       "Baka. Paikutin ang gulong para mabuo ang baka.", "ba", L("bi", "ba", "bo", "bu"), picture="cow", rime="ka"),
    build("ph3-16", PH, 3, "RL1PWS-II-5", T1, "pakwan", "watermelon", ["pak", "wan"], FS, FA),
    build("ph3-17", PH, 3, "RL1PWS-II-5", T2, "kalabaw", "carabao", ["ka", "la", "baw"], FS, FA),
    build("ph3-18", PH, 3, "RL1PWS-II-5", T2, "kamatis", "tomato", ["ka", "ma", "tis"], FS, FA),
    build("ph3-19", PH, 3, "RL1PWS-II-5", T2, "eroplano", "airplane", ["e", "ro", "pla", "no"], FS, FA),
    it("ph3-20", PH, 3, "RL1PWS-II-4", T2, SPIN, "Paikutin para mabuo ang lobo.",
       "Lobo. Paikutin ang gulong para mabuo ang lobo.", "lo", L("la", "li", "lo", "lu"), picture="balloon",
       rime="bo"),
    # ===== Level 3 (Filipino): vocabulary +8 =====
    it("vo3-13", VO, 3, "RL1VWK-II-1", T1, TAP, "Pindutin ang pisara.", "Pindutin ang pisara.", "blackboard",
       [p("chair", "upuan"), p("blackboard", "pisara"), p("ball", "bola")]),
    it("vo3-14", VO, 3, "RL1VWK-II-1", T1, TAP, "Pindutin ang upuan.", "Pindutin ang upuan.", "chair",
       [p("chair", "upuan"), p("book", "aklat"), p("pencil", "lapis")]),
    it("vo3-15", VO, 3, "RL1VWK-II-1", T1, TAP, "Pindutin ang guro.", "Pindutin ang guro.", "teacher",
       [p("farmer", "magsasaka"), p("doctor", "doktor"), p("teacher", "guro")]),
    it("vo3-16", VO, 3, "RL1VWK-II-2b", T1, TAP, "Alin ang mainit?", "Alin ang mainit?", "sun",
       [p("ice", "yelo"), p("sun", "araw"), p("cloud", "ulap")]),
    it("vo3-17", VO, 3, "RL1VWK-II-2a", T2, TAP, "Basahin ang salita. Pindutin ang larawan.",
       "Basahin ang salita. Pindutin ang larawan.", "notebook",
       [ch("book", picture="book"), ch("notebook", picture="notebook"), ch("pencil", picture="pencil")],
       word="kuwaderno"),
    it("vo3-18", VO, 3, "RL1VWK-II-2a", T2, TAP, "Basahin ang salita. Pindutin ang larawan.",
       "Basahin ang salita. Pindutin ang larawan.", "blackboard",
       [ch("chair", picture="chair"), ch("table", picture="table"), ch("blackboard", picture="blackboard")],
       word="pisara"),
    it("vo3-19", VO, 3, "RL1VWK-II-2b", T2, TAP, "Alin ang malamig?", "Alin ang malamig?", "ice",
       [p("fire", "apoy"), p("ice", "yelo"), p("sun", "araw")]),
    it("vo3-20", VO, 3, "RL1VWK-II-3", T2, TAP, "Pindutin ang salitang ay.", "Pindutin ang salitang ay.", "ay",
       W("at", "ang", "ay", "sa"), variant="word_catch"),
    # ===== Level 3 (Filipino): fluency +8 =====
    sentence("fl3-13", 3, T1, ["Ito", "ay", "upuan."], "chair"),
    sentence("fl3-14", 3, T1, ["Malaki", "ang", "kalabaw."], "carabao"),
    fill("fl3-15", 3, T1, "Ang ___ ay matamis.", "Ang ano ay matamis? Piliin ang tamang salita.", "mangga",
         ["mangga", "bato", "ulap"], pic="mango"),
    fill("fl3-16", 3, T1, "Lumilipad ang ___.", "Lumilipad ang ano? Piliin ang tamang salita.", "paruparo",
         ["kalabaw", "paruparo", "upuan"], pic="butterfly"),
    sentence("fl3-17", 3, T2, ["Masaya", "ang", "mga", "bata."]),
    sentence("fl3-18", 3, T2, ["Malinis", "ang", "aming", "silid."]),
    fill("fl3-19", 3, T2, "Nagbabasa ako ng ___.", "Nagbabasa ako ng ano? Piliin ang tamang salita.", "aklat",
         ["bato", "aklat", "ulan"]),
    fill("fl3-20", 3, T2, "Ang guro ay nasa ___.", "Ang guro ay nasa saan? Piliin ang tamang salita.", "paaralan",
         ["ilog", "puno", "paaralan"]),
    # ===== Level 3 (Filipino): literal comprehension +8, two new stories =====
    q("lc3-13", 3, "RL1CAT-II-1a", T1, "p3-paaralan", "Sino ang guro?", "ana",
      [("lea", "Si Lea"), ("ana", "Si Titser Ana"), ("rey", "Si Rey")]),
    q("lc3-14", 3, "RL1CAT-II-1a", T1, "p3-paaralan", "Ano ang dala ni Lea?", "lapis",
      [("lapis", "bagong lapis at kuwaderno"), ("lobo", "lobo at bola"), ("payong", "payong at bag")]),
    q("lc3-15", 3, "RL1CAT-II-1a", T2, "p3-paaralan", "Ano ang ibinigay ni Lea kay Rey?", "krayola",
      [("lapis", "lapis"), ("kuwaderno", "kuwaderno"), ("krayola", "krayola")]),
    seq("lc3-16", 3, T2, "p3-paaralan", "Ayusin ang kuwento.", "Ano ang unang nangyari? Ayusin ang kuwento.",
        [("a", "Bumati si Titser Ana.", "teacher"), ("b", "Umupo si Lea sa tabi ni Rey.", "chair"),
         ("c", "Masaya si Lea pag-uwi.", "star")]),
    q("lc3-17", 3, "RL1CAT-II-1a", T1, "p3-kalabaw", "Ano ang pangalan ng kalabaw?", "kalog",
      [("kalog", "Kalog"), ("nilo", "Nilo"), ("bantay", "Bantay")]),
    q("lc3-18", 3, "RL1CAT-II-1a", T1, "p3-kalabaw", "Saan tumutulong si Kalog?", "bukid",
      [("paaralan", "sa paaralan"), ("bukid", "sa bukid"), ("ilog", "sa ilog")]),
    q("lc3-19", 3, "RL1CAT-II-1a", T2, "p3-kalabaw", "Kailan naliligo si Kalog?", "tanghali",
      [("umaga", "sa umaga"), ("gabi", "sa gabi"), ("tanghali", "sa tanghali")]),
    q("lc3-20", 3, "RL1CAT-II-1c", T2, "p3-kalabaw", "Ano ang nararamdaman ni Nilo kay Kalog?", "mahal",
      [("takot", "Takot siya kay Kalog."), ("mahal", "Mahal niya si Kalog."), ("galit", "Galit siya kay Kalog.")]),
    # ===== Level 4 (Filipino): vocabulary +8 =====
    it("vo4-13", VO, 4, "RL1VWK-II-4", T1, TAP, "Alin ang may limang bituin?", "Alin ang may limang bituin?", "5",
       [ch("3", picture="star", repeat=3), ch("5", picture="star", repeat=5), ch("4", picture="star", repeat=4)],
       hint="Bilangin ang bituin sa bawat larawan.", explain="Isa, dalawa, tatlo, apat, lima. Limang bituin!"),
    it("vo4-14", VO, 4, "RL1VWK-II-4", T1, TAP, "Bago kumain, ano ang dapat mong gawin?",
       "Bago kumain, ano ang dapat mong gawin?", "hugas",
       [ch("hugas", "Maghugas ng kamay."), ch("tulog", "Matulog."), ch("laro", "Maglaro sa labas.")],
       hint="Ano ang ginagawa natin para malinis ang kamay?", explain="Bago kumain, maghugas ng kamay."),
    it("vo4-15", VO, 4, "RL1VWK-II-4", T1, TAP, "Alin ang hayop?", "Alin ang hayop?", "carabao",
       [p("chair", "upuan"), p("carabao", "kalabaw"), p("ball", "bola")],
       hint="Ang hayop ay buhay at gumagalaw.", explain="Ang kalabaw ay hayop."),
    it("vo4-16", VO, 4, "RL1VWK-II-4", T1, TAP, "May basura sa sahig ng silid. Ano ang gagawin mo?",
       "May basura sa sahig ng silid. Ano ang gagawin mo?", "pulot",
       [ch("iwan", "Iwanan ito."), ch("pulot", "Pulutin at itapon sa basurahan."), ch("sipa", "Sipain ito.")],
       hint="Ano ang ginagawa ng batang malinis?", explain="Pinupulot natin ang basura at itinatapon sa basurahan."),
    it("vo4-17", VO, 4, "RL1VWK-II-4", T2, TAP, "Alin ang pinakamarami?", "Alin ang may pinakamaraming mansanas?", "5",
       [ch("2", picture="apple", repeat=2), ch("3", picture="apple", repeat=3), ch("5", picture="apple", repeat=5)],
       hint="Bilangin ang mansanas sa bawat larawan.", explain="Lima ang pinakamarami."),
    it("vo4-18", VO, 4, "RL1VWK-II-2b", T2, TAP, "Ano ang ibig sabihin ng malinis?",
       "Ano ang ibig sabihin ng malinis?", "walang",
       [ch("dumi", "maraming dumi"), ch("walang", "walang dumi"), ch("basa", "basang-basa")],
       hint="Ang malinis na kamay ay walang dumi.", explain="Ang malinis ay walang dumi."),
    it("vo4-19", VO, 4, "RL1VWK-II-2b", T2, TAP, "Alin ang salitang naglalarawan?",
       "Alin ang salitang naglalarawan?", "matangkad",
       [ch("guro", "guro"), ch("naglakad", "naglakad"), ch("matangkad", "matangkad")],
       hint="Ang salitang naglalarawan ay nagsasabi kung ano ang tao o bagay.",
       explain="Ang matangkad ay naglalarawan."),
    it("vo4-20", VO, 4, "RL1VWK-II-4", T2, TAP, "Alin ang hindi hayop?", "Alin ang hindi hayop?", "chair",
       [p("carabao", "kalabaw"), p("cat", "pusa"), p("chair", "upuan")],
       hint="Alin ang hindi buhay at hindi gumagalaw?", explain="Ang upuan ay hindi hayop."),
    # ===== Level 4 (Filipino): fluency +8 =====
    sentence("fl4-13", 4, T1, ["Naglilinis", "kami", "ng", "aming", "silid."]),
    sentence("fl4-14", 4, T1, ["Nagtanim", "si", "Lolo", "ng", "mais."], "corn"),
    fill("fl4-15", 4, T1, "Ang ___ ay tumutulong sa bukid.", "Ang ano ay tumutulong sa bukid? Piliin ang tamang salita.",
         "kalabaw", ["paruparo", "kalabaw", "lobo"], pic="carabao"),
    fill("fl4-16", 4, T1, "Gumamit ako ng ___ dahil umuulan.",
         "Gumamit ako ng ano dahil umuulan? Piliin ang tamang salita.", "payong", ["payong", "kutsara", "lapis"],
         pic="umbrella"),
    sentence("fl4-17", 4, T2, ["Pumila", "ang", "mga", "bata", "sa", "labas."]),
    sentence("fl4-18", 4, T2, ["Binasa", "ni", "Titser", "ang", "isang", "kuwento."]),
    fill("fl4-19", 4, T2, "Maaga akong ___ para pumasok sa paaralan.",
         "Maaga akong ano para pumasok sa paaralan? Piliin ang tamang salita.", "gumising",
         ["natulog", "gumising", "umiyak"]),
    fill("fl4-20", 4, T2, "Itinapon ko ang balat ng saging sa ___.",
         "Itinapon ko ang balat ng saging sa saan? Piliin ang tamang salita.", "basurahan",
         ["kama", "bintana", "basurahan"]),
    # ===== Level 4 (Filipino): literal comprehension +8, a story and an informational text =====
    q("lc4-13", 4, "RL1CAT-II-1a", T1, "p4-lapis", "Ano ang nawawala kay Rosa?", "lapis",
      [("lapis", "ang lapis niya"), ("bag", "ang bag niya"), ("kuwaderno", "ang kuwaderno niya")],
      "Basahin ang unang pangungusap.", "Hindi makita ni Rosa ang kanyang lapis."),
    q("lc4-14", 4, "RL1CAT-II-1a", T1, "p4-lapis", "Sino ang nagpahiram ng lapis?", "ben",
      [("titser", "Si Titser"), ("ben", "Si Ben"), ("nanay", "Si Nanay")],
      "Sino ang lumapit kay Rosa?", "Si Ben ang nagpahiram ng lapis."),
    q("lc4-15", 4, "RL1CAT-II-1a", T2, "p4-lapis", "Saan nakita ni Rosa ang lapis niya?", "kuwaderno",
      [("upuan", "sa ilalim ng upuan"), ("bag", "sa loob ng bag"), ("kuwaderno", "sa loob ng kuwaderno")],
      "Ano ang nangyari pagkatapos ng klase?", "Nakita niya ang lapis sa loob ng kanyang kuwaderno."),
    q("lc4-16", 4, "RL1CAT-II-1f", T2, "p4-lapis", "Bakit malungkot si Rosa?", "pagsusulit",
      [("pagsusulit", "May pagsusulit at wala siyang lapis."), ("ulan", "Umuulan sa labas."),
       ("baon", "Wala siyang baon.")],
      "Ano ang mangyayari sa klase nila?", "Malungkot siya dahil may pagsusulit at wala siyang lapis."),
    q("lc4-17", 4, "RL1CAT-II-2a", T1, "p4-hugas", "Kailan dapat maghugas ng kamay?", "kumain",
      [("tulog", "habang natutulog"), ("kumain", "bago kumain"), ("laro", "habang naglalaro")],
      "Basahin ang ikatlong pangungusap.", "Maghugas ng kamay bago kumain."),
    q("lc4-18", 4, "RL1CAT-II-2a", T1, "p4-hugas", "Ano ang ginagamit sa paghuhugas ng kamay?", "sabon",
      [("sabon", "sabon at malinis na tubig"), ("papel", "papel at lapis"), ("buhangin", "buhangin")],
      "Ano ang sinabi ng teksto na gamitin?", "Gumamit ng sabon at malinis na tubig."),
    q("lc4-19", 4, "RL1CAT-II-2a", T1, "p4-hugas", "Ano ang pampatuyo ng kamay?", "tuwalya",
      [("damit", "damit"), ("tuwalya", "malinis na tuwalya"), ("kurtina", "kurtina")],
      "Basahin ang huling bahagi ng teksto.", "Patuyuin ang kamay gamit ang malinis na tuwalya."),
    q("lc4-20", 4, "RL1CAT-II-2b", T2, "p4-hugas", "Bakit mahalaga ang paghuhugas ng kamay?", "sakit",
      [("damit", "Para bumango ang damit."), ("sakit", "Para hindi magkasakit."), ("buhok", "Para gumanda ang buhok.")],
      "Ano ang dala ng maruming kamay?", "Naghuhugas tayo ng kamay para hindi magkasakit."),
    # ===== Level 5 (English): fluency +8 =====
    sentence("fl5-13", 5, T1, ["The", "girl", "waters", "the", "flowers."], "flower", "Put the words in order."),
    sentence("fl5-14", 5, T1, ["We", "wash", "our", "hands", "before", "lunch."], "hand", "Put the words in order."),
    fill("fl5-15", 5, T1, "I use an ___ when it rains.", "I use an what when it rains? Pick the word that fits.",
         "umbrella", ["umbrella", "apple", "egg"], pic="umbrella", ask="Which word fits?"),
    fill("fl5-16", 5, T1, "The ___ pulls the plow on the farm.",
         "The what pulls the plow on the farm? Pick the word that fits.", "carabao", ["butterfly", "carabao", "cat"],
         pic="carabao", ask="Which word fits?"),
    sentence("fl5-17", 5, T2, ["My", "friends", "and", "I", "play", "tag", "after", "class."],
             ask="Put the words in order."),
    sentence("fl5-18", 5, T2, ["Teacher", "Ana", "writes", "the", "date", "on", "the", "board."],
             ask="Put the words in order."),
    fill("fl5-19", 5, T2, "Please throw your trash in the ___.",
         "Please throw your trash in the what? Pick the word that fits.", "trash can", ["bed", "trash can", "bag"],
         ask="Which word fits?"),
    fill("fl5-20", 5, T2, "The sky turns dark before it ___.", "The sky turns dark before it what? Pick the word that fits.",
         "rains", ["sings", "jumps", "rains"], ask="Which word fits?"),
    # ===== Level 5 (English): literal comprehension +8, two new stories =====
    q("lc5-13", 5, "RL1CAT-II-1a", T1, "p5-market", "Who went with Ana to the market?", "father",
      [("father", "her father"), ("mother", "her mother"), ("teacher", "her teacher")],
      "Look at the first sentence.", "The story says: Ana went to the market with her father."),
    q("lc5-14", 5, "RL1CAT-II-1a", T1, "p5-market", "What did Father buy a kilo of?", "tomatoes",
      [("oranges", "oranges"), ("tomatoes", "tomatoes"), ("mangoes", "mangoes")],
      "They were bright red.", "Father bought a kilo of tomatoes."),
    q("lc5-15", 5, "RL1CAT-II-1f", T2, "p5-market", "Why did the woman give Ana an orange?", "helped",
      [("hungry", "Ana was hungry."), ("paid", "Ana paid for it."), ("helped", "Ana helped her pick up the oranges.")],
      "What did Ana do when the oranges rolled away?", "Ana helped her, so the woman thanked her with an orange."),
    q("lc5-16", 5, "RL1CAT-II-1d", T2, "p5-market", "What will Ana probably do next Saturday?", "market",
      [("market", "Go to the market again."), ("bed", "Stay in bed all day."), ("beach", "Go to the beach.")],
      "Read what Ana said at the end.", "Ana said: I want to go again next Saturday."),
    q("lc5-17", 5, "RL1CAT-II-1a", T1, "p5-program", "Who played the music?", "joy",
      [("mara", "Mara"), ("joy", "Teacher Joy"), ("leo", "Leo")],
      "Who helped the class every afternoon?", "Teacher Joy played the music."),
    q("lc5-18", 5, "RL1CAT-II-1a", T1, "p5-program", "What colors were the costumes?", "red",
      [("red", "red and yellow"), ("blue", "blue and white"), ("green", "green and pink")],
      "Read about the day of the program.", "The class wore red and yellow costumes."),
    q("lc5-19", 5, "RL1CAT-II-1c", T2, "p5-program", "How did Leo feel when he forgot the step?", "worried",
      [("proud", "proud"), ("sleepy", "sleepy"), ("worried", "worried")],
      "Read what happened when Leo forgot the third step.", "Leo felt worried."),
    seq("lc5-20", 5, T2, "p5-program", "Put the story in order.", "What happened first? Put the story in order.",
        [("a", "Leo forgot the third step.", None), ("b", "Mara helped Leo practice.", None),
         ("c", "The audience clapped loudly.", "hand")]),
]

passages = {
    "p3-paaralan": {"level": 3, "language": FIL, "scene": "village", "title": "Unang Araw sa Paaralan",
                    "text": "Unang araw ni Lea sa paaralan. Dala niya ang bagong lapis at kuwaderno. Bumati si "
                            "Titser Ana, \"Magandang umaga!\" Umupo si Lea sa tabi ni Rey. Nagbahagi si Lea ng "
                            "krayola kay Rey. Masaya si Lea pag-uwi."},
    "p3-kalabaw": {"level": 3, "language": FIL, "scene": "village", "title": "Ang Kalabaw ni Tatay",
                   "text": "May kalabaw si Tatay. Ang pangalan nito ay Kalog. Tuwing umaga, tumutulong si Kalog sa "
                           "bukid. Sa tanghali, naliligo ito sa putikan. Gustong-gusto ni Kalog ang damo. Mahal ni "
                           "Nilo si Kalog."},
    "p4-lapis": {"level": 4, "language": FIL, "scene": "village", "title": "Ang Nawawalang Lapis",
                 "text": "Isang umaga, hindi makita ni Rosa ang kanyang lapis. Hinanap niya ito sa kanyang bag at sa "
                         "ilalim ng upuan. Malungkot siya dahil may pagsusulit sila. Lumapit si Ben at sinabing, "
                         "\"Hiramin mo muna ang lapis ko.\" Natuwa si Rosa at nagpasalamat. Pagkatapos ng klase, "
                         "nakita ni Rosa ang lapis niya sa loob ng kanyang kuwaderno. Ibinalik niya ang lapis ni Ben "
                         "at binigyan pa niya ito ng kendi."},
    "p4-hugas": {"level": 4, "language": FIL, "scene": "home", "title": "Ang Paghuhugas ng Kamay",
                 "text": "Mahalaga ang paghuhugas ng kamay. Ang maruming kamay ay may mikrobyo na nagdudulot ng "
                         "sakit. Maghugas ng kamay bago kumain at pagkatapos gumamit ng banyo. Gumamit ng sabon at "
                         "malinis na tubig. Kuskusin ang mga kamay habang nagbibilang hanggang dalawampu. Banlawan at "
                         "patuyuin gamit ang malinis na tuwalya. Sa ganitong paraan, malusog at ligtas tayo."},
    "p5-market": {"level": 5, "language": EN, "scene": "village", "title": "Saturday at the Market",
                  "text": "On Saturday, Ana went to the market with her father. The market was busy and loud. They "
                          "bought fish, rice and green vegetables. Ana saw a stall full of bright red tomatoes, so "
                          "Father bought a kilo. On the way out, Ana saw an old woman drop her bag of oranges. The "
                          "oranges rolled everywhere! Ana quickly helped her pick them up. The woman smiled and gave "
                          "Ana one sweet orange. At home, Ana told Mother about the busy market and the kind woman. "
                          "\"I want to go again next Saturday,\" she said."},
    "p5-program": {"level": 5, "language": EN, "scene": "village", "title": "The School Program",
                   "text": "The Grade 1 class practiced a dance for the school program. Every afternoon, Teacher Joy "
                           "played the music, and the children practiced the steps. Leo always forgot the third "
                           "step. He felt worried. His friend Mara said, \"Watch my feet, and count with me.\" They "
                           "practiced together every day. On the day of the program, the class wore red and yellow "
                           "costumes. When the music started, Leo counted softly and did every step right. The "
                           "audience clapped loudly. Leo smiled and hugged Mara."},
}
json.dump({"note": "DRAFT for teacher review. 112 more items so each skill at each level has 20 (10 easier, "
                   "10 harder). Not in the game yet.", "items": items, "passages": passages},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
print(len(items), "items,", len(passages), "passages")
