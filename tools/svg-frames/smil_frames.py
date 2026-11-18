"""Samples a SMIL-animated SVG into one static SVG per frame, so Godot (which
can't play SVG animation) can render them to PNG frames (D-022).

Usage:
    python smil_frames.py in.svg outdir prefix fps [old=new,old=new...] [pad=0.3]

Handles <animate> (d, opacity, display, fill, stroke, dash...) and
<animateTransform>. The frame count comes from the animation's own duration;
the last frame is sampled just before the loop restarts. The optional color
map swaps hex colors before sampling (e.g. to the game's palette); pad widens
the canvas on every side by that share of its size, for pieces that fly out.
"""
import sys, re, copy, os
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
NUM = re.compile(r"-?\d*\.?\d+(?:e-?\d+)?")
HEX = re.compile(r"#[0-9a-fA-F]{6}")


def rgb(h):
    return [int(h[k:k + 2], 16) for k in (1, 3, 5)]


def bez(p1, p2, u):
    return 3 * (1 - u) ** 2 * u * p1 + 3 * (1 - u) * u ** 2 * p2 + u ** 3


def ease(spline, x):
    x1, y1, x2, y2 = spline
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if bez(x1, x2, mid) < x:
            lo = mid
        else:
            hi = mid
    return bez(y1, y2, (lo + hi) / 2)


def sample(anim, t):
    dur = float(anim.get("dur").rstrip("s"))
    p = min(t / dur, 1.0)
    vals = [v.strip() for v in anim.get("values").split(";")]
    kts = [float(k) for k in anim.get("keyTimes").split(";")]
    mode = anim.get("calcMode", "linear")
    i = 0
    while i < len(kts) - 2 and p >= kts[i + 1]:
        i += 1
    if mode == "discrete":
        j = 0
        for k, kt in enumerate(kts):
            if p >= kt:
                j = k
        return vals[min(j, len(vals) - 1)]
    span = kts[i + 1] - kts[i]
    f = 0.0 if span <= 0 else min(max((p - kts[i]) / span, 0.0), 1.0)
    if mode == "spline":
        sp = [list(map(float, s.split())) for s in anim.get("keySplines").split(";")]
        f = ease(sp[i], f)
    a, b = vals[i], vals[i + 1]
    # Colors blend channel by channel; other text values (url refs,
    # keywords) step at the halfway point instead of being read as numbers.
    if HEX.fullmatch(a) and HEX.fullmatch(b):
        ca, cb = rgb(a), rgb(b)
        return "#%02x%02x%02x" % tuple(round(x + (y - x) * f) for x, y in zip(ca, cb))
    if a.startswith("#") or "url(" in a or not NUM.search(a):
        return a if f < 0.5 else b
    na, nb = NUM.findall(a), NUM.findall(b)
    if len(na) != len(nb):
        return a if f < 0.5 else b
    out = iter("%.3f" % (float(x) + (float(y) - float(x)) * f) for x, y in zip(na, nb))
    return NUM.sub(lambda m: next(out), a)


def frame(root, t, pad=0.0):
    r = copy.deepcopy(root)
    parents = {c: p for p in r.iter() for c in p}
    for anim in list(r.iter()):
        tag = anim.tag.split("}")[-1]
        if tag not in ("animate", "animateTransform"):
            continue
        host = parents[anim]
        v = sample(anim, t)
        if tag == "animateTransform":
            host.set("transform", "%s(%s)" % (anim.get("type"), v.replace(" ", ",")))
        else:
            host.set(anim.get("attributeName"), v)
        host.remove(anim)
    # Renderers differ on display=none; drop those subtrees instead.
    parents = {c: p for p in r.iter() for c in p}
    for el in list(r.iter()):
        if el.get("display") == "none" and el in parents:
            parents[el].remove(el)
    x, y, w, h = map(float, (r.get("viewBox") or "0 0 200 200").split())
    x, y, w, h = x - w * pad, y - h * pad, w * (1 + 2 * pad), h * (1 + 2 * pad)
    r.set("viewBox", "%g %g %g %g" % (x, y, w, h))
    r.set("width", "%g" % w)
    r.set("height", "%g" % h)
    return ET.tostring(r, encoding="unicode")


def main():
    src, out, prefix, fps = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
    text = open(src, encoding="utf-8").read()
    pad = 0.0
    for arg in sys.argv[5:]:
        if arg.startswith("pad="):
            pad = float(arg[4:])
            continue
        for pair in arg.split(","):
            old, new = pair.split("=")
            text = text.replace(old, new)
    root = ET.fromstring(text)
    dur = max(float(a.get("dur").rstrip("s")) for a in root.iter()
              if a.tag.split("}")[-1] in ("animate", "animateTransform"))
    n = int(round(dur * fps)) + 1
    os.makedirs(out, exist_ok=True)
    for k in range(n):
        t = dur * k / (n - 1) if k < n - 1 else dur * 0.9995
        with open(os.path.join(out, "%s_%02d.svg" % (prefix, k)), "w", encoding="utf-8") as f:
            f.write(frame(root, t, pad))
    print("wrote", n, "frames over", dur, "s")


main()
