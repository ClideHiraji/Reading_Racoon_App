"""Every picture icon in the new style. Each function draws one icon on an Icon (icons_gen)."""
import json
import math
import os
from icons_gen import (Icon, INK, W, deep, shade, lite, mix, f, pt, rounded, star_pts, crescent,
                       ring, leaf_d, spark_d, tag)

YEL = "#ffc918"      # Palette.YELLOW
GOLD = "#f7bd2a"
ORA = "#e9801f"      # Palette.ORANGE
RED = "#e2574c"
PINK = "#f59bb6"
LIL = "#b48fd0"
PLUM = "#8e6aa0"     # Palette.PLUM
BLU = "#74a6cb"      # Palette.BLUE
SKY = "#a9d3ea"
TEAL = "#2a9d8f"     # Palette.TEAL
LEAF = "#6aab4c"     # Palette.LEAF
BARK = "#b9875b"     # Palette.NIPA
CREAM = "#fff3dc"
SKIN = "#f2c29b"
STEM = "#8a5a3a"
GLASS = "#c4e8f8"
EAR_PINK = "#ffb3c4"


def leaf(s, S, E, bend=0, w=7, c=LEAF):
    d, rib = leaf_d(S, E, bend, w)
    s.P(d, c)
    s.stroke(rib, deep(c), 2, op=0.55)


def small_star(s, cx, cy, R, r, c=YEL, line=None):
    s.P(rounded(star_pts(cx, cy, R, r), [0.2 if i % 2 == 0 else 0.1 for i in range(10)]), c, line=line)


# ---------------------------------------------------------------- sky and nature
def sun(s):
    s.shadow(rx=24, cy=116)
    cx, cy = 64, 60
    for i in range(8):
        a = math.radians(i * 45 - 90)
        b1 = (cx + 25 * math.cos(a - 0.3), cy + 25 * math.sin(a - 0.3))
        t = (cx + 52 * math.cos(a), cy + 52 * math.sin(a))
        b2 = (cx + 25 * math.cos(a + 0.3), cy + 25 * math.sin(a + 0.3))
        s.P("M %s L %s L %s Z" % (pt(b1), pt(t), pt(b2)), ORA)
    s.C(cx, cy, 31, YEL, g=s.rad(YEL, 52, 46, 44))
    s.gloss(50, 44, 7, 4.5, -35)
    s.face(64, 62, gap=20, eye=3.4)


def moon(s):
    s.shadow(rx=24)
    c = "#ffe27a"
    s.P(crescent((60, 62), 42, (86, 42), 32), c, g=s.rad(c, 40, 52, 64))
    s.face(44, 74, gap=15, eye=3.2, eyes="sleep", bdx=11, bdy=4)
    s.P(spark_d(100, 76, 8), "#fff0a8")
    s.P(spark_d(94, 30, 5), "#fff0a8")


def star(s):
    s.shadow(rx=26, cy=114)
    c = "#ffcf33"
    s.P(rounded(star_pts(64, 62, 48, 23), [0.22 if i % 2 == 0 else 0.12 for i in range(10)]), c,
        g=s.rad(c, 50, 42, 62))
    s.gloss(50, 44, 6, 3.6, -35)
    s.face(64, 67, gap=18, eye=3.2)


def cloud(s):
    s.shadow(rx=36, cy=112)
    c, L = "#f2f7fd", "#88a6c6"
    s.blob([("circle", dict(cx=42, cy=72, r=18)), ("circle", dict(cx=63, cy=56, r=24)),
            ("circle", dict(cx=87, cy=68, r=19)), ("rect", dict(x=24, y=66, width=82, height=28, rx=14))],
           c, g=s.rad(c, 48, 44, 72, 0.7, 0.88), line=L)
    s.gloss(52, 46, 7, 4, -30, 0.9)
    s.face(64, 76, gap=20, eye=3.3)


def night(s):
    s.shadow(rx=32)
    sky = "#4a56a6"
    cl = s.clip('<circle cx="64" cy="62" r="46"/>')
    s.C(64, 62, 46, sky, g=s.lin("#323d82", "#7d69b9", 0, 16, 0, 108))
    s.group(clip_path=cl)
    s.P(crescent((82, 40), 13, (89, 34), 11), "#ffe27a")
    for (x, y, r) in [(40, 38, 6), (58, 56, 4), (100, 62, 5), (30, 64, 3.5)]:
        s.P(spark_d(x, y, r), "#fff3b0", noline=True)
    for (x, y) in [(70, 24), (48, 22), (86, 70), (22, 50)]:
        s.C(x, y, 1.6, "#fff3b0", noline=True)
    s.P("M 6 96 Q 40 72 72 90 Q 98 78 124 92 L 124 124 L 6 124 Z", "#3d8a76", line="#24584c")
    s.P("M 6 108 Q 44 92 84 106 Q 106 100 124 106 L 124 124 L 6 124 Z", "#4fa384", line="#24584c")
    s.end()
    if not s.paper:
        s.add(tag("circle", cx=64, cy=62, r=46, fill="none", stroke=s.ln(sky), stroke_width=W))


def tree(s):
    s.shadow(rx=30)
    s.P("M 52 113 Q 59 100 58 76 L 70 76 Q 69 100 76 113 Z", BARK, g=(52, 76, 76, 113))
    s.blob([("circle", dict(cx=64, cy=42, r=27)), ("circle", dict(cx=39, cy=58, r=20)),
            ("circle", dict(cx=89, cy=58, r=20)), ("circle", dict(cx=50, cy=76, r=17)),
            ("circle", dict(cx=78, cy=76, r=17)), ("circle", dict(cx=64, cy=66, r=22))],
           LEAF, g=(18, 14, 110, 94))
    s.stroke("M 46 32 Q 54 22 66 22", lite(LEAF, 0.55), 3.4, op=0.9)
    s.stroke("M 28 54 Q 30 46 36 42", lite(LEAF, 0.55), 3, op=0.9)
    for (x, y) in [(44, 64), (84, 50), (68, 80), (56, 40), (92, 72)]:
        s.E(x, y, 5, 6.2, "#ffb52e", g=s.rad("#ffb52e", x - 2, y - 3, 8))
        s.C(x - 1.6, y - 2.4, 1.4, "#ffffff", noline=True, op=0.75)


def palm(s):
    s.shadow(rx=40, cy=114)
    sand = "#f3d38f"
    s.P("M 20 112 Q 64 88 108 112 Z", sand, g=(20, 92, 108, 112))
    trunk = "M 58 104 C 54 84, 60 62, 72 44"
    s.tube(trunk, "#c48a54", 13)
    for t in (0.18, 0.36, 0.54, 0.72):
        p0, p1, p2, p3 = (58, 104), (54, 84), (60, 62), (72, 44)
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1]
        s.stroke("M %s %s Q %s %s %s %s" % (f(x - 4), f(y - 1), f(x), f(y + 2.5), f(x + 4), f(y - 1)), deep("#c48a54"), 2.2)
    for (E, bend, w) in [((24, 46), 6, 7), ((34, 74), -4, 6.5), ((112, 40), -6, 7), ((104, 72), 5, 6.5), ((70, 10), 4, 6)]:
        leaf(s, (71, 44), E, bend, w, "#5fb35a")
    for (x, y) in [(66, 49), (76, 48), (71, 55)]:
        s.C(x, y, 5.5, "#8a5a3a", g=True)


def mountain(s):
    s.shadow(rx=56, cy=112)
    back, front = "#b69ad0", "#8e6aa0"
    s.P("M 50 108 L 84 44 Q 88 37 92 44 L 124 108 Z", back, g=(50, 37, 124, 108))
    s.P("M 76.6 58 L 84 44 Q 88 37 92 44 L 99 58 Q 95 54 91 59 Q 87 53 83 59 Q 79.5 54 76.6 58 Z", "#ffffff", line=deep(back))
    s.P("M 4 108 L 44 32 Q 48 25 52 32 L 96 108 Z", front, g=(4, 25, 96, 108))
    s.P("M 33.5 52 L 44 32 Q 48 25 52 32 L 63.6 52 Q 59 48 54.5 54 Q 49 47 43.5 54 Q 38 48 33.5 52 Z", "#ffffff", line=deep(front))
    s.P("M 8 110 Q 34 88 64 104 Q 94 88 120 110 Z", LEAF, g=(8, 88, 120, 110))


def waves(s):
    s.shadow(rx=44, cy=114)
    for i, (y, c) in enumerate([(42, "#a6e0f4"), (66, "#5bbde0"), (90, "#2f93c4")]):
        x0, x1, amp, n = 18, 110, 7, 5
        hp = (x1 - x0) / n
        d = "M %s %s" % (f(x0), f(y))
        x = x0
        for k in range(n):
            sign = -1 if k % 2 == 0 else 1
            d += " Q %s %s %s %s" % (f(x + hp / 2), f(y + sign * 2 * amp), f(x + hp), f(y))
            x += hp
        s.tube(d, c, 15)
        s.stroke("M %s %s Q %s %s %s %s" % (f(x0 + 4), f(y - 3), f(x0 + hp / 2), f(y - 2 * amp - 2), f(x0 + hp - 2), f(y - 5)),
                 "#ffffff", 2.6, op=0.7)
        s.C(x0 + 2 * hp + hp / 2, y - amp - 3, 2.4, "#ffffff", noline=True, op=0.85)


def sparkles(s):
    s.shadow(rx=26)
    s.P(spark_d(52, 66, 40), YEL, g=s.rad(YEL, 42, 50, 50))
    s.face(52, 66, gap=13, eye=2.8, bdx=11, bdy=4)
    s.P(spark_d(98, 30, 16), "#ff9fc3")
    s.P(spark_d(100, 90, 13), SKY)
    s.C(22, 26, 3.2, YEL, noline=True)
    s.C(104, 60, 2.6, "#ff9fc3", noline=True)


def bolt(s):
    s.shadow(rx=22)
    pts = [(72, 8), (32, 64), (58, 64), (46, 110), (96, 46), (70, 46), (86, 8)]
    s.P(rounded(pts, 0.14), YEL, g=s.rad(YEL, 56, 30, 80))
    s.stroke("M 70 16 L 44 56", "#ffffff", 3.2, op=0.6)


# ---------------------------------------------------------------- food
def apple(s):
    s.shadow(rx=32, cy=116)
    s.tube("M 64 46 Q 63 32 70 22", STEM, 6)
    s.P("M 64 42 C 50 32, 20 36, 20 66 C 20 94, 42 112, 56 110 C 60 109, 62 107, 64 107 C 66 107, 68 109, 72 110 "
        "C 86 112, 108 94, 108 66 C 108 36, 78 32, 64 42 Z", RED, g=s.rad(RED, 42, 52, 72))
    leaf(s, (68, 30), (94, 22), -4, 7.5)
    s.gloss(38, 62, 5, 9, 20)
    s.face(64, 78, gap=24, eye=3.5)


def banana(s):
    s.shadow(rx=24, cy=116)
    c = "#ffd84d"
    s.tube("M 63 22 L 66 10", "#8a6a3a", 7)
    s.P("M 60 20 C 30 36, 22 84, 52 109 C 57 114, 66 112, 64 105 C 58 86, 60 50, 72 26 C 74 18, 64 16, 60 20 Z",
        c, g=s.rad(c, 40, 46, 72))
    s.C(58.5, 109.5, 3.2, "#8a6a3a", noline=True)
    s.stroke("M 52 32 C 40 50, 38 76, 48 94", "#ffffff", 3, op=0.55)
    s.face(47, 66, gap=13, eye=2.9, bdx=9.5, bdy=4.5)


def pear(s):
    s.shadow(rx=30, cy=116)
    c = "#b8d65a"
    s.tube("M 64 32 Q 64 22 68 14", STEM, 5)
    s.P("M 64 28 C 54 28, 52 42, 50 52 C 46 64, 30 70, 30 88 C 30 104, 46 112, 64 112 C 82 112, 98 104, 98 88 "
        "C 98 70, 82 64, 78 52 C 76 42, 74 28, 64 28 Z", c, g=s.rad(c, 46, 52, 72))
    leaf(s, (67, 22), (90, 14), -3, 6.5)
    s.gloss(42, 78, 4.5, 8, 20)
    s.face(64, 86, gap=22, eye=3.4)


def grapes(s):
    s.shadow(rx=30)
    c = "#9b6fc4"
    s.tube("M 64 32 Q 62 20 69 12", STEM, 5)
    leaf(s, (66, 24), (94, 16), -4, 8)
    for count, y in [(4, 40), (3, 58), (2, 76), (1, 94)]:
        for i in range(count):
            x = 64 + (i - (count - 1) / 2) * 21
            s.C(x, y, 11.5, c, g=s.rad(c, x - 4, y - 5, 15))
            s.C(x - 4, y - 4.5, 2.4, "#ffffff", noline=True, op=0.7)


def cake(s):
    s.shadow(rx=46, cy=114)
    s.E(64, 104, 50, 9, "#eaf3fb", line="#93abc4")
    sponge, icing = "#ffe2ae", "#ff9fc0"
    s.P("M 24 60 L 24 94 Q 24 106 64 106 Q 104 106 104 94 L 104 60 Z", sponge, g=(24, 50, 104, 106))
    # icing: the top, and drips down the front
    drips = [(31, 9, 5), (47, 15, 6), (66, 7, 5), (84, 13, 6), (98, 6, 4)]
    pts = []
    for i in range(41):
        x = 104 - i * 2
        y = 60 + 11 * math.sqrt(max(0, 1 - ((x - 64) / 40) ** 2))
        for xc, L, hw in drips:
            if abs(x - xc) < hw:
                y += L * math.sqrt(1 - ((x - xc) / hw) ** 2) + 0
        pts.append((x, y))
    d = "M 24 60 A 40 11 0 0 1 104 60 " + " ".join("L " + pt(p) for p in pts) + " Z"
    s.P(d, icing, g=(24, 49, 104, 80))
    for (x, y, a, c) in [(50, 58, 20, "#5bbde0"), (78, 56, -30, YEL), (64, 64, 60, "#7cc35a"), (40, 63, -10, "#ffffff"),
                         (88, 63, 30, "#b98ad8")]:
        r = math.radians(a)
        s.stroke("M %s %s L %s %s" % (f(x - 2.6 * math.cos(r)), f(y - 2.6 * math.sin(r)),
                                      f(x + 2.6 * math.cos(r)), f(y + 2.6 * math.sin(r))), c, 2.6)
    s.R(60, 30, 8, 24, "#8fd3f2", rx=2.5)
    s.stroke("M 61 38 L 67 34 M 61 46 L 67 42", "#ffffff", 2.2, op=0.9)
    s.P("M 64 13 Q 71 21 69 26 Q 64 31 59 26 Q 57 21 64 13 Z", "#ffb52e")
    s.P("M 64 19 Q 67 23 66 25 Q 64 27 62 25 Q 61 23 64 19 Z", "#fff0a8", noline=True)
    s.face(64, 88, gap=22, eye=3.3)


# ---------------------------------------------------------------- animals
def sit(s, c, belly=None, cx=64, cy=94, rx=23, ry=18, paw=None):
    s.E(cx, cy, rx, ry, c, g=True)
    if belly:
        s.E(cx, cy + 4, rx * 0.52, ry * 0.62, belly, noline=True)
    pc = paw or belly or c
    s.E(cx - 10, cy + 16, 8, 5.5, pc, line=deep(c) if s.mode != "ink" else None)
    s.E(cx + 10, cy + 16, 8, 5.5, pc, line=deep(c) if s.mode != "ink" else None)


def whiskers(s, x, y, spread=26):
    for sx in (-1, 1):
        s.stroke("M %s %s L %s %s" % (f(x + sx * spread * 0.62), f(y - 2), f(x + sx * spread), f(y - 4)), INK, 1.7, op=0.5)
        s.stroke("M %s %s L %s %s" % (f(x + sx * spread * 0.62), f(y + 2), f(x + sx * spread), f(y + 3)), INK, 1.7, op=0.5)


def cat(s):
    s.shadow(rx=32)
    c, cream = "#f6a54c", "#fff1db"
    s.tube("M 82 104 C 108 106, 114 82, 104 70", c, 10)
    sit(s, c, cream)
    s.P("M 36 46 L 37 17 Q 38 11 44 14 L 62 30 Z", c)
    s.P("M 92 46 L 91 17 Q 90 11 84 14 L 66 30 Z", c)
    s.P("M 41 37 L 41.5 23 Q 42 20 45 22 L 54 30 Z", EAR_PINK, noline=True)
    s.P("M 87 37 L 86.5 23 Q 86 20 83 22 L 74 30 Z", EAR_PINK, noline=True)
    s.E(64, 52, 32, 27, c, g=True)
    for (x0, x1) in [(64, 64), (56, 57.5), (72, 70.5)]:
        s.stroke("M %s 27 L %s 34" % (f(x0), f(x1)), shade(c, 0.78), 3.4)
    s.face(64, 54, gap=24, eye=3.6, mouth="w", nose="#ff8fa3")
    whiskers(s, 64, 62, 34)


def dog(s):
    s.shadow(rx=32)
    c, ear, cream = "#e3aa6c", "#a8693f", "#fff1db"
    s.tube("M 84 100 C 98 98, 104 88, 101 76", c, 9)
    sit(s, c, cream)
    s.E(64, 52, 31, 27, c, g=True)
    s.E(77, 46, 9.5, 8.5, "#c98a55", noline=True)
    s.P("M 40 30 C 25 30, 19 52, 25 66 C 29 74, 40 70, 42 58 Z", ear, g=(19, 30, 42, 74))
    s.P("M 88 30 C 103 30, 109 52, 103 66 C 99 74, 88 70, 86 58 Z", ear, g=(86, 30, 109, 74))
    s.E(64, 64, 14, 10, cream, noline=True)
    s.eye(52, 48, 3.6)
    s.eye(76, 48, 3.6)
    s.E(64, 58.5, 5, 3.6, INK)
    s.C(62.5, 57.5, 1.2, "#ffffff", noline=True)
    s.P("M 61 65 Q 64 74 67 65 Z", "#ff8fa3", line="#c2475a", sw=1.6)
    s.mouth(64, 63, 4.4, "w", 2.2)
    s.blush(42, 60, 3.4)
    s.blush(86, 60, 3.4)
    s.tube("M 46 75 Q 64 83 82 75", "#ef5b4f", 6)
    s.C(64, 81, 4, GOLD)


def bear(s):
    s.shadow(rx=32)
    c, light = "#b98157", "#f1d4b0"
    for x in (38, 90):
        s.C(x, 30, 12, c, g=True)
        s.C(x, 30, 6, light, noline=True)
    sit(s, c, light)
    s.E(64, 54, 32, 28, c, g=True)
    s.E(64, 66, 14, 10, light, noline=True)
    s.E(64, 61, 5, 3.6, INK)
    s.C(62.5, 60, 1.2, "#ffffff", noline=True)
    s.mouth(64, 66, 4.2, "w", 2.2)
    s.eye(51, 52, 3.6)
    s.eye(77, 52, 3.6)
    s.blush(42, 62, 3.4)
    s.blush(86, 62, 3.4)


def rabbit(s):
    s.shadow(rx=30)
    c, L = "#fbf6f2", "#b9a3ad"
    s.E(50, 28, 9, 23, c, line=L, rot=-10)
    s.E(78, 28, 9, 23, c, line=L, rot=10)
    s.E(50, 30, 4.5, 15, EAR_PINK, noline=True, rot=-10)
    s.E(78, 30, 4.5, 15, EAR_PINK, noline=True, rot=10)
    s.E(64, 98, 22, 15, c, line=L, g=s.rad(c, 56, 90, 30, 0.6, 0.9))
    s.E(52, 111, 9, 5, c, line=L)
    s.E(76, 111, 9, 5, c, line=L)
    s.E(64, 64, 29, 25, c, line=L, g=s.rad(c, 52, 52, 40, 0.6, 0.9))
    s.face(64, 64, gap=22, eye=3.4, mouth="w", nose="#ff8fa3")
    s.R(61.5, 72.5, 5, 4.5, "#ffffff", rx=1.2, line=L, sw=1.4)


def mouse(s):
    s.shadow(rx=32)
    c = "#bfb9cc"
    s.tube("M 82 104 C 104 106, 112 90, 102 84 C 96 80, 92 88, 98 90", "#ffadc0", 4.5)
    for x in (36, 92):
        s.C(x, 34, 17, c, g=True)
        s.C(x, 35, 10, EAR_PINK, noline=True)
    sit(s, c, "#ebe7f2", paw="#ffc2d0")
    s.E(64, 58, 27, 24, c, g=True)
    s.face(64, 58, gap=20, eye=3.4, mouth="w", nose="#ff8fa3")
    whiskers(s, 64, 66, 30)


def fox(s):
    s.shadow(rx=34)
    c, white, dark = "#f3873f", "#fff6ec", "#5a3d3a"
    tail = "M 82 92 C 96 92, 102 80, 104 58 C 120 70, 120 100, 96 106 C 90 107, 84 104, 82 100 Z"
    cl = s.clip('<path d="%s"/>' % tail)
    s.P(tail, c, g=(82, 58, 118, 107))
    s.group(clip_path=cl)
    s.C(108, 60, 13, white, noline=True)
    s.end()
    s.P(tail, c, g="none")
    s.E(64, 94, 22, 18, c, g=True)
    s.E(64, 92, 11, 13, white, noline=True)
    s.E(54, 110, 7.5, 5, dark, line=deep(c) if s.mode != "ink" else None)
    s.E(74, 110, 7.5, 5, dark, line=deep(c) if s.mode != "ink" else None)
    s.P("M 36 44 L 37 13 Q 39 7 45 11 L 61 29 Z", c)
    s.P("M 92 44 L 91 13 Q 89 7 83 11 L 67 29 Z", c)
    s.P("M 41 34 L 41.5 19 Q 42.5 16 45 18 L 54 29 Z", dark, noline=True)
    s.P("M 87 34 L 86.5 19 Q 85.5 16 83 18 L 74 29 Z", dark, noline=True)
    head = ("M 64 80 C 50 80, 36 72, 30 62 C 26 56, 28 48, 32 42 C 36 30, 50 26, 64 26 C 78 26, 92 30, 96 42 "
            "C 100 48, 102 56, 98 62 C 92 72, 78 80, 64 80 Z")
    hc = s.clip('<path d="%s"/>' % head)
    s.P(head, c, g=(28, 26, 100, 80))
    s.group(clip_path=hc)
    s.P("M 24 56 C 40 62, 52 60, 64 68 C 76 60, 88 62, 104 56 L 104 90 L 24 90 Z", white, noline=True)
    s.end()
    s.P(head, c, g="none")
    s.E(64, 68, 4.6, 3.4, INK)
    s.eye(52, 52, 3.6)
    s.eye(76, 52, 3.6)
    s.mouth(64, 72.5, 3.6, "w", 2)
    s.blush(41, 63, 3.3)
    s.blush(87, 63, 3.3)


def raccoon(s):
    s.shadow(rx=34)
    c, cream, mask, pink = "#9d97aa", "#fbf3e4", "#5d556a", "#eab3a3"
    s.tube("M 84 102 C 106 104, 114 86, 106 68", c, 13, dash="6 6", dashc=mask)
    sit(s, c, cream, paw=mask)
    s.P("M 34 42 L 38 18 Q 40 12 46 16 L 60 30 Z", c)
    s.P("M 94 42 L 90 18 Q 88 12 82 16 L 68 30 Z", c)
    s.P("M 40 34 L 42 23 Q 43 20 46 22 L 53 30 Z", pink, noline=True)
    s.P("M 88 34 L 86 23 Q 85 20 82 22 L 75 30 Z", pink, noline=True)
    s.E(64, 54, 32, 27, c, g=True)
    s.E(50, 39, 9, 4, cream, noline=True, rot=-8)
    s.E(78, 39, 9, 4, cream, noline=True, rot=8)
    s.P("M 32 54 C 35 42, 54 42, 60 51 Q 64 55 68 51 C 74 42, 93 42, 96 54 C 92 64, 76 64, 68 59 Q 64 57 60 59 "
        "C 52 64, 36 64, 32 54 Z", mask, noline=True)
    s.E(64, 67, 14.5, 9.5, cream, noline=True)
    for x in (49, 79):
        s.add(tag("ellipse", cx=x, cy=53, rx=3.3, ry=4.1, fill=INK))
        s.add(tag("circle", cx=x - 1, cy=51.3, r=1.6, fill="#ffffff"))
    s.E(64, 62.5, 4.6, 3.3, INK)
    s.mouth(64, 67, 3.8, "w", 2)
    s.blush(41, 66, 3.2)
    s.blush(87, 66, 3.2)


def elephant(s):
    s.shadow(rx=36)
    c = "#a7bddb"
    s.E(31, 52, 20, 23, c, g=True)
    s.E(97, 52, 20, 23, c, g=True)
    s.E(33, 53, 12, 15, "#f7c0cf", noline=True)
    s.E(95, 53, 12, 15, "#f7c0cf", noline=True)
    s.E(64, 96, 24, 16, c, g=True)
    s.E(51, 109, 9, 6.5, c)
    s.E(77, 109, 9, 6.5, c)
    for x in (48, 51, 54, 74, 77, 80):
        s.C(x, 112, 1.3, "#ffffff", noline=True, op=0.9)
    s.E(64, 50, 27, 25, c, g=True)
    s.tube("M 64 58 C 64 80, 70 90, 80 86 C 86 84, 87 78, 82 75", c, 12)
    s.E(64, 59, 8, 6, c, noline=True)
    s.face(64, 47, gap=22, eye=3.4, mouth=None, bdy=7)


def frog(s):
    s.shadow(rx=40)
    c, belly = "#7cc35a", "#d8efa4"
    s.E(38, 109, 13, 6, c)
    s.E(90, 109, 13, 6, c)
    s.blob([("ellipse", dict(cx=64, cy=80, rx=41, ry=28)), ("circle", dict(cx=42, cy=48, r=16)),
            ("circle", dict(cx=86, cy=48, r=16))], c, g=(23, 32, 105, 108))
    s.E(64, 95, 23, 12, belly, noline=True)
    for x in (42, 86):
        s.C(x, 47, 10, "#ffffff", noline=True)
        s.C(x + 1, 48, 5.6, INK, noline=True)
        s.C(x - 0.8, 45.6, 2, "#ffffff", noline=True)
    s.stroke("M 46 76 Q 64 90 82 76", INK, 2.6)
    s.blush(34, 72, 4.4)
    s.blush(94, 72, 4.4)
    for (x, y, r) in [(30, 86, 3.2), (98, 86, 3.2), (64, 60, 2.6)]:
        s.C(x, y, r, shade(c, 0.8), noline=True)


def fish(s):
    s.shadow(rx=40, cy=114)
    c, fin, belly = "#4cb8d8", "#2f95bf", "#e2f6fb"
    s.P("M 92 64 L 114 45 Q 121 41 120 49 L 113 64 L 120 79 Q 121 87 114 83 Z", fin)
    s.P("M 50 38 Q 62 17 82 30 L 80 40 Z", fin)
    s.P("M 58 88 Q 62 104 76 99 L 74 88 Z", fin)
    body = "M 18 64 C 18 44, 42 34, 62 34 C 84 34, 98 50, 100 64 C 98 78, 84 94, 62 94 C 42 94, 18 84, 18 64 Z"
    cl = s.clip('<path d="%s"/>' % body)
    s.P(body, c, g=(18, 34, 100, 94))
    s.group(clip_path=cl)
    s.E(56, 88, 40, 16, belly, noline=True)
    s.end()
    s.P(body, c, g="none")
    s.stroke("M 70 42 Q 79 64 70 86", shade(c, 0.78), 3.2)
    s.stroke("M 82 45 Q 90 64 82 83", shade(c, 0.78), 3.2)
    s.stroke("M 50 46 Q 56 64 50 82", s.ln(c), 2.6)
    s.eye(36, 58, 4.4)
    s.mouth(25, 69, 4, "smile", 2.2)
    s.blush(38, 71, 3.3)
    s.gloss(36, 44, 6, 3, -20, 0.5)
    s.C(10, 40, 4.2, "#dff4fb", line="#7fc3dc", sw=2)
    s.C(16, 27, 2.8, "#dff4fb", line="#7fc3dc", sw=1.8)


def bee(s):
    s.shadow(rx=34)
    c, band = "#ffd23f", "#4b3a44"
    s.E(54, 33, 12, 18, "#e8f7ff", line="#86b5d2", rot=-22, op=0.95)
    s.E(76, 31, 12, 18, "#e8f7ff", line="#86b5d2", rot=20, op=0.95)
    s.stroke("M 40 48 Q 34 34 27 31", band, 2.8)
    s.stroke("M 50 44 Q 50 30 45 22", band, 2.8)
    s.C(26, 30, 4, band, noline=True)
    s.C(45, 21, 4, band, noline=True)
    s.P("M 96 64 L 110 69 L 96 75 Z", band, line=band)
    body = '<ellipse cx="64" cy="70" rx="34" ry="27"/>'
    cl = s.clip(body)
    s.E(64, 70, 34, 27, c, g=True)
    s.group(clip_path=cl)
    s.stroke("M 72 40 Q 80 70 72 100", band, 9, cap="butt")
    s.stroke("M 89 40 Q 97 70 89 100", band, 9, cap="butt")
    s.end()
    s.E(64, 70, 34, 27, c, g="none")
    s.gloss(44, 52, 6, 3.6, -25)
    s.face(47, 70, gap=18, eye=3.3, bdx=12, bdy=5)


def ant(s):
    s.shadow(rx=38)
    c = "#d0603f"
    leg = deep(c)
    for d in ["M 56 72 Q 46 82 40 104", "M 62 74 Q 60 90 58 106", "M 68 72 Q 78 86 80 104",
              "M 58 70 Q 50 66 46 70"]:
        s.stroke(d, leg, 3.6)
    s.E(91, 72, 23, 19, c, g=True)
    s.E(63, 72, 11, 9.5, c, g=True)
    s.stroke("M 28 44 Q 22 30 14 28", leg, 2.8)
    s.stroke("M 42 42 Q 46 28 54 22", leg, 2.8)
    s.C(13, 28, 4, c)
    s.C(55, 21, 4, c)
    s.C(36, 58, 18, c, g=True)
    s.gloss(84, 62, 7, 4, -25, 0.5)
    s.face(36, 59, gap=14, eye=3.1, bdx=11, bdy=5)


def butterfly(s):
    s.shadow(rx=30, cy=116)
    up, low, body = LIL, "#ff9fc3", PLUM
    s.stroke("M 60 42 Q 52 24 43 22", body, 2.8)
    s.stroke("M 68 42 Q 76 24 85 22", body, 2.8)
    s.C(42, 21, 3.6, body, noline=True)
    s.C(86, 21, 3.6, body, noline=True)
    s.P("M 62 68 C 42 70, 26 86, 34 99 C 42 111, 60 96, 62 76 Z", low, g=(26, 66, 62, 108))
    s.P("M 66 68 C 86 70, 102 86, 94 99 C 86 111, 68 96, 66 76 Z", low, g=(66, 66, 102, 108))
    s.P("M 62 58 C 46 22, 10 22, 13 47 C 15 68, 42 72, 62 66 Z", up, g=(12, 24, 62, 72))
    s.P("M 66 58 C 82 22, 118 22, 115 47 C 113 68, 86 72, 66 66 Z", up, g=(66, 24, 116, 72))
    for (x, y, r, c) in [(34, 44, 7.5, lite(up, 0.6)), (94, 44, 7.5, lite(up, 0.6)), (44, 90, 5, "#fff3b0"),
                         (84, 90, 5, "#fff3b0"), (24, 56, 3.5, "#ffffff"), (104, 56, 3.5, "#ffffff")]:
        s.C(x, y, r, c, noline=True)
    s.E(64, 76, 7, 22, body, g=True)
    s.C(64, 50, 11.5, "#c9a6e0", g=True)
    s.face(64, 50, gap=9, eye=2.4, mw=2.6, bdx=7, bdy=4)


def snake(s):
    s.shadow(rx=40)
    c, spot = "#6cc06a", "#c3e886"
    body = "M 30 104 L 90 104 C 108 104, 108 82, 90 82 L 44 82 C 26 82, 26 62, 44 62 L 64 62 C 76 62, 80 54, 78 44"
    s.tube(body, c, 16, dash="3 10", dashc=spot)
    s.E(70, 36, 21, 17, c, g=True)
    s.stroke("M 70 51 L 70 59 M 70 59 L 66 63 M 70 59 L 74 63", "#ff6f7f", 2.6)
    s.face(70, 35, gap=18, eye=3.3, bdx=13, bdy=5)


def hen(s):
    s.shadow(rx=36)
    c, L, comb, beak = "#fff7ec", "#c4a48a", "#ef5b4f", "#ffb52e"
    s.stroke("M 58 100 L 56 112 M 56 112 L 50 114 M 56 112 L 60 115", "#f39a2f", 3.4)
    s.stroke("M 74 100 L 76 112 M 76 112 L 70 114 M 76 112 L 81 115", "#f39a2f", 3.4)
    s.blob([("circle", dict(cx=40, cy=46, r=7)), ("circle", dict(cx=48.5, cy=40.5, r=7.5)),
            ("circle", dict(cx=57, cy=42, r=6.5))], comb)
    s.blob([("ellipse", dict(cx=66, cy=72, rx=36, ry=30)), ("circle", dict(cx=97, cy=50, r=12)),
            ("circle", dict(cx=103, cy=63, r=10))], c, g=s.rad(c, 50, 54, 60, 0.6, 0.88), line=L)
    s.P("M 31 70 Q 27 82 33 82 Q 38 80 35 70 Z", comb)
    s.P("M 31 58 L 16 64 L 31 70 Z", beak)
    s.E(76, 80, 17, 11, "#f6e6cf", line=L, rot=-14)
    s.stroke("M 66 82 Q 74 88 84 84", L, 2)
    s.eye(42, 56, 3.6)
    s.blush(46, 66, 3.3)


def goat(s):
    s.shadow(rx=32)
    c, L, horn, pink = "#f8f2ea", "#b3a08c", "#d9c3a0", "#f6c9c0"
    s.tube("M 54 34 C 50 21, 40 16, 33 20", horn, 8)
    s.tube("M 74 34 C 78 21, 88 16, 95 20", horn, 8)
    s.E(34, 48, 15, 6.5, c, line=L, rot=22)
    s.E(94, 48, 15, 6.5, c, line=L, rot=-22)
    s.E(35, 48.5, 9, 3.2, EAR_PINK, noline=True, rot=22)
    s.E(93, 48.5, 9, 3.2, EAR_PINK, noline=True, rot=-22)
    s.E(64, 98, 22, 14, c, line=L, g=s.rad(c, 56, 90, 30, 0.6, 0.9))
    s.E(54, 110, 7, 4.5, "#7a6a6a", line=L)
    s.E(74, 110, 7, 4.5, "#7a6a6a", line=L)
    s.P("M 57 78 Q 64 98 71 78 Z", c, line=L)
    s.E(64, 56, 25, 27, c, line=L, g=s.rad(c, 54, 44, 40, 0.6, 0.9))
    s.P("M 57 31 Q 64 22 71 31 Q 64 29 57 31 Z", c, line=L)
    s.E(64, 70, 13, 9, pink, noline=True)
    s.C(60, 68.5, 1.4, INK, noline=True)
    s.C(68, 68.5, 1.4, INK, noline=True)
    s.mouth(64, 73.5, 3.2, "smile", 2)
    s.face(64, 52, gap=20, eye=3.3, mouth=None, bdx=15, bdy=8)


# ---------------------------------------------------------------- things
def book(s):
    s.shadow(rx=38)
    cover, pages = BLU, "#fff7e3"
    s.R(76, 26, 26, 80, pages, rx=7)
    for y in range(36, 100, 8):
        s.stroke("M 92 %d L 99 %d" % (y, y), "#dccaa4", 2)
    s.R(26, 20, 64, 88, cover, rx=9, g=True)
    s.stroke("M 39 24 L 39 104", s.ln(cover), 2.6)
    s.R(48, 34, 34, 18, pages, rx=5)
    s.stroke("M 54 41 L 76 41 M 54 46 L 70 46", "#c9b893", 2.2)
    small_star(s, 65, 78, 15, 7)
    s.P("M 70 104 L 70 120 L 75 115 L 80 120 L 80 104 Z", RED)
    s.stroke("M 31 28 L 31 60", "#ffffff", 3, op=0.5)


def stories(s):
    s.shadow(rx=46)
    cover, page = BLU, "#fffaf0"
    s.P("M 64 66 C 50 58, 30 58, 10 64 L 10 108 C 30 102, 50 102, 64 110 C 78 102, 98 102, 118 108 L 118 64 "
        "C 98 58, 78 58, 64 66 Z", cover, g=(10, 58, 118, 110))
    s.P("M 64 62 C 52 54, 34 54, 16 60 L 16 102 C 34 96, 52 98, 64 106 Z", page, line="#a8987e")
    s.P("M 64 62 C 76 54, 94 54, 112 60 L 112 102 C 94 96, 76 98, 64 106 Z", page, line="#a8987e")
    for dy in (0, 10, 20):
        s.stroke("M 24 %s C 34 %s, 46 %s, 56 %s" % (f(70 + dy), f(66 + dy), f(66 + dy), f(71 + dy)), "#d8cdb8", 2.4)
        s.stroke("M 72 %s C 82 %s, 94 %s, 104 %s" % (f(71 + dy), f(66 + dy), f(66 + dy), f(70 + dy)), "#d8cdb8", 2.4)
    s.stroke("M 64 50 L 64 44", "#ffd23f", 2.6, op=0.8)
    small_star(s, 64, 30, 18, 8.5)
    s.face(64, 32, gap=10, eye=2.3, mw=2.6, bdx=7.5, bdy=3)
    s.P(spark_d(34, 34, 8), "#ff9fc3")
    s.P(spark_d(96, 28, 7), SKY)
    s.C(44, 50, 2, YEL, noline=True)
    s.C(86, 48, 2, YEL, noline=True)


def pencil(s):
    s.shadow(rx=38, cy=112)
    s.group(transform="rotate(-38 62 66)")
    s.P("M 33 54 L 10 66 L 33 78 Z", "#f6d6a6")
    s.P("M 17.5 62 L 10 66 L 17.5 70 Z", "#4b3a44", noline=True)
    s.R(30, 54, 60, 24, "#ffc93c", rx=3, g=s.lin(lite("#ffc93c", 0.4), shade("#ffc93c", 0.86), 0, 54, 0, 78))
    s.stroke("M 33 62 L 88 62", shade("#ffc93c", 0.8), 2.2)
    s.stroke("M 33 70 L 88 70", shade("#ffc93c", 0.8), 2.2)
    s.R(98, 54, 18, 24, "#ff9fb5", rx=8)
    s.R(88, 53, 12, 26, "#c9cfdb", rx=2)
    s.stroke("M 92 55 L 92 77 M 96 55 L 96 77", "#9aa3b5", 1.8)
    s.end()


def bag(s):
    s.shadow(rx=36)
    c, pocket = TEAL, "#ffb84d"
    strap = shade(c, 0.78)
    s.tube("M 52 30 Q 52 16 64 16 Q 76 16 76 30", strap, 7)
    s.R(20, 52, 12, 42, strap, rx=6)
    s.R(96, 52, 12, 42, strap, rx=6)
    s.R(28, 28, 72, 84, c, rx=22, g=True)
    s.P("M 28 58 L 28 50 Q 28 28 50 28 L 78 28 Q 100 28 100 50 L 100 58 Q 64 68 28 58 Z", lite(c, 0.18))
    s.R(40, 56, 8, 12, YEL, rx=2.5)
    s.R(80, 56, 8, 12, YEL, rx=2.5)
    s.R(40, 74, 48, 30, pocket, rx=12, g=True)
    s.stroke("M 47 84 L 81 84", deep(pocket), 2.4)
    s.C(78, 84, 3, "#ffffff", line=deep(pocket), sw=2)
    small_star(s, 64, 95, 6.5, 3, "#fff3b0", line=deep(pocket))


def ball(s):
    s.shadow(rx=34, cy=114)
    cl = s.clip('<circle cx="64" cy="62" r="45"/>')
    s.C(64, 62, 45, "#fffaf3", noline=not s.paper)
    s.group(clip_path=cl)
    s.P("M 64 17 Q -2 62 64 107 Q 32 62 64 17 Z", "#ff6b5a", noline=True)
    s.P("M 64 17 Q 130 62 64 107 Q 96 62 64 17 Z", "#5aa9e6", noline=True)
    s.P("M 64 17 Q 80 62 64 107 Q 48 62 64 17 Z", YEL, noline=True)
    if not s.paper:
        i = s.nid()
        s.defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="48" cy="40" r="66">'
                      '<stop offset="0" stop-color="#ffffff" stop-opacity="0.5"/>'
                      '<stop offset="0.45" stop-color="#ffffff" stop-opacity="0"/>'
                      '<stop offset="1" stop-color="#3b2d3a" stop-opacity="0.22"/></radialGradient>' % i)
        s.C(64, 62, 45, "#000000", g="url(#%s)" % i, noline=True)
    s.end()
    if not s.paper:
        s.add(tag("circle", cx=64, cy=62, r=45, fill="none", stroke=s.ln("#c75a63"), stroke_width=W))
    s.E(64, 22, 6, 3.4, "#ffffff", line=s.ln("#c75a63"), sw=2)
    s.gloss(44, 40, 7, 4.5, -40, 0.75)


def boat(s):
    s.stroke("M 64 82 L 64 16", "#8a5a3a", 4.5)
    s.P("M 64 15 L 79 20 L 64 25 Z", RED)
    s.P("M 68 22 Q 98 44 104 74 L 68 74 Z", "#fffaf0", line="#a89a92", g=(68, 22, 104, 74))
    s.P("M 60 30 Q 40 50 30 74 L 60 74 Z", YEL, g=(30, 30, 60, 74))
    hull = "M 16 80 L 112 80 Q 108 102 86 104 L 42 104 Q 20 102 16 80 Z"
    cl = s.clip('<path d="%s"/>' % hull)
    s.P(hull, "#f47c5a", g=(16, 80, 112, 104))
    s.group(clip_path=cl)
    s.R(10, 84, 110, 6, "#ffffff", noline=True)
    s.end()
    s.P(hull, "#f47c5a", g="none")
    d = "M 8 106"
    for k in range(8):
        d += " Q %s %s %s 106" % (f(8 + k * 14 + 7), f(99 if k % 2 == 0 else 113), f(8 + (k + 1) * 14))
    d += " L 120 116 Q 64 122 8 116 Z"
    s.P(d, "#8fd3f2", g=s.lin("#a6e0f4", "#5bbde0", 0, 100, 0, 120))


def bus(s):
    s.shadow(rx=52, cy=112)
    c = "#ffc83a"
    s.R(10, 30, 108, 66, c, rx=16, g=True)
    for x in (20, 42, 64):
        s.R(x, 40, 18, 20, GLASS, rx=5, line=deep(BLU) if s.mode != "ink" else None, sw=2.6)
    s.P("M 90 40 L 106 40 Q 112 40 112 46 L 112 62 L 90 62 Z", GLASS, line=deep(BLU) if s.mode != "ink" else None, sw=2.6)
    s.stroke("M 14 72 L 114 72", "#f08a3c", 5, cap="butt")
    s.C(110, 82, 4, "#fff3b0", sw=2.4)
    s.R(102, 88, 16, 6, "#b9bccb", rx=3, sw=2.4)
    for x in (34, 92):
        s.C(x, 96, 12.5, "#4a3f4a", line=INK)
        s.C(x, 96, 5, "#c9cfdb", noline=True)
    s.stroke("M 16 36 L 60 36", "#ffffff", 3, op=0.5)


def car(s):
    s.shadow(rx=48, cy=110)
    c = "#f2675a"
    s.P("M 34 64 L 44 38 Q 47 32 54 32 L 80 32 Q 86 32 90 38 L 102 64 Z", c, g=(34, 32, 102, 64))
    gl = deep(BLU) if s.mode != "ink" else None
    s.P("M 44 60 L 50 42 Q 51 39 55 39 L 64 39 L 64 60 Z", GLASS, line=gl, sw=2.4)
    s.P("M 70 39 L 79 39 Q 83 39 85 42 L 93 60 L 70 60 Z", GLASS, line=gl, sw=2.4)
    s.R(12, 58, 104, 32, c, rx=14, g=True)
    s.stroke("M 67 62 L 67 86", s.ln(c), 2.2)
    s.stroke("M 72 68 L 78 68", s.ln(c), 2.6)
    s.E(110, 68, 4, 3.4, "#fff3b0", sw=2.2)
    s.E(18, 68, 3, 3.4, "#ffb84d", sw=2.2)
    for x in (38, 90):
        s.C(x, 90, 12.5, "#4a3f4a", line=INK)
        s.C(x, 90, 5, "#c9cfdb", noline=True)
    s.stroke("M 18 64 L 50 64", "#ffffff", 3, op=0.45)


def house(s):
    s.shadow(rx=46)
    s.R(80, 24, 13, 26, "#c96b4a", rx=2.5)
    s.R(28, 56, 72, 54, "#fff0d4", rx=5, g=True)
    s.P("M 16 62 L 64 21 L 112 62 Z", "#f0744a", g=(16, 21, 112, 62))
    s.C(64, 46, 6.5, GLASS, sw=2.6)
    s.P("M 55 110 L 55 87 Q 55 78 64 78 Q 73 78 73 87 L 73 110 Z", "#b9784a")
    s.C(68.5, 96, 1.9, YEL, noline=True)
    for x in (34, 78):
        s.R(x, 70, 16, 16, GLASS, rx=3, sw=2.8)
        s.stroke("M %d 78 L %d 78 M %d 71 L %d 85" % (x + 1, x + 15, x + 8, x + 8), s.ln(GLASS), 2)
    s.blob([("circle", dict(cx=22, cy=106, r=8)), ("circle", dict(cx=31, cy=101, r=9.5)),
            ("circle", dict(cx=40, cy=107, r=7))], LEAF, g=(13, 92, 47, 114))


def hut(s):
    s.shadow(rx=46)
    post, bamboo, wall, roof = "#a8743f", "#e3bf78", "#f0d491", "#c9953f"
    for (x, y1) in [(54, 110), (74, 110)]:
        s.stroke("M %d 84 L %d %d" % (x, x, y1), shade(post, 0.85), 6, cap="butt")
    for x in (32, 96):
        s.tube("M %d 84 L %d 112" % (x, x), post, 7)
    s.R(24, 80, 80, 8, bamboo, rx=3)
    s.R(32, 56, 64, 26, wall, rx=2, g=True)
    for x in range(40, 96, 8):
        s.stroke("M %d 58 L %d 80" % (x, x), shade(wall, 0.84), 1.8)
    s.R(40, 62, 16, 12, "#7a4f2e", rx=2, sw=2.6)
    s.R(68, 60, 16, 22, "#7a4f2e", rx=2, sw=2.6)
    s.P("M 10 62 Q 34 42 50 16 L 78 16 Q 94 42 118 62 Q 64 70 10 62 Z", roof, g=(10, 16, 118, 66))
    for (a, b) in [((54, 20), (34, 60)), ((60, 20), (52, 63)), ((68, 20), (76, 63)), ((74, 20), (94, 60)),
                   ((48, 24), (20, 60)), ((80, 24), (108, 60))]:
        s.stroke("M %s Q %s %s" % (pt(a), pt(((a[0] + b[0]) / 2 + 2, (a[1] + b[1]) / 2)), pt(b)), shade(roof, 0.78), 2)
    s.tube("M 48 16 L 80 16", post, 6)
    s.stroke("M 70 88 L 66 112 M 82 88 L 86 112 M 68 96 L 83 96 M 67 104 L 85 104", post, 3)


def box(s):
    s.shadow(rx=42)
    k = "#e0ad6c"
    s.P("M 22 56 L 70 66 L 70 110 L 22 100 Z", k, g=(22, 56, 70, 110))
    s.P("M 70 66 L 106 54 L 106 98 L 70 110 Z", shade(k, 0.84))
    s.P("M 22 56 L 58 46 L 106 54 L 70 66 Z", lite(k, 0.22))
    s.P("M 37 52 L 85 61 L 91 59 L 43 50 Z", "#f6e3b8", line=deep(k) if s.mode != "ink" else None, sw=1.8)
    s.P("M 85 61 L 91 59 L 91 103 L 85 105 Z", "#f6e3b8", line=deep(k) if s.mode != "ink" else None, sw=1.8)
    s.P("M 46 92 C 36 84, 36 76, 41 75 C 44 74, 46 77, 46 79 C 46 77, 48 74, 51 75 C 56 77, 56 85, 46 92 Z", "#ff6f86", sw=2.2)


def chest(s):
    s.shadow(rx=46)
    wood, gold = "#c07a48", GOLD
    shape = "M 20 108 L 20 50 Q 20 28 64 28 Q 108 28 108 50 L 108 108 Z"
    cl = s.clip('<path d="%s"/>' % shape)
    s.R(20, 62, 88, 46, wood, rx=6, g=True)
    s.P("M 20 64 L 20 50 Q 20 28 64 28 Q 108 28 108 50 L 108 64 Z", lite(wood, 0.12), g=(20, 28, 108, 64))
    s.stroke("M 22 80 L 106 80 M 22 95 L 106 95", shade(wood, 0.78), 2.2)
    s.group(clip_path=cl)
    for x in (32, 86):
        s.R(x, 20, 10, 92, gold, line=deep(gold) if s.mode != "ink" else None, sw=2.6)
    s.end()
    s.R(20, 62, 88, 46, wood, rx=6, g="none")
    s.P("M 20 64 L 20 50 Q 20 28 64 28 Q 108 28 108 50 L 108 64 Z", wood, g="none")
    s.R(54, 54, 20, 22, gold, rx=4, g=True)
    s.C(64, 62, 3.2, "#4b3a44", noline=True)
    s.P("M 62.6 63 L 61.6 70 L 66.4 70 L 65.4 63 Z", "#4b3a44", noline=True)
    s.stroke("M 28 40 Q 40 32 56 32", "#ffffff", 3, op=0.4)


def chest_open(s):
    s.shadow(rx=46)
    wood, gold = "#c07a48", GOLD
    s.P("M 22 60 L 28 22 Q 64 10 100 22 L 106 60 Z", "#7a4a33", g=s.lin("#6a3d2a", "#94603f", 0, 14, 0, 60))
    s.stroke("M 30 26 Q 64 15 98 26", gold, 4)
    s.blob([("circle", dict(cx=34, cy=60, r=10)), ("circle", dict(cx=49, cy=53, r=12)),
            ("circle", dict(cx=66, cy=49, r=13)), ("circle", dict(cx=82, cy=53, r=12)),
            ("circle", dict(cx=95, cy=60, r=10)), ("rect", dict(x=24, y=56, width=80, height=12))], gold,
           g=(24, 36, 104, 70))
    for (x, y) in [(46, 54), (62, 48), (80, 54), (36, 61), (92, 61)]:
        s.add(tag("ellipse", cx=x, cy=y, rx=6, ry=2.6, fill="none", stroke=deep(gold), stroke_width=1.8))
    s.P("M 58 34 L 65 42 L 58 50 L 51 42 Z", "#ff6f86", g=(51, 34, 65, 50))
    s.C(78, 42, 5, "#6cc6f0", g=True)
    shape = "M 20 108 L 20 62 L 108 62 L 108 108 Z"
    cl = s.clip('<path d="%s"/>' % shape)
    s.R(20, 62, 88, 46, wood, rx=6, g=True)
    s.stroke("M 22 80 L 106 80 M 22 95 L 106 95", shade(wood, 0.78), 2.2)
    s.group(clip_path=cl)
    for x in (32, 86):
        s.R(x, 58, 10, 54, gold, line=deep(gold) if s.mode != "ink" else None, sw=2.6)
    s.end()
    s.R(20, 62, 88, 46, wood, rx=6, g="none")
    s.R(54, 64, 20, 18, gold, rx=4, g=True)
    s.C(64, 71, 3, "#4b3a44", noline=True)
    for (x, y, r) in [(30, 30, 7), (100, 34, 6), (64, 18, 5)]:
        s.P(spark_d(x, y, r), "#fff3b0")


def coins(s):
    s.shadow(rx=44)
    gold = GOLD
    side = shade(gold, 0.78)
    L = s.ln(gold)
    for y in (94, 84, 74, 64):
        cx = 44
        if s.paper:
            s.E(cx, y + 8, 22, 7, side)
            s.R(cx - 22, y, 44, 8, side, noline=True)
            s.E(cx, y, 22, 7, lite(gold, 0.15), noline=True)
        else:
            s.add(tag("ellipse", cx=cx, cy=y + 8, rx=22, ry=7, fill=side, stroke=L, stroke_width=W))
            s.add(tag("rect", x=cx - 22, y=y, width=44, height=8, fill=side))
            s.stroke("M %s %s L %s %s M %s %s L %s %s" % (f(cx - 22), f(y), f(cx - 22), f(y + 8), f(cx + 22), f(y), f(cx + 22), f(y + 8)), L, W)
            s.add(tag("ellipse", cx=cx, cy=y, rx=22, ry=7, fill=lite(gold, 0.15), stroke=L, stroke_width=W))
        s.add(tag("ellipse", cx=cx, cy=y, rx=14, ry=4, fill="none", stroke=shade(gold, 0.8), stroke_width=1.8))
    s.C(84, 80, 27, gold, g=True)
    s.C(84, 80, 20, gold, g="none", line=shade(gold, 0.78), sw=2.4)
    small_star(s, 84, 80, 12, 5.5, lite(gold, 0.45))
    s.gloss(72, 66, 5, 3, -40, 0.75)
    s.P(spark_d(106, 44, 7), "#fff3b0")


def crown(s):
    s.shadow(rx=46)
    gold = GOLD
    s.P("M 22 96 L 16 46 L 42 68 L 64 30 L 86 68 L 112 46 L 106 96 Z", gold, g=(16, 30, 112, 96))
    s.R(20, 84, 88, 16, shade(gold, 0.9), rx=5)
    for (x, y, r) in [(16, 44, 6), (64, 27, 6.5), (112, 44, 6)]:
        s.C(x, y, r, gold, g=True)
    s.C(64, 92, 5.5, "#ff6f86", g=True, sw=2.6)
    s.C(40, 92, 4.2, "#6cc6f0", g=True, sw=2.4)
    s.C(88, 92, 4.2, "#6cc6f0", g=True, sw=2.4)
    s.E(64, 60, 5, 6.5, "#7ad19a", g=True, sw=2.4)
    s.stroke("M 26 80 L 23 56", "#ffffff", 3, op=0.55)


def gift(s):
    s.shadow(rx=42)
    box_c, rib = LIL, YEL
    s.P("M 64 44 C 50 22, 30 26, 36 40 C 40 48, 56 47, 64 44 Z", rib, g=(32, 26, 64, 48))
    s.P("M 64 44 C 78 22, 98 26, 92 40 C 88 48, 72 47, 64 44 Z", rib, g=(64, 26, 96, 48))
    s.R(26, 58, 76, 52, box_c, rx=7, g=True)
    for (x, y) in [(38, 74), (44, 96), (88, 72), (92, 96)]:
        s.C(x, y, 4, lite(box_c, 0.45), noline=True)
    s.R(20, 44, 88, 18, lite(box_c, 0.12), rx=7, g=True)
    s.R(57, 44, 14, 66, rib, g=(57, 44, 71, 110))
    s.E(64, 44, 8, 6.5, rib, g=True)


def trophy(s):
    s.shadow(rx=36)
    gold, wood = GOLD, "#a8693f"
    s.tube("M 38 34 C 16 32, 16 62, 44 62", gold, 7)
    s.tube("M 90 34 C 112 32, 112 62, 84 62", gold, 7)
    s.P("M 58 76 L 70 76 L 73 90 L 55 90 Z", shade(gold, 0.86))
    s.P("M 34 22 L 94 22 L 94 38 Q 94 74 64 78 Q 34 74 34 38 Z", gold, g=(34, 22, 94, 78))
    s.E(64, 22.5, 30, 5.5, lite(gold, 0.35))
    small_star(s, 64, 48, 13, 6, lite(gold, 0.55))
    s.R(40, 88, 48, 8, gold, rx=3)
    s.R(34, 96, 60, 15, wood, rx=4, g=True)
    s.R(52, 100, 24, 6, "#ffe9a8", rx=2, sw=2)
    s.stroke("M 42 32 Q 41 54 50 64", "#ffffff", 3.6, op=0.55)


def heart(s):
    s.shadow(rx=30, cy=114)
    c = "#ff6f86"
    s.P("M 64 106 C 40 90, 16 72, 16 48 C 16 32, 28 22, 42 22 C 52 22, 60 28, 64 36 C 68 28, 76 22, 86 22 "
        "C 100 22, 112 32, 112 48 C 112 72, 88 90, 64 106 Z", c, g=s.rad(c, 42, 38, 76))
    s.gloss(36, 40, 7, 4.5, -35)
    s.face(64, 60, gap=24, eye=3.6)


def bulb(s):
    s.shadow(rx=24, cy=120)
    glass = "#ffe066"
    s.P(spark_d(20, 24, 8), "#ffb52e")
    s.P(spark_d(108, 26, 7), "#ffb52e")
    s.C(16, 52, 2.6, "#ffb52e", noline=True)
    s.C(112, 54, 2.6, "#ffb52e", noline=True)
    s.R(46, 90, 36, 18, "#b9bccb", rx=5, g=True)
    s.stroke("M 47 96 L 81 96 M 47 102 L 81 102", shade("#b9bccb", 0.78), 2.4)
    s.P("M 56 107 L 72 107 Q 70 116 64 116 Q 58 116 56 107 Z", "#6b6478")
    s.P("M 64 10 C 40 10, 24 28, 24 48 C 24 62, 32 70, 40 78 C 44 82, 46 86, 46 92 L 82 92 C 82 86, 84 82, 88 78 "
        "C 96 70, 104 62, 104 48 C 104 28, 88 10, 64 10 Z", glass, g=s.rad(glass, 50, 30, 76, 0.7, 0.9))
    s.gloss(42, 32, 5, 10, 32, 0.75)
    s.face(64, 52, gap=22, eye=3.5)


def glasses(s):
    s.shadow(rx=44, cy=104)
    frame, lens = PLUM, "#d9f0ff"
    s.tube("M 20 56 L 6 49", frame, 6)
    s.tube("M 108 56 L 122 49", frame, 6)
    for x in (40, 88):
        s.C(x, 64, 21, lens, noline=True, op=0.92)
        s.stroke("M %s 60 L %s 49" % (f(x - 12), f(x - 1)), "#ffffff", 4, op=0.9)
        s.stroke("M %s 69 L %s 60" % (f(x - 8), f(x + 1)), "#ffffff", 3, op=0.8)
        s.tube("M %s 64 A 21 21 0 1 0 %s 64 A 21 21 0 1 0 %s 64 Z" % (f(x - 21), f(x + 21), f(x - 21)), frame, 7)
    s.tube("M 59 58 Q 64 51 69 58", frame, 6)


def hat(s):
    s.shadow(rx=50, cy=112)
    straw, band = "#f3cf74", "#f0744a"
    s.E(64, 86, 56, 18, straw, g=s.rad(straw, 44, 74, 70))
    for (a, b, c) in [((14, 88), (22, 96), (34, 100)), ((94, 100), (106, 96), (114, 88))]:
        s.stroke("M %s Q %s %s" % (pt(a), pt(b), pt(c)), shade(straw, 0.8), 2)
    crown = "M 34 86 C 34 52, 44 34, 64 34 C 84 34, 94 52, 94 86 Q 64 96 34 86 Z"
    cl = s.clip('<path d="%s"/>' % crown)
    s.P(crown, straw, g=(34, 34, 94, 96))
    s.group(clip_path=cl)
    s.P("M 20 66 Q 64 76 108 66 L 108 80 Q 64 92 20 80 Z", band, noline=True)
    s.end()
    s.P(crown, straw, g="none")
    s.stroke("M 35 66 Q 64 75 93 66", s.ln(band), 1.8, op=0.7)
    for k in range(5):
        a = math.radians(k * 72 - 90)
        s.C(84 + 5 * math.cos(a), 73 + 5 * math.sin(a), 4.4, "#ffb3c8", sw=2)
    s.C(84, 73, 3, YEL, noline=True)
    s.stroke("M 46 44 Q 52 38 60 37", "#ffffff", 3, op=0.55)


def scarf(s):
    s.shadow(rx=34)
    c, stripe = TEAL, "#fff1d6"
    ends = [("M 47 56 L 65 56 L 59 104 L 39 101 Z", c), ("M 63 56 L 80 56 L 87 99 L 68 104 Z", shade(c, 0.9))]
    for d, col in ends:
        cl = s.clip('<path d="%s"/>' % d)
        s.P(d, col, g=(39, 56, 87, 104))
        s.group(clip_path=cl)
        s.R(30, 72, 70, 6, stripe, noline=True)
        s.R(30, 86, 70, 6, stripe, noline=True)
        s.end()
        s.P(d, col, g="none")
    for x in (42, 47, 52, 57):
        s.tube("M %d 102 L %d 112" % (x, x - 1), c, 4.5)
    for x in (70, 75, 80, 85):
        s.tube("M %d 102 L %d 111" % (x, x + 1), shade(c, 0.9), 4.5)
    d = ring(64, 44, 38, 18, 24, 8)
    cl = s.clip('<path d="%s" fill-rule="evenodd" clip-rule="evenodd"/>' % d)
    s.P(d, c, g=(26, 26, 102, 62), fill_rule="evenodd")
    s.group(clip_path=cl)
    for x in (40, 86):
        s.R(x, 20, 6, 50, stripe, noline=True)
    s.end()
    s.P(d, c, g="none", fill_rule="evenodd")
    s.E(60, 58, 12, 10, c, g=True)


def scissors(s):
    s.shadow(rx=38)
    steel, h1, h2 = "#d3d9e4", "#f68b3c", BLU
    s.P("M 56 72 L 98 18 Q 103 13 104 20 Q 92 44 66 78 Z", steel, g=(56, 13, 104, 78))
    s.tube("M 52 88 L 60 74", h1, 9)
    s.P(ring(44, 98, 17, 13, 8.5, 6), h1, g=(27, 85, 61, 111), fill_rule="evenodd")
    s.P("M 72 72 L 30 18 Q 25 13 24 20 Q 36 44 62 78 Z", steel, g=(24, 13, 72, 78))
    s.tube("M 76 88 L 68 74", h2, 9)
    s.P(ring(84, 98, 17, 13, 8.5, 6), h2, g=(67, 85, 101, 111), fill_rule="evenodd")
    s.C(64, 72, 5, "#9aa3b5")


def speaker(s):
    s.shadow(rx=38)
    c, wave = "#f68b3c", TEAL
    s.R(18, 48, 28, 34, shade(c, 0.9), rx=6)
    s.P("M 42 50 L 70 28 Q 76 24 76 32 L 76 98 Q 76 106 70 102 L 42 80 Z", c, g=(42, 24, 76, 106))
    s.tube("M 88 46 Q 98 65 88 84", wave, 7)
    s.tube("M 100 34 Q 117 65 100 96", wave, 7)
    s.stroke("M 48 54 L 66 40", "#ffffff", 3, op=0.55)


def ear(s):
    s.shadow(rx=28, cy=118)
    skin, inner = SKIN, "#eaa28c"
    s.tube("M 30 52 Q 21 65 30 78", BLU, 5)
    s.tube("M 19 42 Q 5 65 19 88", BLU, 5)
    s.P("M 46 50 C 44 26, 62 12, 80 14 C 100 16, 108 36, 104 54 C 100 72, 86 76, 84 92 C 82 106, 70 114, 58 112 "
        "C 46 110, 42 100, 48 94 C 52 90, 50 80, 48 72 C 46 64, 46 56, 46 50 Z", skin, g=(42, 12, 108, 114))
    s.P("M 58 40 C 66 28, 90 30, 92 48 C 94 62, 80 68, 76 80 C 74 88, 70 92, 64 90 C 70 82, 68 74, 64 68 "
        "C 60 62, 56 54, 58 40 Z", inner, noline=True, op=0.75)
    s.stroke("M 58 42 C 66 28, 90 30, 92 48 C 94 62, 80 68, 76 80", s.ln(skin), 3)
    s.stroke("M 60 58 Q 68 54 70 62 Q 71 68 66 70", s.ln(skin), 2.6)


def hand(s):
    s.shadow(rx=32, cy=116)
    shapes = [("rect", dict(x=36, y=54, width=58, height=56, rx=24)),
              ("rect", dict(x=38, y=22, width=14, height=48, rx=7)),
              ("rect", dict(x=54, y=14, width=14, height=54, rx=7)),
              ("rect", dict(x=70, y=19, width=14, height=50, rx=7)),
              ("rect", dict(x=86, y=33, width=12, height=40, rx=6)),
              ("rect", dict(x=19, y=50, width=14, height=38, rx=7, transform="rotate(-38 30 82)"))]
    s.blob(shapes, SKIN, g=(18, 14, 98, 110))
    s.stroke("M 50 88 Q 62 96 78 88", s.ln(SKIN), 2.2, op=0.5)
    s.stroke("M 104 20 Q 110 27 108 36", s.ln(SKIN), 2.6, op=0.7)
    s.stroke("M 112 13 Q 121 25 117 38", s.ln(SKIN), 2.6, op=0.7)


def lock(s):
    s.shadow(rx=36)
    gold, steel = GOLD, "#bfc5d3"
    s.tube("M 42 60 L 42 42 Q 42 18 64 18 Q 86 18 86 42 L 86 60", steel, 11)
    s.R(26, 52, 76, 58, gold, rx=16, g=True)
    s.C(64, 74, 7.5, "#5a4652", noline=True)
    s.P("M 60 77 L 57 95 L 71 95 L 68 77 Z", "#5a4652", noline=True)
    s.stroke("M 34 62 L 34 88", "#ffffff", 3.6, op=0.5)


def repeat(s):
    """Spin the Words' picture: two paper arrows chasing round."""
    s.shadow(rx=30)
    for a0, a1, c in [(200, 330, ORA), (20, 150, TEAL)]:
        r, cx, cy = 36, 64, 62
        p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
        p1 = (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1)))
        s.tube("M %s A %s %s 0 0 1 %s" % (pt(p0), f(r), f(r), pt(p1)), c, 15)
        t = math.radians(a1)
        tip = (cx + r * math.cos(t + 0.32), cy + r * math.sin(t + 0.32))
        o = (cx + (r + 15) * math.cos(t), cy + (r + 15) * math.sin(t))
        i = (cx + (r - 15) * math.cos(t), cy + (r - 15) * math.sin(t))
        s.P("M %s L %s L %s Z" % (pt(o), pt(tip), pt(i)), c)


def coin(s):
    """One gold coin with a pressed star: the game's money, readable down to 26 px."""
    s.shadow(rx=34)
    s.C(68, 67, 46, shade(GOLD, 0.74))           # its edge, seen past the face
    s.C(62, 61, 46, GOLD)
    s.C(62, 61, 34, lite(GOLD, 0.22))
    small_star(s, 62, 62, 21, 9.5, "#e39a14")
    s.gloss(44, 42, 7, 4, -40)


def sticker(s):
    """The Sticker Album: a star sticker on its backing, one corner peeling up."""
    s.shadow(rx=40)
    sheet = "M 30 14 L 98 14 Q 114 14 114 30 L 114 80 L 80 114 L 30 114 Q 14 114 14 98 L 14 30 Q 14 14 30 14 Z"
    s.P(sheet, "#fff6e4")
    s.P("M 114 80 L 80 114 Q 84 92 90 88 Q 96 84 114 80 Z", "#e6d5b8")
    small_star(s, 60, 60, 36, 17, YEL)
    s.face(60, 64, gap=14, eye=2.8, bdx=10, bdy=4)


def wordbook(s):
    """My Word Book: an orange notebook, rings down its spine, a pencil beside it."""
    s.shadow(rx=40)
    s.R(34, 18, 66, 92, "#fff7e3", rx=8)
    s.R(22, 14, 70, 94, ORA, rx=9)
    s.R(36, 28, 44, 26, "#fff7e3", rx=6)
    s.stroke("M 43 37 L 73 37 M 43 45 L 64 45", "#d9c39a", 3)
    small_star(s, 58, 80, 11, 5, YEL)
    for y in range(26, 104, 14):
        s.C(22, y, 5, "#e9e2d4")
        s.C(22, y, 1.8, "#8a7a6a", noline=True)
    s.group(transform="rotate(-48 96 92)")
    s.P("M 78 86 L 64 92 L 78 98 Z", "#f6d6a6")
    s.P("M 68.5 90 L 64 92 L 68.5 94 Z", "#4b3a44", noline=True)
    s.R(77, 86, 34, 12, "#ffc93c", rx=2)
    s.R(111, 85.5, 7, 13, "#c9cfdb", rx=1.5)
    s.R(117, 86, 8, 12, "#ff9fb5", rx=4)
    s.end()


def shirt(s):
    """The Closet's Clothes tab: a teal T-shirt with a star."""
    s.shadow(rx=40)
    s.P("M 44 18 Q 64 31 84 18 L 108 30 L 119 55 L 100 63 L 96 52 L 96 110 L 32 110 L 32 52 L 28 63 L 9 55 "
        "L 20 30 Z", TEAL, g=(9, 18, 119, 110))
    s.stroke("M 45 20 Q 64 36 83 20", lite(TEAL, 0.45), 5)
    small_star(s, 64, 72, 14, 6.5, YEL)
    s.stroke("M 40 42 L 40 98", "#ffffff", 4, op=0.4)


def bird(s):
    """The Closet's Pets tab: a little maya bird, the pet that comes first."""
    s.shadow(rx=36)
    s.P("M 40 74 L 10 58 L 8 78 L 16 90 L 42 86 Z", "#8a5a3a")
    s.E(60, 74, 34, 30, "#c08552", g=True)
    s.E(66, 84, 22, 16, "#f6e3c4", noline=True)
    s.C(84, 48, 22, "#a8693f", g=True)
    s.E(90, 56, 11, 8, "#fff3dc", noline=True)
    s.P("M 104 44 L 120 50 L 104 56 Z", "#ffb52e")
    s.eye(92, 44, 4.2)
    s.blush(84, 60, 3.4)
    s.E(50, 66, 22, 13, "#8a5a3a", rot=-24)
    s.stroke("M 56 102 L 54 112 M 70 102 L 70 112", "#e9801f", 4)


# name: (function, group, label)
ICONS = {
    # animals
    "cat": (cat, "Animals", "Cat"), "dog": (dog, "Animals", "Dog"), "fish": (fish, "Animals", "Fish"),
    "hen": (hen, "Animals", "Hen"), "bee": (bee, "Animals", "Bee"), "bear": (bear, "Animals", "Bear"),
    "rabbit": (rabbit, "Animals", "Rabbit"), "mouse": (mouse, "Animals", "Mouse"), "fox": (fox, "Animals", "Fox"),
    "frog": (frog, "Animals", "Frog"), "ant": (ant, "Animals", "Ant"), "snake": (snake, "Animals", "Snake"),
    "butterfly": (butterfly, "Animals", "Butterfly"), "elephant": (elephant, "Animals", "Elephant"),
    "goat": (goat, "Animals", "Goat"), "raccoon": (raccoon, "Animals", "Racoon"),
    # sky, nature, food
    "sun": (sun, "Sky and nature", "Sun"), "moon": (moon, "Sky and nature", "Moon"),
    "star": (star, "Sky and nature", "Star"), "cloud": (cloud, "Sky and nature", "Cloud"),
    "night": (night, "Sky and nature", "Night"), "sparkles": (sparkles, "Sky and nature", "Sparkles"),
    "bolt": (bolt, "Sky and nature", "Lightning"), "tree": (tree, "Sky and nature", "Mango tree"),
    "palm": (palm, "Sky and nature", "Palm tree"), "mountain": (mountain, "Sky and nature", "Mountain"),
    "waves": (waves, "Sky and nature", "Waves"),
    "apple": (apple, "Food", "Apple"), "banana": (banana, "Food", "Banana"), "pear": (pear, "Food", "Pear"),
    "grapes": (grapes, "Food", "Grapes"), "cake": (cake, "Food", "Cake"),
    # things
    "book": (book, "Things", "Book"), "stories": (stories, "Things", "Stories"), "pencil": (pencil, "Things", "Pencil"),
    "bag": (bag, "Things", "Bag"), "ball": (ball, "Things", "Ball"), "boat": (boat, "Things", "Boat"),
    "bus": (bus, "Things", "Bus"), "car": (car, "Things", "Car"), "house": (house, "Things", "House"),
    "hut": (hut, "Things", "Bahay kubo"), "box": (box, "Things", "Box"), "hat": (hat, "Things", "Hat"),
    "hand": (hand, "Things", "Hand"), "ear": (ear, "Things", "Ear"), "scissors": (scissors, "Things", "Scissors"),
    "glasses": (glasses, "Things", "Glasses"), "scarf": (scarf, "Things", "Scarf"), "lock": (lock, "Things", "Lock"),
    "speaker": (speaker, "Things", "Speaker"), "bulb": (bulb, "Things", "Bright idea"),
    "heart": (heart, "Things", "Heart"), "gift": (gift, "Things", "Gift"), "crown": (crown, "Things", "Crown"),
    "trophy": (trophy, "Things", "Trophy"), "coins": (coins, "Things", "Coins"), "chest": (chest, "Things", "Treasure"),
    "chest_open": (chest_open, "Things", "Open treasure"), "repeat": (repeat, "Things", "Spin again"),
    "coin": (coin, "Things", "Coin"), "sticker": (sticker, "Things", "Sticker"),
    "wordbook": (wordbook, "Things", "Word book"), "shirt": (shirt, "Things", "Shirt"),
    "bird": (bird, "Animals", "Bird"),
}


FIT = {}
_fit_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fit.json")
if os.path.exists(_fit_path):
    FIT = json.load(open(_fit_path, encoding="utf-8"))


def draw(name, prefix="", mode="paper"):
    s = Icon(name, prefix, mode)
    ICONS[name][0](s)
    if mode == "paper" and name in FIT:
        s.vb = FIT[name]
    return s


if __name__ == "__main__":
    import sys
    out = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else "paper"
    os.makedirs(out, exist_ok=True)
    for n in ICONS:
        with open(os.path.join(out, n + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(draw(n, mode=mode).svg())
    print("wrote", len(ICONS), "icons to", out)
