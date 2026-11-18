"""Racoon redesign options as SVG (400x400, feet near y=378).

A Mochi: big round head, small bean body, thick ink outline, soft shading.
B Bean plush: head and body one soft bean, tonal outline.
C Little reader: Mochi proportions, a bit taller, holding an open book.
D Sticker: Mochi shapes, flat fills, thin inner lines, thick white sticker edge.
Moods: idle, happy, thinking, sleepy; plus idle wearing a salakot.
"""
import math
import os

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT_DIR, exist_ok=True)

INK = "#3b2d3a"
FUR = "#8e8899"
FUR_LIGHT = "#aaa4b6"
FUR_SHADE = "#716a80"
FUR_DARK = "#5d5766"
MASK = "#3a2f40"
MASK_TOP = "#4a3e52"
CREAM = "#fbf3e4"
CREAM_SHADE = "#ead8c0"
EAR_IN = "#eab3a3"
BLUSH = "#f08c78"
TEAL = "#2a9d8f"
TEAL_LIGHT = "#45b8a9"
TEAL_DEEP = "#1d7166"
NIPA = "#c99a66"
NIPA_DEEP = "#845837"
CORAL = "#e9801f"
CORAL_DEEP = "#bd6212"
PAGE = "#fffef4"


# --- geometry helpers ------------------------------------------------------------------

def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def smooth_path(pts, closed=True):
    """Catmull-Rom through pts as cubic Beziers."""
    n = len(pts)
    d = [f"M {f(pts[0][0])} {f(pts[0][1])}"]
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[(i + 1) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d.append(f"C {f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    if closed:
        d.append("Z")
    return " ".join(d)


def head_pts(cx, cy, rx, ry, tuft=0.07, n=72):
    """Round head with soft cheek tufts low on each side."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        k = 1.0
        for c in (0.34, math.pi - 0.34):
            da = abs((a - c + math.pi) % math.tau - math.pi)
            k += tuft * max(0.0, 1 - da / 0.3) ** 2
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return pts


def mask_path(cx, cy, half_w, half_h, droop=10, bridge=0.62):
    top, bot = [], []
    n = 28
    for i in range(n + 1):
        x = -half_w + 2 * half_w * i / n
        u = abs(x) / half_w
        h = half_h * math.sqrt(max(0.0, 1 - u ** 2.2)) * (bridge + (1 - bridge) * min(1.0, abs(x) / (half_w * 0.42)))
        yc = 4 + droop * u ** 2
        top.append((cx + x, cy + yc - h))
        bot.append((cx + x, cy + yc + h))
    pts = top + bot[::-1][1:-1]
    return smooth_path(pts)


def bezier(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def tail_parts(p0, p1, p2, r0, rmid, rtip, rings):
    """A fluffy tail along a quadratic curve: outline path and ring band paths."""
    n = 40
    left, right, center = [], [], []
    for i in range(n + 1):
        t = i / n
        p = bezier(p0, p1, p2, t)
        q = bezier(p0, p1, p2, min(1, t + 0.01))
        o = bezier(p0, p1, p2, max(0, t - 0.01))
        dx, dy = q[0] - o[0], q[1] - o[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        r = r0 + (rmid - r0) * math.sin(math.pi * min(t, 0.75) / 1.5) ** 1.2
        r = r * (1 - t) + rtip * t if t > 0.75 else r
        left.append((p[0] + nx * r, p[1] + ny * r))
        right.append((p[0] - nx * r, p[1] - ny * r))
        center.append((p, (dx / ln, dy / ln), r))
    # round tip
    (pe, (tx, ty), re) = center[-1]
    cap = []
    a0 = math.atan2(-ty * 0 + left[-1][1] - pe[1], left[-1][0] - pe[0])
    for k in range(1, 9):
        a = a0 - math.pi * k / 9
        cap.append((pe[0] + math.cos(a) * re, pe[1] + math.sin(a) * re))
    outline = smooth_path(left + cap + right[::-1])
    bands = []
    for (t1, t2) in rings:
        i1, i2 = int(t1 * n), int(t2 * n)
        pts = left[i1:i2 + 1] + right[i1:i2 + 1][::-1]
        if t2 >= 0.999:
            pts = left[i1:] + cap + right[i1:][::-1]
        bands.append(smooth_path(pts))
    return outline, bands


def defs(flat=False):
    if flat:
        return ""
    return f"""<defs>
<radialGradient id="fur" cx="0.38" cy="0.3" r="0.8"><stop offset="0" stop-color="{FUR_LIGHT}"/><stop offset="0.55" stop-color="{FUR}"/><stop offset="1" stop-color="{FUR_SHADE}"/></radialGradient>
<radialGradient id="cream" cx="0.4" cy="0.3" r="0.85"><stop offset="0" stop-color="#fffbf2"/><stop offset="0.7" stop-color="{CREAM}"/><stop offset="1" stop-color="{CREAM_SHADE}"/></radialGradient>
<linearGradient id="mask" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{MASK_TOP}"/><stop offset="1" stop-color="{MASK}"/></linearGradient>
<linearGradient id="teal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{TEAL_LIGHT}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient>
<radialGradient id="dark" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="#6f6879"/><stop offset="1" stop-color="{FUR_DARK}"/></radialGradient>
<linearGradient id="nipa" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#dcb07c"/><stop offset="1" stop-color="{NIPA}"/></linearGradient>
<linearGradient id="cover" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f29a45"/><stop offset="1" stop-color="{CORAL}"/></linearGradient>
</defs>"""


class Style:
    def __init__(self, name, outline, ow, inner_w, flat=False, backing=False):
        self.backing = backing  # white silhouette with a wide white edge (sticker)
        self.name = name
        self.outline = outline
        self.ow = ow           # outline width on outer shapes
        self.inner_w = inner_w  # outline width on inner shapes (0 = none)
        self.flat = flat

    def fill(self, grad, flat_color):
        if self.backing:
            return "#ffffff"
        return flat_color if self.flat else f"url(#{grad})"

    def stroke(self, inner=False):
        w = self.inner_w if inner else self.ow
        if w <= 0:
            return 'stroke="none"'
        return f'stroke="{self.outline}" stroke-width="{f(w)}" stroke-linejoin="round" stroke-linecap="round"'


def capsule(a, b, w, fill, st):
    """A rounded limb: an outline line under a fill line."""
    out = ""
    if st.ow > 0:
        out += f'<line x1="{f(a[0])}" y1="{f(a[1])}" x2="{f(b[0])}" y2="{f(b[1])}" stroke="{st.outline}" stroke-width="{f(w + st.ow * 2)}" stroke-linecap="round"/>'
    out += f'<line x1="{f(a[0])}" y1="{f(a[1])}" x2="{f(b[0])}" y2="{f(b[1])}" stroke="{"#ffffff" if st.backing else fill}" stroke-width="{f(w)}" stroke-linecap="round"/>'
    return out


def ear(cx, cy, rot, s, st, size=1.0):
    outer = "M -38 30 C -34 -8 -16 -40 0 -46 C 16 -40 34 -8 38 30 C 14 40 -14 40 -38 30 Z"
    inner = "M -20 24 C -18 0 -9 -20 0 -25 C 9 -20 18 0 20 24 C 8 30 -8 30 -20 24 Z"
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(rot)}) scale({f(size)})">'
            f'<path d="{outer}" fill="{st.fill("fur", FUR)}" {st.stroke()}/>'
            + ("" if st.backing else f'<path d="{inner}" fill="{EAR_IN}"/>') + '</g>')


def face(cx, cy, mood, st, scale=1.0, eye_dx=46):
    """Mask, brows, eyes, muzzle, nose, mouth and blush around (cx, cy) = mask center."""
    s = scale
    g = []
    g.append(f'<ellipse cx="{f(cx - 45 * s)}" cy="{f(cy - 40 * s)}" rx="{f(24 * s)}" ry="{f(9 * s)}" fill="{CREAM}" transform="rotate(-10 {f(cx - 45 * s)} {f(cy - 40 * s)})"/>')
    g.append(f'<ellipse cx="{f(cx + 45 * s)}" cy="{f(cy - 40 * s)}" rx="{f(24 * s)}" ry="{f(9 * s)}" fill="{CREAM}" transform="rotate(10 {f(cx + 45 * s)} {f(cy - 40 * s)})"/>')
    g.append(f'<path d="{mask_path(cx, cy, 100 * s, 31 * s, 11 * s)}" fill="{st.fill("mask", MASK)}"/>')
    ey = cy + 2 * s
    for side in (-1, 1):
        ex = cx + side * eye_dx * s
        if mood == "happy":
            g.append(f'<path d="M {f(ex - 12 * s)} {f(ey + 5 * s)} Q {f(ex)} {f(ey - 13 * s)} {f(ex + 12 * s)} {f(ey + 5 * s)}" fill="none" stroke="{CREAM}" stroke-width="{f(6 * s)}" stroke-linecap="round"/>')
        elif mood == "sleepy":
            g.append(f'<path d="M {f(ex - 12 * s)} {f(ey - 1 * s)} Q {f(ex)} {f(ey + 10 * s)} {f(ex + 12 * s)} {f(ey - 1 * s)}" fill="none" stroke="{CREAM}" stroke-width="{f(5.5 * s)}" stroke-linecap="round"/>')
        else:
            look = (3 * s, -5 * s) if mood == "thinking" else (0, 1 * s)
            g.append(f'<circle cx="{f(ex)}" cy="{f(ey)}" r="{f(17 * s)}" fill="{CREAM}"/>')
            g.append(f'<circle cx="{f(ex + look[0])}" cy="{f(ey + look[1])}" r="{f(10.5 * s)}" fill="#221a26"/>')
            g.append(f'<circle cx="{f(ex + look[0] - 3.5 * s)}" cy="{f(ey + look[1] - 4 * s)}" r="{f(3.8 * s)}" fill="#ffffff"/>')
            g.append(f'<circle cx="{f(ex + look[0] + 3.5 * s)}" cy="{f(ey + look[1] + 3.5 * s)}" r="{f(1.6 * s)}" fill="#ffffff" opacity="0.8"/>')
    my = cy + 40 * s
    g.append(f'<ellipse cx="{f(cx)}" cy="{f(my)}" rx="{f(46 * s)}" ry="{f(31 * s)}" fill="{st.fill("cream", CREAM)}"/>')
    for side in (-1, 1):
        g.append(f'<ellipse cx="{f(cx + side * 76 * s)}" cy="{f(cy + 36 * s)}" rx="{f(15 * s)}" ry="{f(9 * s)}" fill="{BLUSH}" opacity="0.5"/>')
    ny = cy + 25 * s
    g.append(f'<ellipse cx="{f(cx)}" cy="{f(ny)}" rx="{f(14 * s)}" ry="{f(10 * s)}" fill="#2d2430"/>')
    g.append(f'<ellipse cx="{f(cx - 4 * s)}" cy="{f(ny - 4 * s)}" rx="{f(5 * s)}" ry="{f(3 * s)}" fill="#ffffff" opacity="0.55"/>')
    mo = cy + 42 * s
    if mood == "happy":
        g.append(f'<path d="M {f(cx - 15 * s)} {f(mo - 2 * s)} Q {f(cx)} {f(mo + 20 * s)} {f(cx + 15 * s)} {f(mo - 2 * s)} Z" fill="#6b2f36" stroke="#2d2430" stroke-width="{f(3 * s)}" stroke-linejoin="round"/>')
        g.append(f'<ellipse cx="{f(cx)}" cy="{f(mo + 9 * s)}" rx="{f(7 * s)}" ry="{f(4 * s)}" fill="{CORAL}"/>')
    elif mood == "thinking":
        g.append(f'<path d="M {f(cx + 1 * s)} {f(mo + 4 * s)} Q {f(cx + 9 * s)} {f(mo + 1 * s)} {f(cx + 16 * s)} {f(mo + 4 * s)}" fill="none" stroke="#2d2430" stroke-width="{f(4 * s)}" stroke-linecap="round"/>')
    elif mood == "sleepy":
        g.append(f'<ellipse cx="{f(cx)}" cy="{f(mo + 5 * s)}" rx="{f(5 * s)}" ry="{f(6 * s)}" fill="#6b2f36"/>')
    else:
        g.append(f'<path d="M {f(cx - 15 * s)} {f(mo)} Q {f(cx - 7.5 * s)} {f(mo + 9 * s)} {f(cx)} {f(mo)} Q {f(cx + 7.5 * s)} {f(mo + 9 * s)} {f(cx + 15 * s)} {f(mo)}" fill="none" stroke="#2d2430" stroke-width="{f(4 * s)}" stroke-linecap="round" stroke-linejoin="round"/>')
    return "".join(g)


def zzz(x, y, st):
    return (f'<g fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" opacity="0.75">'
            f'<path d="M {x} {y} h 18 l -18 20 h 18"/><path d="M {x + 28} {y - 30} h 13 l -13 14 h 13"/></g>')


def salakot(cx, top, st, width=1.0):
    w = 118 * width
    brim_y = top + 64
    lines = "".join(
        f'<line x1="{f(cx)}" y1="{f(top + 6)}" x2="{f(cx - w * 0.86 + i * w * 0.287)}" y2="{f(brim_y - 4)}" stroke="{NIPA_DEEP}" stroke-width="3" opacity="0.55" stroke-linecap="round"/>'
        for i in range(7))
    return (f'<ellipse cx="{f(cx)}" cy="{f(brim_y)}" rx="{f(w)}" ry="20" fill="{NIPA_DEEP}" {st.stroke()}/>'
            f'<path d="M {f(cx - w * 0.92)} {f(brim_y - 2)} Q {f(cx - w * 0.3)} {f(top + 16)} {f(cx)} {f(top)} Q {f(cx + w * 0.3)} {f(top + 16)} {f(cx + w * 0.92)} {f(brim_y - 2)} Q {f(cx)} {f(brim_y + 16)} {f(cx - w * 0.92)} {f(brim_y - 2)} Z" fill="{st.fill("nipa", NIPA)}" {st.stroke()}/>'
            + lines +
            f'<circle cx="{f(cx)}" cy="{f(top - 2)}" r="9" fill="{NIPA_DEEP}" {st.stroke()}/>')


def scarf(cx, y, half, st, sag=24, knot_dx=36):
    band = (f'M {f(cx - half)} {f(y - 10)} C {f(cx - half * 0.5)} {f(y + sag - 10)} {f(cx + half * 0.5)} {f(y + sag - 10)} {f(cx + half)} {f(y - 10)} '
            f'L {f(cx + half + 2)} {f(y + 9)} C {f(cx + half * 0.5)} {f(y + sag + 14)} {f(cx - half * 0.5)} {f(y + sag + 14)} {f(cx - half - 2)} {f(y + 9)} Z')
    kx, ky = cx + knot_dx, y + sag - 2
    tails = (f'<path d="M {f(kx - 4)} {f(ky + 6)} C {f(kx - 10)} {f(ky + 26)} {f(kx - 8)} {f(ky + 40)} {f(kx - 2)} {f(ky + 38)} L {f(kx + 12)} {f(ky + 34)} C {f(kx + 10)} {f(ky + 30)} {f(kx + 10)} {f(ky + 18)} {f(kx + 8)} {f(ky + 6)} Z" fill="{TEAL_DEEP}" {st.stroke(inner=False) if st.ow else ""}/>'
             f'<path d="M {f(kx + 6)} {f(ky + 4)} C {f(kx + 18)} {f(ky + 20)} {f(kx + 26)} {f(ky + 30)} {f(kx + 28)} {f(ky + 32)} L {f(kx + 36)} {f(ky + 24)} C {f(kx + 34)} {f(ky + 20)} {f(kx + 24)} {f(ky + 8)} {f(kx + 14)} {f(ky)} Z" fill="{TEAL}" {st.stroke() if st.ow else ""}/>')
    return (tails + f'<path d="{band}" fill="{st.fill("teal", TEAL)}" {st.stroke()}/>'
            f'<ellipse cx="{f(kx)}" cy="{f(ky)}" rx="13" ry="12" fill="{TEAL_DEEP}" {st.stroke()}/>')


# --- the options ------------------------------------------------------------------------

def mochi_parts(st, mood, hat, wave=True, book=False, tall=False):
    """Back-to-front shapes for Mochi-like Racoons (A, C, D)."""
    hy = 172 if tall else 180       # mask center
    hcy = hy - 2                    # head center
    hrx, hry = (108, 92) if tall else (118, 100)
    body_cy, body_ry = (318, 62) if tall else (320, 58)
    g = []
    outline, bands = tail_parts((232, 326), (340, 340), (322, 206), 20, 40, 24,
                                [(0.36, 0.48), (0.62, 0.74), (0.86, 1.0)])
    g.append(f'<path d="{outline}" fill="{st.fill("fur", FUR)}"/>')
    if not st.backing:
        for b in bands:
            g.append(f'<path d="{b}" fill="{st.fill("mask", MASK)}"/>')
    if st.ow:
        g.append(f'<path d="{outline}" fill="none" {st.stroke()}/>')
    # feet and body
    for x in (170, 230):
        g.append(f'<ellipse cx="{x}" cy="371" rx="25" ry="13" fill="{st.fill("dark", FUR_DARK)}" {st.stroke()}/>')
    g.append(f'<ellipse cx="200" cy="{body_cy}" rx="70" ry="{body_ry}" fill="{st.fill("fur", FUR)}" {st.stroke()}/>')
    if not st.backing:
        g.append(f'<ellipse cx="200" cy="{body_cy + 8}" rx="44" ry="{body_ry - 18}" fill="{st.fill("cream", CREAM)}"/>')
    if book:
        g.append(open_book(200, 318, st))
        for x in (142, 258):
            g.append(f'<circle cx="{x}" cy="324" r="15" fill="{st.fill("dark", FUR_DARK)}" {st.stroke()}/>')
    else:
        limb = FUR_DARK if st.flat else FUR_SHADE
        g.append(capsule((256, 302), (266, 340), 26, limb, st))
        if wave:   # the free side: the tail is on the right
            g.append(capsule((144, 300), (98, 262), 26, limb, st))
        else:
            g.append(capsule((146, 300), (134, 338), 26, limb, st))
    # ears, head
    g.append(ear(200 - hrx * 0.66, hcy - hry * 0.82, -24, None, st, 1.0))
    g.append(ear(200 + hrx * 0.66, hcy - hry * 0.82, 24, None, st, 1.0))
    g.append(f'<path d="{smooth_path(head_pts(200, hcy, hrx, hry))}" fill="{st.fill("fur", FUR)}" {st.stroke()}/>')
    if not st.flat and not st.backing:
        g.append(f'<ellipse cx="{200 - hrx * 0.42}" cy="{hcy - hry * 0.62}" rx="26" ry="11" fill="#ffffff" opacity="0.28" transform="rotate(-22 {200 - hrx * 0.42} {hcy - hry * 0.62})"/>')
    if not st.backing:
        g.append(face(200, hy, mood, st, 0.92 if tall else 1.0))
    g.append(scarf(200, hcy + hry - 2, 66, st))
    if hat:
        g.append(salakot(200, hcy - hry - 40, st))
    if mood == "sleepy" and not st.backing:
        g.append(zzz(300, 92, st))
    return g


def open_book(cx, cy, st):
    cover = f'M {cx - 66} {cy - 12} L {cx} {cy + 2} L {cx + 66} {cy - 12} L {cx + 68} {cy + 40} L {cx} {cy + 54} L {cx - 68} {cy + 40} Z'
    left = f'M {cx - 58} {cy - 14} Q {cx - 28} {cy - 20} {cx} {cy - 4} L {cx} {cy + 46} Q {cx - 28} {cy + 30} {cx - 60} {cy + 34} Z'
    right = f'M {cx + 58} {cy - 14} Q {cx + 28} {cy - 20} {cx} {cy - 4} L {cx} {cy + 46} Q {cx + 28} {cy + 30} {cx + 60} {cy + 34} Z'
    lines = "".join(
        f'<path d="M {cx + s * 12} {cy + 4 + k * 9} Q {cx + s * 30} {cy - 2 + k * 9} {cx + s * 48} {cy + k * 9}" stroke="#7d6857" stroke-width="2.5" opacity="0.45" fill="none" stroke-linecap="round"/>'
        for s in (-1, 1) for k in range(4))
    return (f'<path d="{cover}" fill="{st.fill("cover", CORAL)}" {st.stroke()}/>'
            f'<path d="{left}" fill="{PAGE}" {st.stroke(inner=True) if st.inner_w else ""}/>'
            f'<path d="{right}" fill="{PAGE}" {st.stroke(inner=True) if st.inner_w else ""}/>' + lines)


def bean_parts(st, mood, hat):
    g = []
    outline, bands = tail_parts((286, 330), (352, 334), (334, 202), 24, 42, 26,
                                [(0.34, 0.47), (0.6, 0.73), (0.86, 1.0)])
    g.append(f'<path d="{outline}" fill="{st.fill("fur", FUR)}"/>')
    for b in bands:
        g.append(f'<path d="{b}" fill="{st.fill("mask", MASK)}"/>')
    g.append(f'<path d="{outline}" fill="none" {st.stroke()}/>')
    for x in (162, 238):
        g.append(f'<ellipse cx="{x}" cy="372" rx="27" ry="13" fill="{st.fill("dark", FUR_DARK)}" {st.stroke()}/>')
    g.append(ear(136, 96, -26, None, st, 0.95))
    g.append(ear(264, 96, 26, None, st, 0.95))
    bean = "M 200 72 C 286 72 318 150 322 236 C 326 330 282 376 200 376 C 118 376 74 330 78 236 C 82 150 114 72 200 72 Z"
    g.append(f'<path d="{bean}" fill="{st.fill("fur", FUR)}" {st.stroke()}/>')
    g.append('<ellipse cx="142" cy="118" rx="28" ry="12" fill="#ffffff" opacity="0.28" transform="rotate(-24 142 118)"/>')
    g.append(f'<ellipse cx="200" cy="302" rx="74" ry="62" fill="{st.fill("cream", CREAM)}"/>')
    g.append(capsule((86, 258), (56, 218), 24, FUR_SHADE, st))
    g.append(capsule((316, 262), (326, 298), 24, FUR_SHADE, st))
    g.append(face(200, 168, mood, st, 0.95, eye_dx=46))
    g.append(scarf(200, 236, 112, st, sag=22, knot_dx=48))
    if hat:
        g.append(salakot(200, 26, st, 1.0))
    if mood == "sleepy":
        g.append(zzz(306, 88, st))
    return g


def svg(parts, extra_defs="", sticker=None, flat=False):
    body = "".join(parts)
    pre = ""
    if sticker:
        pre = (f'<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#3a2a1f" flood-opacity="0.25"/></filter>'
               f'<g filter="url(#sh)">{sticker}</g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">'
            f'{defs(flat)}{extra_defs}<ellipse cx="200" cy="380" rx="100" ry="12" fill="#3a2a1f" opacity="0.14"/>{pre}{body}</svg>')


def silhouette(parts):
    """The same shapes in white with a fat white edge: the sticker backing."""
    import re
    s = "".join(parts)
    s = re.sub(r'fill="[^"]*"', 'fill="#ffffff"', s)
    s = re.sub(r'stroke="(?!none)[^"]*"', 'stroke="#ffffff"', s)
    s = re.sub(r'stroke-width="[^"]*"', 'stroke-width="30"', s)
    s = re.sub(r'opacity="[^"]*"', '', s)
    s = re.sub(r'stroke="none"', 'stroke="#ffffff" stroke-width="30"', s)
    # every shape gets the white edge
    s = s.replace("<path ", '<path stroke="#ffffff" stroke-width="30" stroke-linejoin="round" ').replace(
        "<ellipse ", '<ellipse stroke="#ffffff" stroke-width="30" ').replace("<circle ", '<circle stroke="#ffffff" stroke-width="30" ')
    return s


STYLES = {
    "A": Style("Mochi", INK, 7, 0),
    "B": Style("Bean plush", "#5b5468", 6, 0),
    "C": Style("Little reader", INK, 7, 3),
    "D": Style("Sticker", "#5d5766", 3.5, 0, flat=True),
}

MOODS = ["idle", "happy", "thinking", "sleepy"]

for key, st in STYLES.items():
    for mood in MOODS + ["hat"]:
        m = "idle" if mood == "hat" else mood
        hat = mood == "hat"
        if key == "B":
            parts = bean_parts(st, m, hat)
        else:
            parts = mochi_parts(st, m, hat, book=(key == "C"), tall=(key == "C"))
        if key == "D":
            back = Style("backing", "#ffffff", 15, 0, flat=True, backing=True)
            backing = "".join(mochi_parts(back, m, hat))
            doc = svg(parts, sticker=backing, flat=True)
        else:
            doc = svg(parts)
        with open(os.path.join(OUT_DIR, f"racoon_{key}_{mood}.svg"), "w", encoding="utf-8") as fh:
            fh.write(doc)
print("wrote", len(os.listdir(OUT_DIR)), "files to", OUT_DIR)
