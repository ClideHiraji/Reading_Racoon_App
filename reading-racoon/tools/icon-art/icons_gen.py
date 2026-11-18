"""Reading Racoon's pictures (D-027), drawn in code so they share one style.

Modes:
- "paper" (the game's, D-027 revised): flat cut paper like the rest of the game (D-009). Every piece is
  one flat colour, lifted on a crisp little shadow with a faint edge; no gradients, shine or outlines.
  Colours are softened toward the warm paper. Each picture is cropped to fill its box (fit.json).
- "soft": soft round shapes, gentle light-to-shade gradients, a ground shadow and an outline in a
  deeper shade of each colour (the first proposal). "ink": the same with Racoon's ink outline.
Faces (dot eyes, blush) go on animals, the sky and fruit in every mode. 128 x 128 drawing space.
"""
import colorsys
import math

INK = "#3b2d3a"
W = 3.6           # outline width at 128 px
BLUSH = "#ff8a9c"
PAPER = "#fefde0"   # Palette.PAPER
LIFT = 2.4          # paper mode: how far a cut-out's shadow falls
SHADOW_OP = 0.22
EDGE_W = 1.5        # paper mode: the faint edge round each cut-out
EDGE_OP = 0.18


def f(v):
    if isinstance(v, str):
        return v
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def rgb(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def hexc(r):
    return "#" + "".join("%02x" % max(0, min(255, round(v * 255))) for v in r)


def mix(a, b, t):
    A, B = rgb(a), rgb(b)
    return hexc([A[i] + (B[i] - A[i]) * t for i in range(3)])


def _hls(c):
    return colorsys.rgb_to_hls(*rgb(c))


def _from(h, l, s):
    return hexc(colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s))))


def deep(c):
    """The outline: the same colour, much darker (yellows lean orange as they darken)."""
    h, l, s = _hls(c)
    if 0.08 < h < 0.2:
        h -= 0.04
    if s < 0.12:
        return mix(c, INK, 0.55)
    return _from(h, l * 0.5, min(1, s * 0.85 + 0.05))


def shade(c, k=0.84):
    h, l, s = _hls(c)
    if 0.08 < h < 0.2:
        h -= 0.015
    return _from(h, l * k, s)


def lite(c, k=0.45):
    h, l, s = _hls(c)
    return _from(h, l + (1 - l) * k, s)


def _light(c):
    """A pale colour that needs an edge to show on cream paper."""
    return isinstance(c, str) and c.startswith("#") and _hls(c)[1] > 0.76


def tag(t, **a):
    parts = []
    for k, v in a.items():
        if v is None:
            continue
        k = k.rstrip("_").replace("_", "-")
        parts.append('%s="%s"' % (k, f(v)))
    return "<%s %s/>" % (t, " ".join(parts))


def pt(p):
    return "%s %s" % (f(p[0]), f(p[1]))


def rounded(pts, ks):
    """A closed polygon with its corners rounded (k = how far along each edge the curve starts)."""
    n = len(pts)
    out = []
    for i in range(n):
        v, p, q = pts[i], pts[i - 1], pts[(i + 1) % n]
        k = ks[i] if isinstance(ks, (list, tuple)) else ks
        a = (v[0] + (p[0] - v[0]) * k, v[1] + (p[1] - v[1]) * k)
        b = (v[0] + (q[0] - v[0]) * k, v[1] + (q[1] - v[1]) * k)
        out.append(("L" if out else "M") + " " + pt(a) + " Q " + pt(v) + " " + pt(b))
    return " ".join(out) + " Z"


def star_pts(cx, cy, R, r, n=5, a0=-90):
    return [(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(a0 + 180 / n * i)),
             cy + (R if i % 2 == 0 else r) * math.sin(math.radians(a0 + 180 / n * i))) for i in range(2 * n)]


def crescent(O, R, I, r):
    """Path of the circle (O, R) with the circle (I, r) cut out of it."""
    dx, dy = I[0] - O[0], I[1] - O[1]
    d = math.hypot(dx, dy)
    a = (R * R - r * r + d * d) / (2 * d)
    h = math.sqrt(max(0, R * R - a * a))
    px, py = O[0] + a * dx / d, O[1] + a * dy / d
    x1 = (px + h * dy / d, py - h * dx / d)
    x2 = (px - h * dy / d, py + h * dx / d)

    def arc(C, rad, s, e, away):
        a0 = math.atan2(s[1] - C[1], s[0] - C[0])
        a1 = math.atan2(e[1] - C[1], e[0] - C[0])
        ccw = (a1 - a0) % (2 * math.pi)
        through = (away - a0) % (2 * math.pi)
        delta = ccw if through < ccw else ccw - 2 * math.pi
        return "A %s %s 0 %d %d %s" % (f(rad), f(rad), 1 if abs(delta) > math.pi else 0, 1 if delta > 0 else 0, pt(e))

    away_o = math.atan2(-dy, -dx)
    toward_o = math.atan2(-dy, -dx)
    return "M %s %s %s Z" % (pt(x1), arc(O, R, x1, x2, away_o), arc(I, r, x2, x1, toward_o))


def ring(cx, cy, rx, ry, ix, iy):
    o = "M %s %s A %s %s 0 1 0 %s %s A %s %s 0 1 0 %s %s Z" % (
        f(cx - rx), f(cy), f(rx), f(ry), f(cx + rx), f(cy), f(rx), f(ry), f(cx - rx), f(cy))
    i = "M %s %s A %s %s 0 1 0 %s %s A %s %s 0 1 0 %s %s Z" % (
        f(cx - ix), f(cy), f(ix), f(iy), f(cx + ix), f(cy), f(ix), f(iy), f(cx - ix), f(cy))
    return o + " " + i


def leaf_d(S, E, bend, w):
    mx, my = (S[0] + E[0]) / 2, (S[1] + E[1]) / 2
    dx, dy = E[0] - S[0], E[1] - S[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    c1 = (mx + nx * (bend + w), my + ny * (bend + w))
    c2 = (mx + nx * (bend - w), my + ny * (bend - w))
    mid = (mx + nx * bend, my + ny * bend)
    return "M %s Q %s %s Q %s %s Z" % (pt(S), pt(c1), pt(E), pt(c2), pt(S)), "M %s Q %s %s" % (pt(S), pt(mid), pt(E))


def spark_d(cx, cy, r, k=0.2):
    return ("M {x} {t} Q {a} {b} {rr} {y} Q {a} {c} {x} {bt} Q {d} {c} {l} {y} Q {d} {b} {x} {t} Z").format(
        x=f(cx), y=f(cy), t=f(cy - r), bt=f(cy + r), rr=f(cx + r), l=f(cx - r),
        a=f(cx + r * k), b=f(cy - r * k), c=f(cy + r * k), d=f(cx - r * k))


class Icon:
    def __init__(self, name, prefix="", mode="soft"):
        self.name = name
        self.p = (prefix + name).replace("_", "-")
        self.mode = mode
        self.paper = mode == "paper"
        self.ow = 0 if self.paper else W      # outline width (none on paper)
        self.vb = None                        # the view box (fit.json), else 0 0 128 128
        self.defs = []
        self.out = []
        self.k = 0

    # --- plumbing ---
    def nid(self):
        self.k += 1
        return "%s-%d" % (self.p, self.k)

    def add(self, s):
        self.out.append(s)

    def ln(self, c, line=None):
        if line:
            return INK if (self.mode == "ink" and line != "none") else line
        return INK if self.mode == "ink" else deep(c)

    def tone(self, c):
        """Paper mode: a colour a touch softer and warmer, like ink printed on the game's paper."""
        if not self.paper or not isinstance(c, str) or not c.startswith("#"):
            return c
        h, l, s = _hls(c)
        return mix(_from(h, l, s * 0.9), PAPER, 0.06)

    def rad(self, c, cx, cy, r, hi=0.45, lo=0.84):
        if self.paper:
            return self.tone(c)
        i = self.nid()
        self.defs.append(
            '<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">'
            '<stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></radialGradient>' % (i, f(cx), f(cy), f(r), lite(c, hi), c, shade(c, lo)))
        return "url(#%s)" % i

    def gb(self, c, x0, y0, x1, y1, hi=0.45, lo=0.84):
        w, h = x1 - x0, y1 - y0
        return self.rad(c, x0 + 0.3 * w, y0 + 0.26 * h, 0.95 * max(w, h), hi, lo)

    def lin(self, c1, c2, x1, y1, x2, y2):
        if self.paper:
            return self.tone(mix(c1, c2, 0.5))
        i = self.nid()
        self.defs.append(
            '<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">'
            '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
            % (i, f(x1), f(y1), f(x2), f(y2), c1, c2))
        return "url(#%s)" % i

    def clip(self, inner):
        i = self.nid()
        self.defs.append('<clipPath id="%s">%s</clipPath>' % (i, inner))
        return "url(#%s)" % i

    def _stroke(self, c, line, sw, noline):
        if noline or line == "none":
            return dict(stroke=None)
        return dict(stroke=self.ln(c, line), stroke_width=sw, stroke_linejoin="round", stroke_linecap="round")

    def _fill(self, c, g, box):
        if self.paper:
            return "none" if g == "none" else self.tone(c)
        if isinstance(g, tuple):
            return self.gb(c, *g)
        if g is True and box:
            return self.gb(c, *box)
        return g or c

    def _piece(self, t, a, c, fill, line, sw, noline, op):
        if not self.paper:
            self.add(tag(t, **a, fill=fill, opacity=op, **self._stroke(c, line, sw, noline)))
            return
        if fill == "none":
            return      # the outline pass over clipped details: cut paper has no outline
        if not noline:
            self._lifts([(t, a)], _light(fill))
        self.add(tag(t, **a, fill=fill, opacity=op))

    def _lifts(self, shapes, edge=False):
        """Paper mode: cut-outs cast a crisp little shadow (D-009, D-027); pale ones also get a faint
        edge, so white paper still shows on the game's cream paper."""
        self.add('<g opacity="%s" transform="translate(0 %s)">' % (f(SHADOW_OP), f(LIFT)))
        for t, a in shapes:
            self.add(tag(t, **a, fill=INK))
        self.add("</g>")
        if edge:
            self.add('<g opacity="%s">' % f(EDGE_OP))
            for t, a in shapes:
                self.add(tag(t, **a, fill=INK, stroke=INK, stroke_width=2 * EDGE_W, stroke_linejoin="round"))
            self.add("</g>")

    # --- shapes ---
    def P(self, d, c, g=None, line=None, sw=W, noline=False, op=None, **a):
        self._piece("path", dict(d=d, **a), c, self._fill(c, g, None), line, sw, noline, op)

    def C(self, cx, cy, r, c, g=None, line=None, sw=W, noline=False, op=None, **a):
        self._piece("circle", dict(cx=cx, cy=cy, r=r, **a), c, self._fill(c, g, (cx - r, cy - r, cx + r, cy + r)),
                    line, sw, noline, op)

    def E(self, cx, cy, rx, ry, c, g=None, line=None, sw=W, noline=False, rot=None, op=None, **a):
        tr = "rotate(%s %s %s)" % (f(rot), f(cx), f(cy)) if rot else None
        self._piece("ellipse", dict(cx=cx, cy=cy, rx=rx, ry=ry, transform=tr, **a), c,
                    self._fill(c, g, (cx - rx, cy - ry, cx + rx, cy + ry)), line, sw, noline, op)

    def R(self, x, y, w, h, c, rx=0, g=None, line=None, sw=W, noline=False, op=None, **a):
        self._piece("rect", dict(x=x, y=y, width=w, height=h, rx=rx or None, **a), c,
                    self._fill(c, g, (x, y, x + w, y + h)), line, sw, noline, op)

    def tube(self, d, c, w, line=None, sw=W, dash=None, dashc=None, noline=False, cap="round"):
        if self.paper:
            if not noline:
                self.add('<g opacity="%s" transform="translate(0 %s)">' % (f(SHADOW_OP), f(LIFT)))
                self.add(tag("path", d=d, fill="none", stroke=INK, stroke_width=w, stroke_linecap=cap,
                             stroke_linejoin="round"))
                self.add("</g>")
                if _light(self.tone(c)):
                    self.add(tag("path", d=d, fill="none", stroke=INK, stroke_width=w + 2 * EDGE_W, stroke_linecap=cap,
                                 stroke_linejoin="round", opacity=EDGE_OP))
            self.add(tag("path", d=d, fill="none", stroke=self.tone(c), stroke_width=w, stroke_linecap=cap,
                         stroke_linejoin="round"))
            if dash:
                self.add(tag("path", d=d, fill="none", stroke=self.tone(dashc), stroke_width=w - W,
                             stroke_dasharray=dash, stroke_linecap="butt"))
            return
        if not noline:
            self.add(tag("path", d=d, fill="none", stroke=self.ln(c, line), stroke_width=w + sw,
                         stroke_linecap=cap, stroke_linejoin="round"))
        self.add(tag("path", d=d, fill="none", stroke=c, stroke_width=w - (0 if noline else sw),
                     stroke_linecap=cap, stroke_linejoin="round"))
        if dash:
            self.add(tag("path", d=d, fill="none", stroke=dashc, stroke_width=w - sw,
                         stroke_dasharray=dash, stroke_linecap="butt"))

    def stroke(self, d, c, w=2.4, op=None, cap="round"):
        if self.paper and c.lower() == "#ffffff" and op is not None and op < 0.8:
            return      # a shine: paper has none
        self.add(tag("path", d=d, fill="none", stroke=c, stroke_width=w, stroke_linecap=cap,
                     stroke_linejoin="round", opacity=op))

    def blob(self, shapes, c, g=None, line=None, sw=W):
        """Shapes merged into one, with one outline round the lot (on paper: one cut-out)."""
        if self.paper:
            self._lifts(shapes, _light(self.tone(c)))
            for t, a in shapes:
                self.add(tag(t, **a, fill=self.tone(c)))
            return
        L = self.ln(c, line)
        for t, a in shapes:
            self.add(tag(t, **a, fill=L, stroke=L, stroke_width=2 * sw, stroke_linejoin="round"))
        fill = self.gb(c, *g) if isinstance(g, tuple) else (g or c)
        for t, a in shapes:
            self.add(tag(t, **a, fill=fill))

    def group(self, **a):
        self.add("<g %s>" % " ".join('%s="%s"' % (k.replace("_", "-"), v) for k, v in a.items()))

    def end(self):
        self.add("</g>")

    # --- the style's details ---
    def shadow(self, cx=64, cy=115, rx=30, ry=4.5):
        if self.paper:
            return      # on paper each cut-out casts its own shadow instead
        self.add(tag("ellipse", cx=cx, cy=cy, rx=rx, ry=ry, fill="#3a2a1f", opacity=0.14))

    def gloss(self, cx, cy, rx, ry, rot=-30, op=0.6):
        if self.paper:
            return
        self.add(tag("ellipse", cx=cx, cy=cy, rx=rx, ry=ry, fill="#ffffff", opacity=op,
                     transform="rotate(%s %s %s)" % (f(rot), f(cx), f(cy))))

    def eye(self, x, y, e=3.3, kind="dot"):
        lw = max(1.8, e * 0.66)
        if kind == "dot":
            self.add(tag("ellipse", cx=x, cy=y, rx=e * 0.86, ry=e * 1.1, fill=INK))
            self.add(tag("circle", cx=x - e * 0.28, cy=y - e * 0.45, r=e * 0.36, fill="#ffffff"))
        elif kind == "sleep":
            self.stroke("M %s %s Q %s %s %s %s" % (f(x - e), f(y - e * 0.3), f(x), f(y + e * 1.0), f(x + e), f(y - e * 0.3)), INK, lw)
        elif kind == "happy":
            self.stroke("M %s %s Q %s %s %s %s" % (f(x - e), f(y + e * 0.5), f(x), f(y - e * 1.0), f(x + e), f(y + e * 0.5)), INK, lw)

    def blush(self, x, y, e=3.3):
        self.add(tag("ellipse", cx=x, cy=y, rx=e * 1.25, ry=e * 0.72, fill=BLUSH, opacity=0.55))

    def mouth(self, x, y, m, kind="smile", lw=2.2):
        if kind == "smile":
            self.stroke("M %s %s Q %s %s %s %s" % (f(x - m), f(y), f(x), f(y + m * 0.9), f(x + m), f(y)), INK, lw)
        elif kind == "w":
            self.stroke("M %s %s Q %s %s %s %s Q %s %s %s %s" % (
                f(x - m), f(y), f(x - m / 2), f(y + m * 0.85), f(x), f(y),
                f(x + m / 2), f(y + m * 0.85), f(x + m), f(y)), INK, lw)
        elif kind == "open":
            self.add(tag("path", d="M %s %s Q %s %s %s %s Q %s %s %s %s Z" % (
                f(x - m), f(y), f(x), f(y + m * 1.6), f(x + m), f(y), f(x), f(y + m * 0.25), f(x - m), f(y)),
                fill="#d9576b", stroke=INK, stroke_width=lw * 0.9, stroke_linejoin="round"))

    def face(self, x, y, gap=20, eye=3.3, mouth="smile", blush=True, eyes="dot", nose=None, bdx=None, bdy=None, mw=None):
        e = eye
        lw = max(1.8, e * 0.66)
        for sx in (-1, 1):
            self.eye(x + sx * gap / 2, y, e, eyes)
        dy = e * 1.55
        if nose:
            self.add(tag("ellipse", cx=x, cy=y + dy - 0.2, rx=e * 0.62, ry=e * 0.45, fill=nose))
            dy += e * 0.8
        if mouth and mouth != "none":
            self.mouth(x, y + dy, mw or e * 1.2, mouth, lw)
        if blush:
            bx = bdx if bdx is not None else gap / 2 + e * 1.55
            by = y + (bdy if bdy is not None else e * 1.5)
            for sx in (-1, 1):
                self.blush(x + sx * bx, by, e)

    def svg(self, px=128, label=None, board=False):
        vb = " ".join(f(v) for v in self.vb) if self.vb else "0 0 128 128"
        head = '<svg %sviewBox="%s" width="%s" height="%s"%s>' % (
            "" if board else 'xmlns="http://www.w3.org/2000/svg" ', vb, px, px,
            (' role="img" aria-label="%s"' % label) if label else (' aria-hidden="true"' if board else ""))
        lines = [head]
        if self.defs:
            lines.append("<defs>")
            lines.extend(self.defs)
            lines.append("</defs>")
        lines.extend(self.out)
        lines.append("</svg>")
        return "\n".join(lines) + "\n"
