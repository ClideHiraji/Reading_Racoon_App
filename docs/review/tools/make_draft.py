"""Write the tier draft: a tier for every existing adventure item plus new items.

Tier 1 = easier (comfort), tier 2 = harder (stretch). Rescue items keep no tier.
Usage: python -I make_draft.py <out.json>
"""
import json
import sys

T1, T2 = 1, 2
groups = {
    T1: "pa1-01 pa1-02 pa1-04 pa1-07 pa1-08 ph1-01 ph1-03 ph1-06 ph1-08 "
        "pa2-02 pa2-03 pa2-05 pa2-06 pa2-10 ph2-01 ph2-05 ph2-07 ph2-09 ph2-11 vo2-01 vo2-02 vo2-03 "
        "ph3-01 ph3-02 ph3-03 ph3-04 ph3-07 vo3-01 vo3-02 vo3-05 vo3-08 fl3-04 fl3-05 fl3-06 fl3-08 "
        "lc3-01 lc3-02 lc3-05 lc3-06 lc3-09 lc3-10 "
        "vo4-02 vo4-03 vo4-05 vo4-06 fl4-01 fl4-02 fl4-03 fl4-06 fl4-07 lc4-01 lc4-02 lc4-05 lc4-09 lc4-10 "
        "fl5-01 fl5-02 fl5-05 fl5-08 lc5-01 lc5-02 lc5-07 lc5-08 lc5-09",
    T2: "pa1-03 pa1-05 pa1-06 ph1-02 ph1-04 ph1-05 ph1-07 "
        "pa2-01 pa2-04 pa2-07 pa2-08 pa2-09 pa2-11 ph2-02 ph2-03 ph2-04 ph2-06 ph2-08 ph2-10 "
        "vo2-04 vo2-05 vo2-06 vo2-07 vo2-08 "
        "ph3-05 ph3-06 ph3-08 ph3-09 vo3-03 vo3-04 vo3-06 vo3-07 fl3-01 fl3-02 fl3-03 fl3-07 "
        "lc3-03 lc3-04 lc3-07 lc3-08 lc3-11 lc3-12 "
        "vo4-01 vo4-04 vo4-07 vo4-08 fl4-04 fl4-05 fl4-08 lc4-03 lc4-04 lc4-06 lc4-07 lc4-08 lc4-11 lc4-12 "
        "fl5-03 fl5-04 fl5-06 fl5-07 lc5-03 lc5-04 lc5-05 lc5-06 lc5-10 lc5-11",
}
tiers = {i: t for t, ids in groups.items() for i in ids.split()}

# Why each item got its tier, shown in the review pack.
reasons = {
    "phonological_awareness": "Tier 1: common rhyme or a long first sound (s, m). Tier 2: stop sounds, more choices, "
                              "more syllables.",
    "phonics": "Tier 1: first sound or letter. Tier 2: middle or last sound, look-alike letters (b, d, p), "
               "near-miss words (pig, pin, big).",
    "vocabulary": "Tier 1: listen and tap a picture. Tier 2: read the word yourself, describing words, "
                  "sight words among look-alikes.",
    "fluency": "Tier 1: fewer words, or a picture that helps. Tier 2: more words, or no picture.",
    "literal_comprehension": "Tier 1: who, what, where stated in one sentence. Tier 2: when, how many, why, "
                             "feelings, order of events, predicting.",
}


def choice(cid, label=None, picture=None, repeat=None):
    c = {"id": cid}
    if label is not None:
        c["label"] = label
    if picture:
        c["picture"] = picture
    if repeat:
        c["repeat"] = repeat
    return c


def item(id, skill, level, code, lang, tier, task, prompt, tts, answer, choices=None, **extra):
    it = {"id": id, "sub_skill": skill, "level": level, "competency": code, "language": lang,
          "task_type": task, "prompt": prompt, "tts_text": tts}
    it.update(extra)
    if choices is not None:
        it["choices"] = choices
    it.update({"answer": answer, "recovery": False, "tier": tier, "new": True})
    return it


EN, FIL = "en-placeholder", "fil-placeholder"
PA, PH, VO, FL, LC = ("phonological_awareness", "phonics", "vocabulary", "fluency", "literal_comprehension")
TAP, DRAG, ORDER, SPIN = "tap_choice", "drag_letter", "order_tiles", "spin_words"
pic = lambda name: choice(name, name, name)

new = [
    # Level 1, phonological awareness (8 -> 12)
    item("pa1-09", PA, 1, "RL1PA-I-3", EN, T1, TAP, "Which one rhymes with hat?", "Which one rhymes with hat?",
         "cat", [pic("cat"), pic("bus"), pic("moon")], picture="hat", word="hat"),
    item("pa1-10", PA, 1, "RL1PA-I-3", EN, T2, TAP, "Which one rhymes with frog?", "Which one rhymes with frog?",
         "dog", [pic("fish"), pic("dog"), pic("ball"), pic("cake")], picture="frog", word="frog"),
    item("pa1-11", PA, 1, "RL1PA-I-5", EN, T2, TAP, "Which one starts with /p/?",
         "Which one starts with the sound p, like pop?", "pear", [pic("bear"), pic("pear"), pic("hen")]),
    item("pa1-12", PA, 1, "RL1PA-I-5", EN, T2, TAP, "Which one starts with /d/?",
         "Which one starts with the sound d, like drum?", "dog", [pic("bag"), pic("goat"), pic("dog")]),
    # Level 1, phonics (8 -> 12)
    item("ph1-09", PH, 1, "RL1PWS-II-1", EN, T1, TAP, "Which letter says /s/?", "Which letter says sss, like a snake?",
         "s", [choice("s", "s"), choice("b", "b"), choice("h", "h")]),
    item("ph1-10", PH, 1, "RL1PWS-II-3", EN, T1, TAP, "Moon starts with which letter?",
         "Moon. Moon starts with which letter?", "m", [choice("m", "m"), choice("t", "t"), choice("b", "b")],
         picture="moon"),
    item("ph1-11", PH, 1, "RL1PWS-II-3", EN, T2, DRAG, "Make the word box.", "Box. Drag the missing letter to make box.",
         "o", [choice("a", "a"), choice("o", "o"), choice("i", "i")], picture="box", pattern=["b", "_", "x"]),
    item("ph1-12", PH, 1, "RL1PWS-II-2", EN, T2, TAP, "Tap the letter d.", "Tap the letter d.", "d",
         [choice("b", "b"), choice("d", "d"), choice("p", "p")]),
    # Level 2, phonological awareness (11 -> 12)
    item("pa2-12", PA, 2, "RL1PA-I-2", EN, T1, TAP, "How many claps in apple?",
         "Clap it with me. Ap. Ple. How many claps?", "2",
         [choice("1", "1", "hand", 1), choice("2", "2", "hand", 2), choice("3", "3", "hand", 3)],
         picture="apple", word="apple", hint="Clap it with me: ap, ple. Count each clap.",
         explain="Ap-ple has 2 claps."),
    # Level 2, phonics (11 -> 12)
    item("ph2-12", PH, 2, "RL1PWS-II-4", EN, T1, SPIN, "Spin to make cat.", "Cat. Spin the wheel to make the word cat.",
         "c", [choice("s", "s"), choice("c", "c"), choice("p", "p"), choice("r", "r")], picture="cat", rime="at"),
    # Level 2, vocabulary (8 -> 12): school words
    item("vo2-09", VO, 2, "RL1VWK-II-1", EN, T1, TAP, "Tap the bus.", "Tap the bus. The bus takes us to school.",
         "bus", [pic("car"), pic("bus"), pic("boat")]),
    item("vo2-10", VO, 2, "RL1VWK-II-1", EN, T1, TAP, "Tap the sticker.", "Tap the sticker.", "sticker",
         [pic("sticker"), pic("pencil"), pic("book")]),
    item("vo2-11", VO, 2, "RL1VWK-II-1", EN, T1, TAP, "Tap the star.", "Teacher gives you a star. Tap the star.",
         "star", [pic("moon"), pic("sun"), pic("star")]),
    item("vo2-12", VO, 2, "RL1VWK-II-3", EN, T2, TAP, "Tap the word is.", "Tap the word is.", "is",
         [choice("it", "it"), choice("is", "is"), choice("in", "in")], variant="word_catch"),
    # Level 3, phonics (9 -> 12)
    item("ph3-10", PH, 3, "RL1PWS-II-5", FIL, T1, ORDER, "Buuin ang salitang lapis.",
         "La. Pis. Pindutin ang mga pantig para mabuo ang lapis.", "la|pis", picture="pencil",
         variant="syllables", tiles=["la", "pis"]),
    item("ph3-11", PH, 3, "RL1PWS-II-5", FIL, T2, ORDER, "Buuin ang salitang bituin.",
         "Bi. Tu. In. Pindutin ang mga pantig para mabuo ang bituin.", "bi|tu|in", picture="star",
         variant="syllables", tiles=["bi", "tu", "in"]),
    item("ph3-12", PH, 3, "RL1PWS-II-5", FIL, T2, ORDER, "Buuin ang salitang paruparo.",
         "Pa. Ru. Pa. Ro. Pindutin ang mga pantig para mabuo ang paruparo.", "pa|ru|pa|ro", picture="butterfly",
         variant="syllables", tiles=["pa", "ru", "pa", "ro"]),
    # Level 3, vocabulary (8 -> 12): school words
    item("vo3-09", VO, 3, "RL1VWK-II-1", FIL, T1, TAP, "Pindutin ang lapis.", "Pindutin ang lapis.", "pencil",
         [pic("pencil"), pic("book"), pic("bag")]),
    item("vo3-10", VO, 3, "RL1VWK-II-1", FIL, T1, TAP, "Pindutin ang aklat.", "Pindutin ang aklat.", "book",
         [pic("bag"), pic("book"), pic("scissors")]),
    item("vo3-11", VO, 3, "RL1VWK-II-2a", FIL, T2, TAP, "Basahin ang salita. Pindutin ang larawan.",
         "Basahin ang salita. Pindutin ang larawan.", "scissors",
         [choice("pencil", picture="pencil"), choice("scissors", picture="scissors"), choice("book", picture="book")],
         word="gunting"),
    item("vo3-12", VO, 3, "RL1VWK-II-3", FIL, T2, TAP, "Pindutin ang salitang si.", "Pindutin ang salitang si.", "si",
         [choice("sa", "sa"), choice("si", "si"), choice("ay", "ay"), choice("ang", "ang")]),
    # Level 3, fluency (8 -> 12)
    item("fl3-09", FL, 3, "RL1BPK-II-3", FIL, T1, ORDER, "Ayusin ang mga salita.", "May aklat ako. Ayusin ang mga salita.",
         "May|aklat|ako.", picture="book", variant="sentence", tiles=["May", "aklat", "ako."]),
    item("fl3-10", FL, 3, "RL1BPK-II-3", FIL, T1, ORDER, "Ayusin ang mga salita.", "Ito ay lapis. Ayusin ang mga salita.",
         "Ito|ay|lapis.", picture="pencil", variant="sentence", tiles=["Ito", "ay", "lapis."]),
    item("fl3-11", FL, 3, "RL1BPK-II-3", FIL, T2, ORDER, "Ayusin ang mga salita.",
         "Masaya kami sa paaralan. Ayusin ang mga salita.", "Masaya|kami|sa|paaralan.", variant="sentence",
         tiles=["Masaya", "kami", "sa", "paaralan."]),
    item("fl3-12", FL, 3, "RL1PWS-II-5", FIL, T2, TAP, "Ano ang kulang?",
         "Sumakay kami sa ano papuntang paaralan? Piliin ang tamang salita.", "bus",
         [choice("puno", "puno"), choice("bus", "bus"), choice("aso", "aso")],
         sentence="Sumakay kami sa ___ papuntang paaralan."),
    # Level 4, vocabulary (8 -> 12): GMRC, Math, describing words
    item("vo4-09", VO, 4, "RL1VWK-II-4", FIL, T1, TAP, "Nahulog ang lapis ng kaklase mo. Ano ang gagawin mo?",
         "Nahulog ang lapis ng kaklase mo. Ano ang gagawin mo?", "pulot",
         [choice("pulot", "Pulutin at ibigay sa kanya."), choice("tawa", "Tawanan siya."),
          choice("tago", "Itago ang lapis.")],
         hint="Ano ang ginagawa ng mabuting kaklase?", explain="Pinupulot natin ito at ibinibigay sa kanya."),
    item("vo4-10", VO, 4, "RL1VWK-II-4", FIL, T1, TAP, "Alin ang bilog?", "Alin ang hugis bilog?", "ball",
         [pic("book"), pic("ball"), pic("box")],
         hint="Ang bilog ay walang kanto.", explain="Ang bola ay bilog."),
    item("vo4-11", VO, 4, "RL1VWK-II-2b", FIL, T2, TAP, "Alin ang salitang naglalarawan?",
         "Alin ang salitang naglalarawan?", "masipag",
         [choice("paaralan", "paaralan"), choice("masipag", "masipag"), choice("sumulat", "sumulat")],
         hint="Ang salitang naglalarawan ay nagsasabi kung ano ang isang tao o bagay.",
         explain="Ang masipag ay naglalarawan sa isang tao."),
    item("vo4-12", VO, 4, "RL1VWK-II-2b", FIL, T2, TAP, "Ano ang ibig sabihin ng masipag?",
         "Ano ang ibig sabihin ng masipag?", "trabaho",
         [choice("trabaho", "laging gumagawa nang mabuti"), choice("tulog", "laging natutulog"),
          choice("iyak", "laging umiiyak")],
         hint="Ang batang masipag ay laging tumutulong at gumagawa.",
         explain="Ang masipag ay laging gumagawa nang mabuti."),
    # Level 4, fluency (8 -> 12)
    item("fl4-09", FL, 4, "RL1BPK-II-3", FIL, T1, ORDER, "Ayusin ang mga salita.",
         "Nagbabasa ang bata ng aklat. Ayusin ang mga salita.", "Nagbabasa|ang|bata|ng|aklat.",
         picture="book", variant="sentence", tiles=["Nagbabasa", "ang", "bata", "ng", "aklat."]),
    item("fl4-10", FL, 4, "RL1BPK-II-3", FIL, T2, ORDER, "Ayusin ang mga salita.",
         "Sumulat si Ana sa kanyang kuwaderno. Ayusin ang mga salita.", "Sumulat|si|Ana|sa|kanyang|kuwaderno.",
         variant="sentence", tiles=["Sumulat", "si", "Ana", "sa", "kanyang", "kuwaderno."]),
    item("fl4-11", FL, 4, "RL1BPK-II-3", FIL, T2, ORDER, "Ayusin ang mga salita.",
         "Tumunog ang kampana sa paaralan kanina. Ayusin ang mga salita.",
         "Tumunog|ang|kampana|sa|paaralan|kanina.", variant="sentence",
         tiles=["Tumunog", "ang", "kampana", "sa", "paaralan", "kanina."]),
    item("fl4-12", FL, 4, "RL1PWS-II-5", FIL, T2, TAP, "Ano ang kulang?",
         "Nagsusulat ako gamit ang ano? Piliin ang tamang salita.", "lapis",
         [choice("kutsara", "kutsara"), choice("payong", "payong"), choice("lapis", "lapis")],
         sentence="Nagsusulat ako gamit ang ___."),
    # Level 5, fluency (8 -> 12)
    item("fl5-09", FL, 5, "RL1BPK-II-3", EN, T1, ORDER, "Put the words in order.",
         "The bus takes us to school. Put the words in order.", "The|bus|takes|us|to|school.",
         picture="bus", variant="sentence", tiles=["The", "bus", "takes", "us", "to", "school."]),
    item("fl5-10", FL, 5, "RL1PWS-II-5", EN, T1, TAP, "Which word fits?",
         "I read a what in class? Pick the word that fits.", "book",
         [choice("book", "book"), choice("cloud", "cloud"), choice("fish", "fish")],
         sentence="I read a ___ in class."),
    item("fl5-11", FL, 5, "RL1BPK-II-3", EN, T2, ORDER, "Put the words in order.",
         "Our teacher reads us a story every day. Put the words in order.",
         "Our|teacher|reads|us|a|story|every|day.", picture="book", variant="sentence",
         tiles=["Our", "teacher", "reads", "us", "a", "story", "every", "day."]),
    item("fl5-12", FL, 5, "RL1PWS-II-5", EN, T2, TAP, "Which word fits?",
         "We line up when the what rings? Pick the word that fits.", "bell",
         [choice("frog", "frog"), choice("tree", "tree"), choice("bell", "bell")],
         sentence="We line up when the ___ rings."),
    # Level 5, literal comprehension (11 -> 12)
    item("lc5-12", LC, 5, "RL1CAT-II-1a", EN, T1, TAP, "What did Mia make the boat from?",
         "What did Mia make the boat from?", "page",
         [choice("page", "an old notebook page"), choice("leaf", "a banana leaf"), choice("wood", "a piece of wood")],
         passage="p5-boat", hint="Look at the first sentence of the story.",
         explain="The story says: Mia made a paper boat from an old notebook page."),
]

json.dump({"note": "DRAFT for teacher review. Not in the game yet. Tier 1 = easier, tier 2 = harder.",
           "reasons": reasons, "tiers": tiers, "new_items": new},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
print(len(tiers), "tiered,", len(new), "new")
