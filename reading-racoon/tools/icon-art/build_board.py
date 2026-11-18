"""Writes the canvas boards that show the redrawn picture icons (Icons page of the Racoon canvas)."""
import json
import os
import re
import sys

from icon_set import ICONS, draw

ROOT = sys.argv[1]            # canvas root (holds project/)
OLD = sys.argv[2]             # the game's current assets/icons folder
INDEX_IN = sys.argv[3]        # canvas.json as read from the canvas
PROJ = os.path.join(ROOT, "project")
os.makedirs(PROJ, exist_ok=True)

INK = "#3a2a1f"
SOFT_INK = "#7d6857"
_n = [0]


def icon(name, px, label=None, mode="paper"):
    _n[0] += 1
    return draw(name, prefix="i%d-" % _n[0], mode=mode).svg(px=px, label=label, board=True)


def old_icon(name, px, color):
    src = open(os.path.join(OLD, name + ".svg"), encoding="utf-8").read()
    vb = re.search(r'viewBox="([^"]+)"', src).group(1)
    body = re.sub(r"^.*?<svg[^>]*>", "", src, flags=re.S).replace("</svg>", "")
    body = body.replace('fill="#fff"', 'fill="%s"' % color).replace('fill="#ffffff"', 'fill="%s"' % color)
    return '<svg viewBox="%s" width="%d" height="%d" aria-hidden="true">%s</svg>' % (vb, px, px, body.strip())


HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>%s</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Andika:wght@400;700&amp;display=swap">
<style>
body{margin:0}
a{color:#1d7166}a:hover{color:#3a2a1f}
</style>
</helmet>
"""

TAIL = """</x-dc>
<script type="text/x-dc" data-dc-script data-props='%s'>
class Component extends DCLogic {
  renderVals() {
    return { card: this.props.card ?? '#fff8e7' };
  }
}
</script>
</body>
</html>
"""


def props(w, h):
    return json.dumps({"card": {"editor": "color", "default": "#fff8e7",
                                "options": ["#fff8e7", "#fffef4", "#d4e6f2", "#74a6cb"]},
                       "$preview": {"width": w, "height": h}}, separators=(",", ":"))


def leaves(w, h):
    """The leafy green ground behind the white panel, like the reference board."""
    shapes = []
    spots = [(40, 60, 70, -30, "#7fbf5c"), (w - 60, 90, 80, 35, "#8fcd6a"), (30, h - 80, 90, 20, "#8fcd6a"),
             (w - 50, h - 60, 70, -40, "#7fbf5c"), (w / 2, -10, 60, 80, "#8fcd6a"), (w / 2 + 300, h + 6, 70, -70, "#7fbf5c"),
             (-10, h / 2, 64, 60, "#7fbf5c"), (w + 6, h / 2 + 40, 70, -60, "#8fcd6a")]
    for (x, y, r, a, c) in spots:
        shapes.append('<path d="M %d %d Q %d %d %d %d Q %d %d %d %d Z" fill="%s" transform="rotate(%d %d %d)"/>' % (
            x - r, y, x, y - r * 0.55, x + r, y, x, y + r * 0.55, x - r, y, c, a, x, y))
        shapes.append('<path d="M %d %d L %d %d" stroke="#6aab4c" stroke-width="3" stroke-linecap="round" '
                      'transform="rotate(%d %d %d)"/>' % (x - r + 8, y, x + r - 8, y, a, x, y))
    return ('<svg viewBox="0 0 %d %d" width="%d" height="%d" aria-hidden="true" '
            'style="position: absolute; left: 0; top: 0; display: block">\n%s\n</svg>\n' % (w, h, w, h, "\n".join(shapes)))


def frame(w, h, inner):
    return ('<div style="position: relative; width: %dpx; height: %dpx; box-sizing: border-box; padding: 32px; '
            'background: #9fd47f; font-family: \'Andika\', sans-serif; color: %s; overflow: hidden">\n%s'
            '<div style="position: relative; height: 100%%; box-sizing: border-box; background: #ffffff; border-radius: 40px; '
            'padding: 36px 40px; box-shadow: 0 8px 0 rgba(58, 42, 31, 0.12); display: flex; flex-direction: column; gap: 22px">\n'
            '%s</div>\n</div>\n' % (w, h, INK, leaves(w, h), inner))


def header(title, sub, chips=()):
    chip_html = "".join(
        '<span style="background: #fff3c4; color: #6b4a00; border-radius: 999px; padding: 6px 16px; font-size: 18px; '
        'font-weight: 700; white-space: nowrap">%s</span>' % c for c in chips)
    return ('<header style="display: flex; justify-content: space-between; align-items: flex-end; gap: 32px">\n'
            '<div style="display: flex; flex-direction: column; gap: 6px; min-width: 0">\n'
            '<h1 style="margin: 0; font-size: 44px; line-height: 1.1; font-weight: 700">%s</h1>\n'
            '<p style="margin: 0; font-size: 21px; line-height: 1.4; color: %s; max-width: 900px">%s</p>\n</div>\n'
            '<div style="display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; max-width: 520px">%s</div>\n'
            '</header>\n' % (title, SOFT_INK, sub, chip_html))


def section(title, count):
    return ('<h2 style="margin: 0; font-size: 24px; font-weight: 700; display: flex; align-items: center; gap: 10px">%s'
            '<span style="font-size: 18px; color: %s; font-weight: 400">%d</span></h2>\n' % (title, SOFT_INK, count))


def card(name):
    label = ICONS[name][2]
    return ('<figure style="margin: 0; background: {{card}}; border-radius: 26px; box-shadow: 0 4px 0 rgba(58, 42, 31, 0.08); '
            'padding: 12px 8px 10px; display: flex; flex-direction: column; align-items: center; gap: 4px">\n'
            '%s<figcaption style="font-size: 20px; font-weight: 700; white-space: nowrap">%s</figcaption>\n</figure>\n'
            % (icon(name, 120, label), label))


def grid(names, extra=""):
    return ('<div style="display: grid; grid-template-columns: repeat(8, minmax(0, 1fr)); gap: 16px">\n%s%s</div>\n'
            % ("".join(card(n) for n in names), extra))


def group(g):
    return [n for n, v in ICONS.items() if v[1] == g]


CHIPS = ("Flat paper cut-outs", "A crisp little shadow", "Faces on animals, sky and fruit", "The game's own colours")
SUB = ("Cut from paper like the rest of the game: flat colours lifted on a crisp little shadow, "
       "no shine or outlines. These are the pictures in the game now (D-027).")


def write(name, title, w, h, body):
    with open(os.path.join(PROJ, name), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(HEAD % title + frame(w, h, body) + TAIL % props(w, h))
    print("wrote", name, os.path.getsize(os.path.join(PROJ, name)), "bytes")


# --- board A: animals, then sky, nature and food
A_W, A_H = 1600, 1200
animals = group("Animals")
sky = group("Sky and nature") + group("Food")
write("IconsA.dc.html", "Picture icons: animals, sky and food", A_W, A_H,
      header("Picture icons, paper cut-outs", SUB, CHIPS)
      + section("Animals", len(animals)) + grid(animals)
      + section("Sky, nature and food", len(sky)) + grid(sky))

# --- board B: things, and the glyphs that stay one colour
B_W, B_H = 1600, 1100
things = group("Things")
glyphs = [("arrow_left", "#e9801f"), ("arrow_right", "#e9801f"), ("check", "#6aab4c"), ("play", "#74a6cb"),
          ("pause", "#74a6cb"), ("repeat", "#8e6aa0"), ("talk", "#2a9d8f"), ("heart_plus", "#e9801f")]
note = ('<div style="grid-column: span %d; background: #f6f1e4; border-radius: 26px; padding: 18px 24px; display: flex; '
        'flex-direction: column; justify-content: center; gap: 12px">\n'
        '<p style="margin: 0; font-size: 20px; line-height: 1.4"><b>These stay one colour.</b> They sit on buttons, '
        'and the game paints them to match each button.</p>\n'
        '<div style="display: flex; gap: 12px; flex-wrap: wrap">\n%s</div>\n</div>\n') % (
    8 - len(things) % 8 if len(things) % 8 else 8,
    "".join('<span style="width: 60px; height: 60px; border-radius: 18px; background: %s; box-shadow: 0 4px 0 rgba(58, 42, 31, 0.18); '
            'display: flex; align-items: center; justify-content: center">%s</span>\n' % (c, old_icon(n, 34, "#ffffff"))
            for n, c in glyphs))
write("IconsB.dc.html", "Picture icons: things", B_W, B_H,
      header("Things", "Objects stay faceless, so the faces mean something: living things, the sky and fruit.")
      + section("Things", len(things)) + grid(things, note))

# --- board C: at game sizes, before and after, and the outline choice
C_W, C_H = 1600, 1500


def box(title, inner, style=""):
    return ('<section style="background: #fbf7ee; border-radius: 28px; padding: 22px 24px; display: flex; '
            'flex-direction: column; gap: 14px; min-width: 0; %s">\n<h2 style="margin: 0; font-size: 24px">%s</h2>\n%s</section>\n'
            % (style, title, inner))


lesson = ('<div style="background: #dcebf0; border-radius: 22px; padding: 22px; display: flex; flex-direction: column; '
          'align-items: center; gap: 18px">\n'
          '<p style="margin: 0; font-size: 30px; font-weight: 700">Which one is a fish?</p>\n'
          '<div style="display: flex; gap: 20px">\n%s</div>\n</div>\n') % "".join(
    '<span style="width: 160px; height: 160px; border-radius: 28px; background: #fffef4; box-shadow: 0 6px 0 rgba(58, 42, 31, 0.16); '
    'display: flex; align-items: center; justify-content: center">%s</span>\n' % icon(n, 128) for n in ("cat", "fish", "hen"))

tiles = ('<div style="display: flex; gap: 20px; justify-content: center; align-items: center; flex-grow: 1">\n%s</div>\n') % "".join(
    '<span style="width: 196px; height: 196px; border-radius: 32px; background: %s; box-shadow: 0 6px 0 rgba(58, 42, 31, 0.2); '
    'display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px">%s'
    '<b style="font-size: 22px">%s</b></span>\n' % (c, icon(n, 104), t)
    for n, c, t in (("bulb", "#6aab4c", "Practice"), ("book", "#e9801f", "Library"), ("speaker", "#74a6cb", "Watch &amp; Listen")))

stickers = ('<div style="background: #b9a2c8; border-radius: 22px; padding: 18px; display: flex; gap: 14px; flex-wrap: wrap; '
            'justify-content: center">\n%s</div>\n') % "".join(
    '<span style="width: 100px; height: 100px; border-radius: 50%%; background: #fffef4; box-shadow: 0 4px 0 rgba(58, 42, 31, 0.18); '
    'display: flex; align-items: center; justify-content: center">%s</span>\n' % icon(n, 80)
    for n in ("sun", "cloud", "moon", "palm", "apple", "banana", "grapes", "star", "heart", "gift", "cake", "chest"))

tiny_names = ["cat", "dog", "fish", "hen", "bee", "sun", "star", "moon", "tree", "boat", "bus", "car", "house", "hat",
              "hand", "ball", "box", "bag", "book", "apple", "banana", "cake"]
tiny = ('<div style="display: flex; gap: 12px; flex-wrap: wrap">\n%s</div>\n' % "".join(icon(n, 48, ICONS[n][2]) for n in tiny_names))

OLD_COLORS = {"fish": "#2a9d8f", "mouse": "#7d6857", "hat": "#3a2a1f", "cloud": "#7d6857", "cat": "#cc8a00", "house": "#bd6212"}
arrow = ('<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><path d="M 4 12 L 18 12 M 13 6 L 19 12 L 13 18" '
         'fill="none" stroke="#7d6857" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>')
pairs = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px">\n%s</div>\n') % "".join(
    '<figure style="margin: 0; background: #ffffff; border-radius: 22px; padding: 10px; display: flex; flex-direction: column; '
    'align-items: center; gap: 2px">\n<div style="display: flex; align-items: center; gap: 6px">%s%s%s</div>\n'
    '<figcaption style="font-size: 17px; color: %s">%s</figcaption>\n</figure>\n' % (
        old_icon(n, 72, OLD_COLORS[n]), arrow, icon(n, 80), SOFT_INK,
        "Mouse, now the animal" if n == "mouse" else ICONS[n][2])
    for n in ("mouse", "fish", "cat", "hat", "cloud", "house"))

cmp_names = ["cat", "sun", "apple", "bus", "fish", "raccoon"]


def cmp_row(mode, title, note):
    return ('<div style="background: #ffffff; border-radius: 22px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px">\n'
            '<p style="margin: 0; font-size: 19px"><b>%s</b> <span style="color: %s">%s</span></p>\n'
            '<div style="display: flex; gap: 10px; justify-content: space-between">%s</div>\n</div>\n'
            % (title, SOFT_INK, note, "".join(icon(n, 92, mode=mode) for n in cmp_names)))


outline = (cmp_row("soft", "First try: stickers.", "Gradients, shine and outlines looked out of place in the paper world.")
           + cmp_row("paper", "Now: paper cut-outs.", "Flat colours on a crisp shadow, like the buttons and trees."))

body = (header("In the game", "The same pictures at the sizes the game shows them, next to what they replace.")
        + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 22px">\n'
        + box("In a lesson, 128 px", lesson) + box("Home tiles, 104 px", tiles) + "</div>\n"
        + box("Sticker book, 80 px", stickers)
        + box("Smallest, 48 px", tiny)
        + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 22px">\n'
        + box("Before and after", pairs) + box("Stickers or paper?", outline) + "</div>\n")
write("IconsGame.dc.html", "Picture icons in the game", C_W, C_H, body)

# --- the canvas index: an Icons page with the three boards
idx = json.load(open(INDEX_IN, encoding="utf-8"))
pages = idx.get("pages") or []
if not pages:
    pages = [{"id": "racoon", "name": "Racoon"}]
if not any(p["id"] == "icons" for p in pages):
    pages.append({"id": "icons", "name": "Icons"})
idx["pages"] = pages
idx["boards"]["IconsA.dc.html"] = {"x": 0, "y": 0, "w": A_W, "h": A_H, "page": "icons",
                                   "title": "Icons · animals, sky and food (paper cut-outs)"}
idx["boards"]["IconsB.dc.html"] = {"x": A_W + 80, "y": 0, "w": B_W, "h": B_H, "page": "icons",
                                   "title": "Icons · things (paper cut-outs)"}
idx["boards"]["IconsGame.dc.html"] = {"x": 0, "y": A_H + 120, "w": C_W, "h": C_H, "page": "icons",
                                      "title": "Icons · in the game, before and after, stickers or paper"}
for k in ("IconsA.dc.html", "IconsB.dc.html", "IconsGame.dc.html"):
    if k not in idx["order"]:
        idx["order"].append(k)
idx.setdefault("notes", {})["icons-title"] = {"x": 0, "y": -300, "text": "Picture icons, cut from paper like the game",
                                              "kind": "title1", "maxW": A_W + 80 + B_W, "page": "icons"}
idx["launch"] = {"view": "canvas", "page": "icons"}
with open(os.path.join(PROJ, "canvas.json"), "w", encoding="utf-8", newline="\n") as fh:
    json.dump(idx, fh, indent=2)
    fh.write("\n")
print("wrote canvas.json with", len(idx["boards"]), "boards and pages", [p["id"] for p in pages])
