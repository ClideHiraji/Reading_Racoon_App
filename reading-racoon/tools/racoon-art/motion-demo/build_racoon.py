"""Build the moving Racoon from the hand-edited Inkscape drawing (D-024).

    python build_racoon.py

Reads   ../parts/racoon_C_inkscape.svg   the drawing, edited by hand in Inkscape; never written here
        ../closet/<folder>/<id>.svg      his Closet items (FR-07, D-026), one Inkscape file each, drawn to fit;
                                         also never written (see ../closet/README.md)
        ../../../content/closet.json     the Closet's catalogue: each item's name, slot, tier, price, recolours
        Motion.template.dc.html          the demo board without a Racoon
Writes  Motion.dc.html                   the demo board: the drawing as a turnable puppet
        ../out/parts/                    every part on its own (<part>.svg, parts.json) and
                                         racoon_rest.svg, the parts put back together
        the game's assets/racoon/        racoon_rig.json, racoon_atlas.svg (Racoon) and closet/<folder>.svg
                                         (the Closet, one sheet per slot)

What the drawing must hold (layer > object labels; the rest is ignored):
  Tail   > Tail > Fur, Ring 1..n
  Body   > Foot left, Foot right, and two unlabelled paths: the body (larger) and the belly
  Arms   > Arm left, Arm right: groups of shapes; the one labelled "paw" is the paw
  Head   > Ear left, Ear right (Outer, Inner), Head, Head shine
  Face   > Brow left, Brow right, Mask, Eye left, Eye right (White, Pupil, then glints),
           Blush left, Blush right, Muzzle, Nose (Nose, Shine), Mouth (smile)
Left and right are as you look at him. The Expressions and Poses layers are not read: the demo
draws his blink, happy eyes and other mouths itself, and moves the drawn arms.

Each Closet file draws its item on a layer labelled "Item". Two are read by the demo boards too:
  neck/scarf_teal.svg  Band, Stripe (squeeze with his neck), and the rest (Knot, ends), which travel
                       round his neck with the knot. Every item marked "scarf" in the catalogue is
                       drawn this way.
  paws/open_book.svg   Cover (its left and right edges are where his paws hold it), and the rest.
A paws item's "Back view" group (or the open book's Cover) is what shows when he turns his back.
"""
import json
import math
import os
import re

import numpy as np
from matplotlib.path import Path as MplPath
from PIL import Image, ImageDraw
from scipy.optimize import minimize

import racoon_design as R

HERE = os.path.dirname(os.path.abspath(__file__))
ART_DIR = os.path.dirname(HERE)
SRC = os.path.join(ART_DIR, "parts", "racoon_C_inkscape.svg")
CLOSET_DIR = os.path.join(ART_DIR, "closet")
CATALOG = os.path.normpath(os.path.join(ART_DIR, "..", "..", "content", "closet.json"))
CATALOG = os.environ.get("RACOON_CLOSET_CATALOG", CATALOG)   # a scratch copy, for testing
TEMPLATE = os.path.join(HERE, "Motion.template.dc.html")
BOARD = os.path.join(HERE, "Motion.dc.html")
# Racoon in the game: the laptop lesson screen, built on the Motion board's script (its moves and
# rig), with the game's moments added on top
INGAME_TEMPLATE = os.path.join(HERE, "InGame.template.dc.html")
INGAME_BOARD = os.path.join(HERE, "InGame.dc.html")
OUT = os.path.join(ART_DIR, "out", "parts")

# How the flat drawing sits in depth, for turning him. These are not in the drawing.
HEAD_R = (108.0, 92.0)             # his head as a ball: half-width, half-height (and depth)
EAR_Z = 23.2                       # the ears sit this far forward of the middle of his head
NECK_R = 50.0                      # the scarf knot travels round his neck at this radius
BOOK_Z = 70.0                      # he holds the book this far in front of his middle
TAIL_Z = (-40.0, -100.0, -72.0)    # the tail's depth at its base, bend and tip: it curls up behind him
TAIL_START = (232.5, 326.0, 340.5, 340.0, 322.5, 206.0, 20.0, 40.0, 24.0)   # first guess for its centre line


def r2(v):
    return round(float(v), 2)


def H(name):
    return "{{ r.%s }}" % name


def one_poly(part, step):
    polys = R.sample(part.page, step)
    if len(polys) != 1:
        raise SystemExit("'%s' must be one closed shape; it has %d pieces." % (" / ".join(part.chain), len(polys)))
    return polys[0]


def paint(part, grad_id=None, round_joins=False):
    """The object's fill, outline and opacity as SVG attributes."""
    a = []
    fill = part.get("fill", "#000000")
    a.append('fill="%s"' % ("url(#%s)" % grad_id if fill.startswith("url(") else fill))
    if part.get("fill-opacity", "1") not in ("1", "1.0"):
        a.append('fill-opacity="%s"' % part.get("fill-opacity"))
    if part.stroke_width > 0.05:
        a.append('stroke="%s" stroke-width="%s"' % (part.get("stroke"), R.fmt(part.stroke_width)))
        join = "round" if round_joins else part.get("stroke-linejoin")
        if join:
            a.append('stroke-linejoin="%s"' % join)
        if part.get("stroke-linecap"):
            a.append('stroke-linecap="%s"' % part.get("stroke-linecap"))
    if part.opacity < 1:
        a.append('opacity="%s"' % R.fmt(part.opacity))
    return " ".join(a)


def box_centre(part):
    x0, y0, x1, y1 = R.bbox(part.page)
    return ((x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2)


def shape(part):
    if len(part.page) != 1:
        raise SystemExit("'%s' must be one closed shape." % " / ".join(part.chain))
    segs = part.page[0]["segs"]
    return {"m": [r2(segs[0][0][0]), r2(segs[0][0][1])], "c": [[r2(v) for q in s[1:] for v in q] for s in segs]}


# --- the tail: a centre line through the drawn tail, and each outline point's place along it ---

def qbez(p0, p1, p2, t):
    u = 1 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def tube(v, n=40):
    p0, p1, p2, (r0, rm, rt) = v[0:2], v[2:4], v[4:6], v[6:9]
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        q, f, o = qbez(p0, p1, p2, t), qbez(p0, p1, p2, min(1, t + 0.01)), qbez(p0, p1, p2, max(0, t - 0.01))
        dx, dy = f[0] - o[0], f[1] - o[1]
        ln = math.hypot(dx, dy) or 1
        r = r0 + (rm - r0) * math.sin(math.pi * min(t, 0.75) / 1.5) ** 1.2
        if t > 0.75:
            r = r * (1 - t) + rt * t
        r = max(r, 2)
        left.append((q[0] - dy / ln * r, q[1] + dx / ln * r))
        right.append((q[0] + dy / ln * r, q[1] - dx / ln * r))
    a0 = math.atan2(left[-1][1] - q[1], left[-1][0] - q[0])
    cap = [(q[0] + math.cos(a0 - math.pi * k / 9) * r, q[1] + math.sin(a0 - math.pi * k / 9) * r) for k in range(1, 9)]
    return left + cap + right[::-1]


def raster(poly, k=2):
    im = Image.new("L", (400 * k, 400 * k), 0)
    ImageDraw.Draw(im).polygon([(x * k, y * k) for x, y in poly], fill=255)
    return np.asarray(im) > 0


def fit_spine(fur_poly):
    """The centre line of a tube that best covers the drawn tail (by overlap)."""
    target = raster(fur_poly)

    def miss(v):
        m = raster(tube(v))
        return 1 - (m & target).sum() / max(1, (m | target).sum())
    best = minimize(miss, TAIL_START, method="Nelder-Mead", options={"xatol": 0.05, "fatol": 1e-5, "maxiter": 2500})
    v = list(best.x)
    return [v[0:2], v[2:4], v[4:6]], 1 - best.fun, [max(2.0, r) for r in v[6:9]]


def skin(poly, spine, n=800):
    """Each point as (t along the centre line, offset along it, offset across it)."""
    ts = [j / (n - 1) for j in range(n)]
    cs = [qbez(spine[0], spine[1], spine[2], t) for t in ts]
    out = []
    for p in poly:
        j = min(range(n), key=lambda i: (cs[i][0] - p[0]) ** 2 + (cs[i][1] - p[1]) ** 2)
        t, u = ts[j], 1 - ts[j]
        tx = 2 * u * (spine[1][0] - spine[0][0]) + 2 * t * (spine[2][0] - spine[1][0])
        ty = 2 * u * (spine[1][1] - spine[0][1]) + 2 * t * (spine[2][1] - spine[1][1])
        ln = math.hypot(tx, ty)
        tx, ty = tx / ln, ty / ln
        dx, dy = p[0] - cs[j][0], p[1] - cs[j][1]
        out.append([round(t, 4), r2(dx * tx + dy * ty), r2(-dx * ty + dy * tx)])
    return out


# --- the arms: each one's shapes measured along the line from shoulder to paw tip -------------

def arm(parts, side, ax):
    sleeve = [p for p in parts if p.label not in ("paw", "outline")][0]
    paw = [p for p in parts if p.label == "paw"]
    pts = np.array(one_poly(sleeve, 1.0))
    c = pts.mean(axis=0)
    w, v = np.linalg.eigh(np.cov((pts - c).T))
    e = v[:, int(np.argmax(w))]
    if paw:
        # point from the shoulder toward the paw, however the arm is drawn (out, down, up)
        if (np.array(one_poly(paw[0], 2.0)).mean(axis=0) - c) @ e < 0:
            e = -e
    elif (c[0] - ax) * e[0] < 0:
        e = -e
    n = np.array([-e[1], e[0]])
    polys = [np.array(one_poly(p, 2.0)) for p in parts]
    u_sleeve = (pts - c) @ e
    u_in, u_tip = u_sleeve.min(), max(((q - c) @ e).max() for q in polys)
    near = pts[u_sleeve < u_in + 12]
    half = np.abs((near - c) @ n).max()                   # half the sleeve's width at the shoulder end
    s = c + e * (u_in + half)                             # the shoulder: where the arm turns
    length = u_tip - (u_in + half)
    if paw:
        up = (np.array(one_poly(paw[0], 2.0)) - s) @ e
        u_paw, u_pc = up.min(), (up.min() + up.max()) / 2
    else:
        u_paw, u_pc = 0.7 * length, 0.85 * length
    return {"side": side, "S": [r2(s[0] - ax), r2(s[1])], "len": r2(length), "elev": round(math.atan2(e[1], e[0] * side), 4),
            "uPaw": r2(u_paw), "uPc": r2(u_pc), "half": r2(half),
            "parts": [[[r2((q - s) @ e), r2((q - s) @ n)] for q in poly] for poly in polys]}


# --- the build ---------------------------------------------------------------------------------

def build():
    D = R.Design(SRC)
    defs, art, report = [], {}, []
    gx = {}   # the parts the game (Godot) needs as textures, collected on the way

    def grad(part, gid, drawn=None):
        g = D.gradient_markup(part, gid, drawn)
        if g:
            defs.append(g)
        return gid

    # head, ears, shine
    head = D.find("Head", "Head")
    hx, hy, _, _ = box_centre(head)
    HC = (r2(hx), r2(hy))
    art["ax"], art["head"] = HC[0], {"c": list(HC), "r": list(HEAD_R), "pivot": [HC[0], r2(hy + 88)]}
    AX = HC[0]
    head_d = R.path_d(head.page)
    defs.append('<clipPath id="rr-head-clip"><path d="%s"></path></clipPath>' % head_d)
    defs.append('<clipPath id="rr-body-clip"><path d="%s"></path></clipPath>' % H("bodyD"))
    art["ears"], ear_mk, ear_cut = [], {}, {}
    head_outline = MplPath(np.array(R.sample(head.page, 0.5)[0]))
    for key, name, side in (("earL", "Ear left", -1), ("earR", "Ear right", 1)):
        outer, inner = D.find("Head", name, "Outer"), D.find("Head", name, "Inner")
        m = outer.matrix
        sc = math.sqrt(abs(m[0] * m[3] - m[1] * m[2]))
        own = (sc, 0, 0, sc, 0, 0)
        ox, oy = m[4] - HC[0], m[5] - HC[1]
        # where the ear meets the head outline: when the ear swings round to the front of his
        # head, its copy in front of the head is cut along this line (its base, sunk in the fur)
        ep = np.array(R.sample(outer.page, 0.5)[0])
        inside = np.array([head_outline.contains_point(q) for q in ep])
        cross = [(ep[i] + ep[i - 1]) / 2 for i in range(len(ep)) if inside[i] != inside[i - 1]]
        if len(cross) == 2 and (~inside).any():
            def local(q):
                dx, dy = q[0] - m[4], q[1] - m[5]
                return np.array([(m[0] * dx + m[1] * dy) / sc, (m[2] * dx + m[3] * dy) / sc])
            p1, p2, seen = local(cross[0]), local(cross[1]), local(ep[~inside].mean(axis=0))
            u = (p2 - p1) / np.linalg.norm(p2 - p1)
            nv = np.array([-u[1], u[0]])
            if (seen - p1) @ nv < 0:
                nv = -nv
            b = (p1 + p2) / 2 - nv * 2.0                   # a little below, tucked under the head's outline
            quad = [b - u * 400, b + u * 400, b + u * 400 + nv * 400, b - u * 400 + nv * 400]
            # how far the head's dome rises above that line inside the ear: the cut starts there
            # (showing only what's already visible) and slides down to the base as the ear comes forward
            hl = np.array([local(q) for q in R.sample(head.page, 0.5)[0]])
            along = (hl - p1) @ u
            span = (along > 0) & (along < np.linalg.norm(p2 - p1))
            rise = float(((hl[span] - b) @ nv).max()) if span.any() else 0.0
            # the base blends into the head's fur over a few px instead of a hard cut
            f1, f2 = b, b + nv * 9
            defs.append('<linearGradient id="rr-%s-fade" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">'
                        '<stop offset="0" stop-color="#000000"></stop><stop offset="1" stop-color="#ffffff"></stop></linearGradient>' % (
                            key, R.fmt(f1[0]), R.fmt(f1[1]), R.fmt(f2[0]), R.fmt(f2[1])))
            defs.append('<mask id="rr-%s-cut" maskUnits="userSpaceOnUse" x="-300" y="-300" width="600" height="600">'
                        '<path d="M %s Z" fill="url(#rr-%s-fade)" transform="translate(%s %s)"></path></mask>' % (
                            key, " L ".join("%s %s" % (R.fmt(q[0]), R.fmt(q[1])) for q in quad), key, H(key + ".cx"), H(key + ".cy")))
            ear_cut[key] = [round(float(nv[0]), 4), round(float(nv[1]), 4), r2(rise)]
            ear_cut[key + "line"] = [r2(b[0]), r2(b[1]), round(float(u[0]), 4), round(float(u[1]), 4)]
        art["ears"].append({"side": side, "off": [r2(ox), r2(oy)], "lam0": round(math.atan2(ox, EAR_Z), 4),
                            "R": r2(math.hypot(ox, EAR_Z)), "tilt": r2(math.degrees(math.atan2(m[1], m[0]))),
                            "cut": ear_cut.get(key) or [0, 0, 0], "cutLine": ear_cut.get(key + "line") or [0, 0, 1, 0]})
        gx.setdefault("ears", []).append((key, outer, inner, own))
        ear_mk[key] = ('<path d="%s" %s></path>' % (R.path_d(R.transform_subs(outer.local, own)), paint(outer, grad(outer, "rr-g-" + key, own))) +
                       '<path d="%s" %s opacity="%s" transform="%s"></path>' % (
                           R.path_d(R.transform_subs(inner.local, own)), paint(inner), H(key + ".inner"), H(key + ".innerT")))
    shine = D.find("Head", "Head shine")

    # face: shapes painted on the head, measured from its centre
    def decal(part):
        pts = [[r2(x - HC[0]), r2(y - HC[1])] for x, y in one_poly(part, 2.2)]
        cx, cy, _, _ = box_centre(part)
        q = max(-0.995, min(0.995, (cy - HC[1]) / HEAD_R[1]))
        ring = HEAD_R[0] * math.sqrt(1 - q * q)
        return {"pts": pts, "lam": round(math.asin(max(-1, min(1, (cx - HC[0]) / ring))), 4)}
    mask = D.find("Face", "Mask")
    art["mask"] = decal(mask)
    brows = [D.find("Face", "Brow left"), D.find("Face", "Brow right")]
    art["brows"] = [decal(b) for b in brows]
    art["eyes"], eye_mk = [], {}
    for key, name in (("eyeL", "Eye left"), ("eyeR", "Eye right")):
        ps = [p for p in D.parts("Face") if p.chain[0] == name]
        white, pupil = D.find("Face", name, "White"), D.find("Face", name, "Pupil")
        glints = [p for p in ps if p is not white and p is not pupil]
        wx, wy, wr, _ = box_centre(white)
        px, py, pr, _ = box_centre(pupil)
        gs = [box_centre(g) for g in glints]
        art["eyes"].append({"c": [r2(wx - HC[0]), r2(wy - HC[1])], "r": r2(wr), "pupil": [r2(px - wx), r2(py - wy), r2(pr)],
                            "glints": [[r2(g[0] - px), r2(g[1] - py), r2(g[2])] for g in gs]})
        k = wr / 15.64
        mk = '<g opacity="%s"><g display="%s">' % (H(key + ".op"), H(key + ".openDisp"))
        mk += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s></ellipse>' % (H(key + ".cx"), H(key + ".cy"), H(key + ".rx"), R.fmt(wr), paint(white))
        mk += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s></ellipse>' % (H(key + ".px"), H(key + ".py"), H(key + ".prx"), R.fmt(pr), paint(pupil))
        for j, g in enumerate(glints):
            mk += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s></ellipse>' % (
                H("%s.g%dx" % (key, j)), H("%s.g%dy" % (key, j)), H("%s.g%dr" % (key, j)), R.fmt(gs[j][2]), paint(g))
        mk += '</g>'
        for kind, width in (("closed", 5.0), ("happy", 5.5)):
            mk += '<path d="%s" display="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"></path>' % (
                H("%s.%s" % (key, kind)), H("%s.%sDisp" % (key, kind)), white.get("fill"), R.fmt(width * k))
        eye_mk[key] = mk + '</g>'
    art["blush"], blush_mk = [], {}
    for key, name in (("blushL", "Blush left"), ("blushR", "Blush right")):
        b = D.find("Face", name)
        bx, by, brx, bry = box_centre(b)
        art["blush"].append({"c": [r2(bx - HC[0]), r2(by - HC[1])], "rx": r2(brx), "ry": r2(bry), "op": r2(b.opacity * float(b.get("fill-opacity", "1")))})
        blush_mk[key] = '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity="%s"></ellipse>' % (
            H(key + ".cx"), H(key + ".cy"), H(key + ".rx"), R.fmt(bry), b.get("fill"), H(key + ".op"))
    muzzle = D.find("Face", "Muzzle")
    mx, my, mrx, mry = box_centre(muzzle)
    art["muzzle"] = {"c": [r2(mx - HC[0]), r2(my - HC[1])], "rx": r2(mrx), "ry": r2(mry)}
    nose, nshine = D.find("Face", "Nose", "Nose"), D.find("Face", "Nose", "Shine")
    nx, ny, nrx, nry = box_centre(nose)
    sx, sy, srx, sry = box_centre(nshine)
    art["nose"] = {"c": [r2(nx - HC[0]), r2(ny - HC[1])], "rx": r2(nrx), "ry": r2(nry), "shine": [r2(sx - nx), r2(sy - ny), r2(srx), r2(sry)]}
    mouth = D.find("Face", "Mouth (smile)")
    art["mouth"] = [[r2(x - HC[0]), r2(y - HC[1])] for x, y in R.sample(mouth.page, 2.0)[0]]

    # body, belly, feet
    solid = sorted([p for p in D.parts("Body") if p.tag == "path"], key=lambda p: -(R.bbox(p.page)[2] - R.bbox(p.page)[0]))
    if len(solid) < 2:
        raise SystemExit("The Body layer needs two paths: the body and the belly.")
    body, belly = solid[0], solid[1]
    bx0, _, bx1, _ = R.bbox(body.page)
    cx, _, hw, _ = box_centre(belly)
    art["body"], art["bodyHalf"] = shape(body), r2(max(AX - bx0, bx1 - AX))
    art["bodyLine"] = r2(body.stroke_width)        # the body's outline width (the game joins arms to it)
    art["belly"] = {"cx": r2(cx - AX), "hw": r2(hw), "shape": shape(belly)}
    feet = [D.find("Body", "Foot left"), D.find("Body", "Foot right")]
    art["feet"], foot_mk = [], {}
    for key, f in zip(("footL", "footR"), feet):
        fx, fy, frx, fry = box_centre(f)
        art["feet"].append({"x": r2(fx - AX), "y": r2(fy), "rx": r2(frx)})
        foot_mk[key] = 'cx="%s" cy="%s" rx="%s" ry="%s" %s' % (H(key + ".cx"), H(key + ".cy"), H(key + ".rx"), R.fmt(fry), paint(f, grad(f, "rr-g-" + key)))
    art["ground"] = r2(max(a["y"] for a in art["feet"]) + 7)
    art["shadowRx"] = 96

    # tail
    tparts = [p for p in D.parts("Tail")]
    fur = D.find("Tail", "Tail", "Fur")
    spine, overlap, tail_radii = fit_spine(one_poly(fur, 1.5))
    report.append("tail centre line: %s, covering %.1f%% of the drawn tail" % ([[r2(v) for v in q] for q in spine], overlap * 100))
    art["tail"] = {"spine": [[r2(v) for v in q] for q in spine], "z": list(TAIL_Z), "radii": [r2(v) for v in tail_radii],
                   "parts": [skin(one_poly(p, 2.0), spine) for p in tparts]}
    tail_mk = "".join('<path d="%s" %s></path>' % (H("tail.d%d" % j), paint(p, grad(p, "rr-g-tail%d" % j), True)) for j, p in enumerate(tparts))

    # arms
    art["arms"], arm_mk = [], {}
    for key, name, side in (("armL", "Arm left", -1), ("armR", "Arm right", 1)):
        ps = [p for p in D.parts("Arms") if p.chain[0] == name]
        if not ps:
            raise SystemExit("The Arms layer needs a group labelled '%s'." % name)
        art["arms"].append(arm(ps, side, AX))
        a = art["arms"][-1]
        report.append("%s: shoulder (%.1f, %.1f), %.1f px long, %.1f deg below level, paw from %.1f px" % (
            name, a["S"][0] + AX, a["S"][1], a["len"], math.degrees(a["elev"]), a["uPaw"]))
        # Joined to the body: the drawn outline ("outline") is hidden near the shoulder once the arm
        # swings away from its drawn pose (a mask, radius set by the rig), and wherever the arm's
        # root pokes out of the body it gets a rim like the drawn outline, so the arm always grows
        # out of the body with no gaps or stray lines.
        sj = [j for j, p in enumerate(ps) if p.label not in ("paw", "outline")][0]
        band = [p for p in ps if p.label == "outline"]
        rim_w, ink = 9.0, "#3b2d3a"
        if band:
            sl = np.array(one_poly(ps[sj], 1.0))
            sp = MplPath(sl)
            inner = [np.min(np.hypot(sl[:, 0] - q[0], sl[:, 1] - q[1])) for poly in R.sample(band[0].page, 1.0) for q in poly
                     if sp.contains_point(q)]
            rim_w, ink = 2 * float(np.percentile(inner, 95)), band[0].get("fill", ink)
        bits = []
        for j, p in enumerate(ps):
            mk = '<path d="%s" %s></path>' % (H("%s.d%d" % (key, j)), paint(p, None, True))
            bits.append('<g mask="url(#rr-%s-band)">%s</g>' % (key, mk) if p.label == "outline" else mk)
        bits.append('<g clip-path="url(#rr-%s-clip)" mask="url(#rr-out-body)"><path d="%s" fill="none" stroke="%s" stroke-width="%s" '
                    'stroke-linejoin="round"></path></g>' % (key, H("%s.d%d" % (key, sj)), ink, R.fmt(rim_w)))
        arm_mk[key] = "".join(bits)
        defs.append('<clipPath id="rr-%s-clip"><path d="%s"></path></clipPath>' % (key, H("%s.d%d" % (key, sj))))
        defs.append('<mask id="rr-%s-band" maskUnits="userSpaceOnUse" x="-300" y="-300" width="1000" height="1000">'
                    '<rect x="-300" y="-300" width="1000" height="1000" fill="#ffffff"></rect>'
                    '<circle cx="%s" cy="%s" r="%s" fill="#000000"></circle></mask>' % (key, H(key + ".mx"), H(key + ".my"), H(key + ".mr")))
        a["rim"], a["sleeve"] = r2(rim_w), sj        # the game draws the same rim round the sleeve (D-024)
        report.append("%s: outline %.1f px inside the sleeve edge" % (name, rim_w / 2))
    defs.append('<mask id="rr-out-body" maskUnits="userSpaceOnUse" x="-300" y="-300" width="1000" height="1000">'
                '<rect x="-300" y="-300" width="1000" height="1000" fill="#ffffff"></rect>'
                '<path d="%s" fill="#000000"></path></mask>' % H("bodyD"))

    def arm_slot(slot):
        return "".join('<g display="%s">%s</g>\n' % (H("%s.%s" % (k, slot)), arm_mk[k]) for k in ("armL", "armR"))

    # Closet items (FR-07): the River scarf and the open book, from their own files
    scarf_mk = book_full = book_back = ""
    art["scarf"] = art["book"] = None
    closet = load_closet()
    if closet:
        def shapes(design, parts, prefix):
            out = []
            for j, p in enumerate(parts):
                gid = "%s%d" % (prefix, j)
                g = design.gradient_markup(p, gid)
                if g:
                    defs.append(g)
                out.append('<path d="%s" %s></path>' % (R.path_d(p.page), paint(p, gid, True)))
            return "".join(out)
        scarf, book = closet["art"]["scarf_teal"], closet["art"]["open_book"]
        sc = scarf.parts("Item")
        band = [p for p in sc if p.label in ("Band", "Stripe")]
        rest = [p for p in sc if p not in band]
        knot = scarf.find("Item", "Knot")
        kx, ky, _, _ = box_centre(knot)
        _, by0, _, by1 = R.bbox(band[0].page)
        art["scarf"] = {"knot": [r2(kx - AX), r2(ky)], "neckR": NECK_R, "pivot": [AX, r2((by0 + by1) / 2)]}
        scarf_mk = '<g display="%s"><g transform="%s">%s</g><g transform="%s" display="%s">%s</g></g>' % (
            H("scarf.disp"), H("scarf.bandT"), shapes(scarf, band, "rr-g-scarf"), H("scarf.knotT"), H("scarf.knotDisp"),
            shapes(scarf, rest, "rr-g-knot"))
        bk = book.parts("Item")
        cover = book.find("Item", "Cover")
        cx0, cy0, cx1, cy1 = R.bbox(cover.page)
        art["book"] = {"x0": r2(cx0), "x1": r2(cx1), "y": r2((cy0 + cy1) / 2), "h": r2(cy1 - cy0), "z": BOOK_Z}
        book_full = shapes(book, bk, "rr-g-book")
        book_back = shapes(book, [cover], "rr-g-bookback")
        report.append("closet: scarf (%d shapes), book (%d shapes, held at x %.1f and %.1f)" % (len(sc), len(bk), cx0, cx1))

    def book_slot(slot, inner):
        return '<g display="%s" transform="%s">%s</g>' % (H("book." + slot), H("book.t"), inner) if inner else ""

    ear_l = '<g transform="%s" display="%%s">%s</g>\n' % (H("earL.t"), ear_mk["earL"])
    head_sw = head.stroke_width
    body_mk = "\n".join([
        '<g display="%s">%s</g>' % (H("tailBack"), tail_mk),
        book_slot("bb", book_back),
        arm_slot("b").rstrip(),
        '<ellipse display="%s" %s></ellipse>' % (H("footL.back"), foot_mk["footL"]),
        '<ellipse %s></ellipse>' % foot_mk["footR"],
        '<ellipse display="%s" %s></ellipse>' % (H("footL.front"), foot_mk["footL"]),
        '<path d="%s" %s></path>' % (H("bodyD"), paint(body)),
        '<g clip-path="url(#rr-body-clip)"><path d="%s" display="%s" %s></path></g>' % (H("bellyD"), H("bellyDisp"), paint(belly)),
        arm_slot("mb").rstrip(),                          # in front of his body but behind a nearer tail
        '<g display="%s">%s</g>' % (H("tailFront"), tail_mk),
        scarf_mk,
        book_slot("bm", book_full),
        arm_slot("m").rstrip(),
        '<g transform="%s">' % H("headT"),
        (ear_l % H("earL.back")).rstrip(),
        '<g transform="%s">%s</g>' % (H("earR.t"), ear_mk["earR"]),
        (ear_l % H("earL.front")).rstrip(),
        '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="%s" display="%s"></ellipse>' % (
            H("muz.cx"), H("muz.cy"), H("muz.rx"), R.fmt(mry), head.get("stroke"), R.fmt(head_sw * 2), H("muz.disp")),
        '<path d="%s" %s></path>' % (head_d, paint(head, grad(head, "rr-g-head"))),
        '<path d="%s" %s></path>' % (R.path_d(shine.page), paint(shine)),
        '<g clip-path="url(#rr-head-clip)">',
        '<path d="%s" %s></path>' % (H("browL"), paint(brows[0])),
        '<path d="%s" %s></path>' % (H("browR"), paint(brows[1])),
        '<path d="%s" %s></path>' % (H("maskD"), paint(mask, grad(mask, "rr-g-mask"))),
        eye_mk["eyeL"], eye_mk["eyeR"], blush_mk["blushL"], blush_mk["blushR"],
        '</g>',
        '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"></path>' % (head_d, head.get("stroke"), R.fmt(head_sw)),
        # an ear that swings round toward the front comes in front of his head (fades in)
        "".join('<g transform="%s" opacity="%s" display="%s">%s</g>' % (
            H(k + ".t"), H(k + ".fo"), H(k + ".fd"),
            ('<g mask="url(#rr-%s-cut)">%s</g>' % (k, ear_mk[k])) if ear_cut.get(k) else ear_mk[k]) for k in ("earL", "earR")),
        '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s display="%s"></ellipse>' % (
            H("muz.cx"), H("muz.cy"), H("muz.rx"), R.fmt(mry), paint(muzzle, grad(muzzle, "rr-g-muzzle")), H("muz.disp")),
        '<g display="%s">' % H("nose.disp"),
        '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s></ellipse>' % (H("nose.cx"), H("nose.cy"), H("nose.rx"), R.fmt(nry), paint(nose)),
        '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s></ellipse>' % (H("nose.sx"), H("nose.sy"), H("nose.srx"), R.fmt(sry), paint(nshine)),
        '</g>',
        '<g opacity="%s">' % H("mouth.op"),
        '<path d="%s" display="%s" %s></path>' % (H("mouth.w"), H("mouth.wDisp"), paint(mouth, None, True)),
        '<g display="%s"><path d="%s" fill="#6b2f36" stroke="#2d2430" stroke-width="2.8" stroke-linejoin="round"></path>'
        '<ellipse cx="%s" cy="%s" rx="%s" ry="3.7" fill="#e9801f"></ellipse></g>' % (H("mouth.happyDisp"), H("mouth.happy"), H("mouth.tx"), H("mouth.ty"), H("mouth.trx")),
        '<g display="%s"><path d="%s" fill="#6b2f36" stroke="#2d2430" stroke-width="2.8" stroke-linejoin="round"></path>'
        '<ellipse cx="%s" cy="%s" rx="%s" ry="2.6" fill="#e9801f"></ellipse></g>' % (H("mouth.openDisp"), H("mouth.open"), H("mouth.ox"), H("mouth.oy"), H("mouth.orx")),
        '<ellipse cx="%s" cy="%s" rx="%s" ry="5.5" fill="#6b2f36" display="%s"></ellipse>' % (H("mouth.ocx"), H("mouth.ocy"), H("mouth.ocrx"), H("mouth.oDisp")),
        '</g>',
        '</g>',
        book_slot("bf", book_full),
        arm_slot("f").rstrip(),
    ])
    body_mk = "\n".join(line for line in body_mk.split("\n") if line)

    motion = open(TEMPLATE, encoding="utf-8").read()
    a = motion.index("<script type=\"text/x-dc\" data-dc-script")
    base_script = motion[motion.index(">", a) + 1:motion.rindex("</script>")]
    boards = [(motion, BOARD, None)]
    if os.path.exists(INGAME_TEMPLATE):
        ingame = open(INGAME_TEMPLATE, encoding="utf-8").read()
        if ingame.count("/*RACOON:BASE*/") != 1:
            raise SystemExit("The in-game template must hold /*RACOON:BASE*/ exactly once.")
        # its own ids (ig-), in case the canvas shows both boards in one page
        boards.append((ingame.replace("/*RACOON:BASE*/", base_script), INGAME_BOARD, "ig-"))
    for tpl, path, prefix in boards:
        for marker, text in (("<!--RACOON:DEFS-->", "\n".join(defs)), ("<!--RACOON:BODY-->", body_mk),
                             ("/*RACOON:ART*/null", json.dumps(art, separators=(",", ":")))):
            if tpl.count(marker) != 1:
                raise SystemExit("%s must hold %s exactly once." % (os.path.basename(path), marker))
            tpl = tpl.replace(marker, text)
        if prefix:
            tpl = tpl.replace("rr-", prefix)
        open(path, "w", encoding="utf-8", newline="\n").write(tpl)
        report.append("wrote %s (%d KB)" % (path, len(tpl.encode("utf-8")) // 1024))
    report += export_parts(D, body, belly, closet)
    gx.update({"head": head, "shine": shine, "mask": mask, "brows": brows, "muzzle": muzzle, "nose": (nose, nshine),
               "mouth": mouth, "body": body, "belly": belly, "feet": feet, "tail": tparts,
               "arms": [(k, [p for p in D.parts("Arms") if p.chain[0] == n]) for k, n in (("armL", "Arm left"), ("armR", "Arm right"))],
               "eyes": [[p for p in D.parts("Face") if p.chain[0] == n] for n in ("Eye left", "Eye right")],
               "blush": [D.find("Face", "Blush left"), D.find("Face", "Blush right")]})
    report += export_godot(D, closet, art, gx)
    return report


# --- the game: Racoon's rig and textures for Godot (scenes/companion/raccoon.gd) ----------------

GODOT_RIG = os.path.join(os.path.dirname(ART_DIR), "..", "assets", "racoon", "racoon_rig.json")
GODOT_RIG = os.environ.get("RACOON_GODOT_RIG", GODOT_RIG)   # a scratch copy, for testing
# a recolour marked "rainbow" in closet.json: every gradient's stops become these stripes (D-026)
RAINBOW_STOPS = "".join('<stop offset="%s" stop-color="%s"/>' % sc for sc in (
    ("0", "#ff8fa3"), ("0.22", "#ffc46b"), ("0.42", "#fff07a"), ("0.6", "#8ee8a0"), ("0.8", "#7fd3ff"), ("1", "#b59bff")))
# how Godot imports a sheet: at twice the drawing's size, with mipmaps (written once, for a new sheet)
SHEET_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/racoon/%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=2.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
"""


def load_closet():
    """The Closet (D-026): its catalogue (content/closet.json) and each item's drawing,
    closet/<folder>/<id>.svg. Stops with a list of what doesn't match: an item without a drawing,
    a drawing that isn't in the catalogue, or a recolour of an item that doesn't exist."""
    if not os.path.exists(CATALOG):
        return None
    cat = json.load(open(CATALOG, encoding="utf-8"))
    items, folders = cat["items"], cat["folders"]
    drawings, problems = {}, []
    for iid, it in items.items():
        if it.get("drawn") == "code":
            continue   # a pet (D-029): scenes/companion/pet.gd draws it, so it has no file here
        if it.get("slot") not in folders:
            problems.append("%s: slot '%s' has no folder in closet.json" % (iid, it.get("slot")))
            continue
        if "recolor" in it:
            if it["recolor"].get("of") not in items or "recolor" in items[it["recolor"]["of"]]:
                problems.append("%s: recolours '%s', which isn't an item with its own drawing" % (iid, it["recolor"].get("of")))
            continue
        path = os.path.join(CLOSET_DIR, folders[it["slot"]], iid + ".svg")
        if not os.path.exists(path):
            problems.append("%s: no drawing at closet/%s/%s.svg" % (iid, folders[it["slot"]], iid))
            continue
        drawings[iid] = R.Design(path)
        if not drawings[iid].layers.get("Item", {}).get("parts"):
            problems.append("closet/%s/%s.svg: nothing drawn on its \"Item\" layer" % (folders[it["slot"]], iid))
    for folder in sorted(set(folders.values())):
        d = os.path.join(CLOSET_DIR, folder)
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if f.endswith(".svg") and not f.startswith("_") and f[:-4] not in items:
                problems.append("closet/%s/%s isn't in closet.json" % (folder, f))
    for need in ("scarf_teal", "open_book"):
        if need not in drawings:
            problems.append("%s: the demo boards need it" % need)
    if problems:
        raise SystemExit("The Closet doesn't add up:\n  " + "\n  ".join(problems))
    return {"items": items, "folders": folders, "art": drawings}


def _chunks(s, n=150):
    """A long string as short lines (the Godot editor chokes on very long lines in project files)."""
    return [s[i:i + n] for i in range(0, len(s), n)]


def export_godot(D, closet, art, gx):
    """Racoon for the game: the rig numbers (as on the boards) plus each part as a small SVG that
    Godot rasterises once at the size it shows him, and the colours of the parts it draws itself."""

    def svg(design, parts, drawn=None, stroke_only=False):
        defs, shapes = [], []
        x0 = y0 = 1e9
        x1 = y1 = -1e9
        for j, p in enumerate(parts):
            subs = R.transform_subs(p.local, drawn) if drawn else p.page
            if stroke_only:
                pnt = 'fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (p.get("stroke"), R.fmt(p.stroke_width))
            else:
                gid = "g%d" % j
                gm = design.gradient_markup(p, gid, drawn)
                if gm:
                    defs.append(gm.replace("></stop>", "/>"))
                pnt = paint(p, gid, True)
            shapes.append('<path d="%s" %s/>' % (R.path_d(subs), pnt))
            b, m = R.bbox(subs), p.stroke_width / 2 + 3
            x0, y0, x1, y1 = min(x0, b[0] - m), min(y0, b[1] - m), max(x1, b[2] + m), max(y1, b[3] + m)
        box = [math.floor(x0), math.floor(y0), math.ceil(x1) - math.floor(x0), math.ceil(y1) - math.floor(y0)]
        text = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" width="%d" height="%d"><defs>%s</defs>%s</svg>' % (
            box[0], box[1], box[2], box[3], box[2], box[3], "".join(defs), "".join(shapes))
        return {"box": box, "svg": _chunks(text)}

    def colour(p, key="fill"):
        return p.get(key, "#000000") if not str(p.get(key, "")).startswith("url(") else "#000000"

    tex = {"head": svg(D, [gx["head"], gx["shine"]]), "head_line": svg(D, [gx["head"]], stroke_only=True),
           "muzzle": svg(D, [gx["muzzle"]]), "mask": svg(D, [gx["mask"]]),
           "brow_l": svg(D, [gx["brows"][0]]), "brow_r": svg(D, [gx["brows"][1]]),
           "body": svg(D, [gx["body"]]), "belly": svg(D, [gx["belly"]]),
           "foot_l": svg(D, [gx["feet"][0]]), "foot_r": svg(D, [gx["feet"][1]]), "tail": svg(D, gx["tail"])}
    for key, outer, inner, own in gx["ears"]:
        tex[key] = svg(D, [outer], own)
        tex[key + "_in"] = svg(D, [inner], own)
    arms = []
    for (key, ps), A in zip(gx["arms"], art["arms"]):
        band = [p for p in ps if p.label == "outline"]
        tex[key + "_fill"] = svg(D, [p for p in ps if p.label != "outline"])
        if band:
            tex[key + "_band"] = svg(D, band)
        us = [q[0] for part in A["parts"] for q in part]
        vs = [abs(q[1]) for part in A["parts"] for q in part]
        arms.append({"uMin": r2(min(us) - 4), "uMax": r2(max(us) + 4), "vMax": r2(max(vs) + 4), "band": bool(band)})
    # The Closet (FR-07, D-026): every item from its own file, one texture each, named by its id. A
    # scarf is two, "<id>.band" and "<id>.knot"; a paws item also has "<id>.back", seen when he turns
    # his back. A recolour in closet.json copies another item's textures with its colours swapped.
    closet_tex, tex_slot = {}, {}

    def profile(parts, box, step=4.0):
        """How wide the item is at each height, from his middle (drawing units, every `step` down its
        box): the game wraps hats and neck items round a shape this wide, so they turn in 3D."""
        pts = []
        for p in parts:
            m = p.stroke_width / 2
            for poly in R.sample(p.page, 1.5):
                pts += [(abs(x - art["ax"]) + m, y) for x, y in poly]
        rows, y = [], float(box[1])
        while y <= box[1] + box[3] + 0.01:
            near = [r for r, py in pts if abs(py - y) <= step * 0.75]
            rows.append(max(near) if near else None)
            y += step
        known = [i for i, r in enumerate(rows) if r is not None]
        rows = [r if r is not None else rows[min(known, key=lambda k: abs(k - i))] for i, r in enumerate(rows)]
        return {"axis": art["ax"], "y0": box[1], "step": step, "r": [r2(max(6.0, r)) for r in rows]}

    if closet:
        items = closet["items"]
        for iid, d in closet["art"].items():
            parts = d.parts("Item")
            front = [p for p in parts if "Back view" not in p.chain]
            back = [p for p in parts if "Back view" in p.chain] or [p for p in parts if p.label == "Cover"]
            got = {}
            if items[iid].get("scarf"):
                band = [p for p in front if p.label in ("Band", "Stripe")]
                got = {".band": svg(d, band), ".knot": svg(d, [p for p in front if p not in band])}
            else:
                got = {"": svg(d, front)}
                if back and (items[iid]["slot"] == "paws" or any("Back view" in p.chain for p in parts)):
                    got[".back"] = svg(d, back)
                if items[iid]["slot"] in ("hat", "neck"):
                    got[""]["profile"] = profile(front, got[""]["box"])
                    if ".back" in got:
                        got[".back"]["profile"] = profile(back, got[".back"]["box"])
            for suffix, t in got.items():
                closet_tex[iid + suffix] = t
                tex_slot[iid + suffix] = items[iid]["slot"]
        for iid, it in items.items():
            rc = it.get("recolor")
            if not rc:
                continue
            for suffix in ("", ".band", ".knot", ".back"):
                base = rc["of"] + suffix
                if base not in closet_tex:
                    continue
                t = "".join(closet_tex[base]["svg"])
                for a, b in rc.get("colors", {}).items():
                    t = t.replace(a, b)
                if rc.get("rainbow"):
                    t = re.sub(r"(<linearGradient[^>]*>).*?(</linearGradient>)", lambda m: m.group(1) + RAINBOW_STOPS + m.group(2), t)
                closet_tex[iid + suffix] = {"box": closet_tex[base]["box"], "svg": _chunks(t)}
                if "profile" in closet_tex[base]:
                    closet_tex[iid + suffix]["profile"] = closet_tex[base]["profile"]
                tex_slot[iid + suffix] = it["slot"]
    nose, nshine = gx["nose"]
    eyes = []
    for parts in gx["eyes"]:
        white, pupil = parts[0], parts[1]
        eyes.append({"white": colour(white), "whiteLine": colour(white, "stroke") if white.stroke_width > 0.05 else "",
                     "whiteW": r2(white.stroke_width), "pupil": colour(pupil),
                     "glints": [[colour(g), r2(g.opacity)] for g in parts[2:]]})
    # All the parts go on one sheet (a texture atlas) in the game, assets/racoon/racoon_atlas.svg,
    # which Godot imports once: the puppet scene's nodes each show their rectangle of it. (One
    # imported file instead of 27, and the parts can be drawn together.) The rig file keeps each
    # part's box on the drawing's 400 x 400 page and its place on the sheet.
    # the little tufts of fur low on each cheek, which sway in the game: on each side, the
    # outermost point of the head's outline between a fifth and three quarters of the way down
    hcx, hcy = art["head"]["c"]
    hry = art["head"]["r"][1]
    outline = [q for poly in R.sample(gx["head"].page, 1.0) for q in poly]
    band = [q for q in outline if hcy + 0.2 * hry <= q[1] <= hcy + 0.75 * hry]
    art["cheekFur"] = []
    for side in (-1, 1):
        tip = min(band, key=lambda q: -side * q[0])
        art["cheekFur"].append({"side": side, "tip": [r2(tip[0]), r2(tip[1])], "root": [r2(tip[0] - side * 11), r2(tip[1] + 3)]})
    sheets = {"body": pack_sheet(tex, "racoon_atlas.svg")}
    sheet_tex = {"body": tex}
    if closet:
        # the Closet: one sheet per slot (assets/racoon/closet/hats.svg...), so a new hat only
        # changes the hats sheet and no sheet grows too big for a phone
        for slot, folder in closet["folders"].items():
            mine = {n: t for n, t in closet_tex.items() if tex_slot[n] == slot}
            if mine:
                sheets["closet_" + slot] = pack_sheet(mine, "closet/%s.svg" % folder)
                sheet_tex["closet_" + slot] = mine
        for f in ("racoon_closet.svg", "racoon_closet.svg.import"):   # the one Closet sheet before
            stale = os.path.join(os.path.dirname(GODOT_RIG), f)
            if os.path.exists(stale):
                os.remove(stale)
    old_dir = os.path.normpath(os.path.join(os.path.dirname(GODOT_RIG), "parts"))
    if os.path.isdir(old_dir):   # the one-file-per-part layout before the atlas
        for f in os.listdir(old_dir):
            if f.endswith(".svg") or f.endswith(".svg.import"):
                os.remove(os.path.join(old_dir, f))
        if not os.listdir(old_dir):
            os.rmdir(old_dir)
    textures = {}
    for sheet, (places, _w, _h, _path) in sheets.items():
        for name, t in sheet_tex[sheet].items():
            textures[name] = {"box": t["box"], "sheet": sheet, "atlas": places[name]}
            if "profile" in t:
                textures[name]["profile"] = t["profile"]
    rig_dir = os.path.dirname(os.path.normpath(GODOT_RIG))
    rig = {"version": 5, "source": "tools/racoon-art/parts/racoon_C_inkscape.svg and tools/racoon-art/closet/ (built by motion-demo/build_racoon.py)",
           "sheets": {k: {"file": os.path.relpath(v[3], rig_dir).replace(os.sep, "/"), "size": [v[1], v[2]]} for k, v in sheets.items()},
           "art": art, "arms": arms, "textures": textures,
           "colors": {"ink": gx["head"].get("stroke"), "headLine": r2(gx["head"].stroke_width), "eyes": eyes,
                      "blush": colour(gx["blush"][0]), "nose": colour(nose), "noseShine": colour(nshine),
                      "noseShineOp": r2(nshine.opacity), "mouth": gx["mouth"].get("stroke"), "mouthW": r2(gx["mouth"].stroke_width)}}
    path = os.path.normpath(GODOT_RIG)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(rig, fh, indent=1)
    longest = max(len(line) for line in open(path, encoding="utf-8"))
    return ["wrote %s (%d KB, longest line %d)" % (path, os.path.getsize(path) // 1024, longest)] + [
        "wrote %s (%d parts on a %d x %d sheet)" % (v[3], len(v[0]), v[1], v[2]) for v in sheets.values()]


def pack_sheet(tex, file_name, width=1000):
    """Packs textures onto one SVG sheet next to the rig file (shelves, tallest first, 12 units
    apart so mipmaps don't bleed). Returns (places, width, height, path)."""
    atlas_path = os.path.normpath(os.path.join(os.path.dirname(GODOT_RIG), file_name))
    os.makedirs(os.path.dirname(atlas_path), exist_ok=True)
    if not os.path.exists(atlas_path + ".import"):
        with open(atlas_path + ".import", "w", encoding="utf-8", newline="\n") as fh:
            fh.write(SHEET_IMPORT % file_name.replace(os.sep, "/"))
    pad = 12
    order = sorted(tex, key=lambda n: (-tex[n]["box"][3], n))
    x = y = row_h = 0
    places, groups = {}, []
    for k, name in enumerate(order):
        bw, bh = tex[name]["box"][2], tex[name]["box"][3]
        if x + bw + pad > width:
            x, y, row_h = 0, y + row_h + pad, 0
        places[name] = [x + pad, y + pad, bw, bh]
        x += bw + pad
        row_h = max(row_h, bh)
        text = "".join(tex[name]["svg"])
        inner = text[text.index(">") + 1:text.rindex("</svg>")]
        inner = inner.replace('id="g', 'id="p%d_g' % k).replace("url(#g", "url(#p%d_g" % k)
        bx, by = tex[name]["box"][0], tex[name]["box"][1]
        groups.append('<g id="%s" transform="translate(%s %s)">%s</g>' % (name, R.fmt(places[name][0] - bx), R.fmt(places[name][1] - by), inner))
    atlas_w, atlas_h = width + pad, y + row_h + 2 * pad
    text = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % (
        atlas_w, atlas_h, atlas_w, atlas_h, "".join(groups))
    text = text.replace("><", ">\n<")
    lines = []
    for line in text.split("\n"):
        while len(line) > 160:
            cut = line.rfind(" ", 0, 150)
            if cut <= 0:
                break
            lines.append(line[:cut])
            line = line[cut + 1:]
        lines.append(line)
    with open(atlas_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return places, atlas_w, atlas_h, atlas_path


# --- every part on its own, for the canvas board ----------------------------------------------

def export_parts(D, body, belly, closet=None):
    """One SVG per drawn object (or group) of the visible layers, back to front. (The Closet's items
    are each their own file already, in ../closet/.)"""
    os.makedirs(OUT, exist_ok=True)
    groups = []
    for lname, layer in D.layers.items():
        if layer["hidden"]:
            continue
        for p in layer["parts"]:
            name = p.chain[0]
            if p is body:
                name = "Body"
            elif p is belly:
                name = "Belly"
            if not groups or groups[-1]["name"] != name or groups[-1]["layer"] != lname:
                groups.append({"name": name, "layer": lname, "parts": []})
            groups[-1]["parts"].append(p)
    n_body = len(groups)
    for f in os.listdir(OUT):   # the copies of the Closet's items written here before D-026's folders
        if f.startswith("closet_") and f.endswith(".svg"):
            os.remove(os.path.join(OUT, f))
    index, closet_index, whole, whole_defs = [], [], [], []
    for z, g in enumerate(groups):
        pid = re.sub(r"[^a-z0-9]+", "_", g["name"].lower()).strip("_")
        if g.get("closet"):
            pid = "closet_" + pid
        defs, shapes = [], []
        x0 = y0 = 1e9
        x1 = y1 = -1e9
        for j, p in enumerate(g["parts"]):
            gid = "g-%s-%d" % (pid, j)
            gm = (closet if g.get("closet") else D).gradient_markup(p, gid)
            if gm:
                defs.append(gm.replace("></stop>", "/>"))
            shapes.append('<path d="%s" %s/>' % (R.path_d(p.page), paint(p, gid)))
            b, m = R.bbox(p.page), p.stroke_width / 2 + 1
            x0, y0, x1, y1 = min(x0, b[0] - m), min(y0, b[1] - m), max(x1, b[2] + m), max(y1, b[3] + m)
        box = [math.floor(x0), math.floor(y0), math.ceil(x1) - math.floor(x0), math.ceil(y1) - math.floor(y0)]
        with open(os.path.join(OUT, pid + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" width="%d" height="%d">\n<title>%s</title>\n<defs>%s</defs>\n%s\n</svg>\n' % (
                box[0], box[1], box[2], box[3], box[2], box[3], g["name"], "".join(defs), "\n".join(shapes)))
        if g.get("closet"):
            closet_index.append({"id": pid, "label": g["name"], "layer": g["layer"], "file": pid + ".svg", "box": box})
            continue
        index.append({"id": pid, "label": g["name"], "layer": g["layer"], "file": pid + ".svg", "order": z, "box": box})
        whole.append('<g id="%s">%s</g>' % (pid, "".join(shapes)))
        whole_defs += defs
    with open(os.path.join(OUT, "racoon_rest.svg"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">\n<defs>%s</defs>\n%s\n</svg>\n' % (
            "".join(whole_defs), "\n".join(whole)))
    with open(os.path.join(OUT, "parts.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"grid": [400, 400], "source": "parts/racoon_C_inkscape.svg",
                   "note": "Left and right are as you look at him. Each file's viewBox is the part's box on the grid. order = back to front.",
                   "parts": index,
                   "closet_source": "closet/<folder>/<id>.svg, listed in reading-racoon/content/closet.json"}, fh, indent=1)
    return ["wrote %d parts to %s" % (n_body, OUT)]


if __name__ == "__main__":
    print("\n".join(build()))
