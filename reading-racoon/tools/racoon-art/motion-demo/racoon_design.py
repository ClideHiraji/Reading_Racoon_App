"""Read Racoon's hand-edited Inkscape drawing (../parts/racoon_C_inkscape.svg) for the build (D-024).

Gives each named object's shape as cubic Bezier segments on the 400 x 400 page (transforms
applied), its fill and outline, and its gradient re-expressed in the shape's own box, so the
shading follows the shape when the puppet moves it.
"""
import math
import re
import xml.etree.ElementTree as ET

SVG = "{http://www.w3.org/2000/svg}"
INK = "{http://www.inkscape.org/namespaces/inkscape}"
XLINK = "{http://www.w3.org/1999/xlink}"
IDENT = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


# --- matrices (a, b, c, d, e, f): x' = a x + c y + e, y' = b x + d y + f ---------------------

def mul(m, n):
    return (m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1],
            m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3],
            m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5])


def apply(m, p):
    return (m[0] * p[0] + m[2] * p[1] + m[4], m[1] * p[0] + m[3] * p[1] + m[5])


def invert(m):
    det = m[0] * m[3] - m[1] * m[2]
    a, b, c, d = m[3] / det, -m[1] / det, -m[2] / det, m[0] / det
    return (a, b, c, d, -(a * m[4] + c * m[5]), -(b * m[4] + d * m[5]))


def parse_transform(s):
    m = IDENT
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", s or ""):
        v = [float(x) for x in re.findall(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", args)]
        if name == "matrix":
            t = tuple(v)
        elif name == "translate":
            t = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif name == "scale":
            t = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        elif name == "rotate":
            a = math.radians(v[0])
            t = (math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0, 0)
            if len(v) == 3:
                t = mul(mul((1, 0, 0, 1, v[1], v[2]), t), (1, 0, 0, 1, -v[1], -v[2]))
        else:
            raise ValueError("transform not supported: " + name)
        m = mul(m, t)
    return m


# --- paths -----------------------------------------------------------------------------------

def parse_path(d):
    """Path data as subpaths of absolute cubic segments: [{'segs': [(p0, c1, c2, p3)], 'closed'}]."""
    tok = re.findall(r"[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d)
    subs, segs = [], []
    cur = start = (0.0, 0.0)
    last_c = last_q = None
    i, cmd = 0, None

    def num():
        nonlocal i
        i += 1
        return float(tok[i - 1])

    def line(to):
        segs.append((cur, (cur[0] + (to[0] - cur[0]) / 3, cur[1] + (to[1] - cur[1]) / 3),
                     (cur[0] + 2 * (to[0] - cur[0]) / 3, cur[1] + 2 * (to[1] - cur[1]) / 3), to))

    def end(closed):
        nonlocal segs
        if segs:
            subs.append({"segs": segs, "closed": closed})
        segs = []

    while i < len(tok):
        if re.match(r"[A-Za-z]", tok[i]):
            cmd = tok[i]
            i += 1
            if cmd in "Zz":
                if math.dist(cur, start) > 1e-6:
                    line(start)
                cur = start
                end(True)
                last_c = last_q = None
                continue
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if c == "M":
            end(False)
            cur = start = (num() + ox, num() + oy)
            cmd = "l" if rel else "L"
            last_c = last_q = None
        elif c == "L":
            to = (num() + ox, num() + oy)
            line(to)
            cur, last_c, last_q = to, None, None
        elif c == "H":
            to = (num() + ox, cur[1])
            line(to)
            cur, last_c, last_q = to, None, None
        elif c == "V":
            to = (cur[0], num() + oy)
            line(to)
            cur, last_c, last_q = to, None, None
        elif c in "CS":
            if c == "C":
                c1 = (num() + ox, num() + oy)
            else:
                c1 = (2 * cur[0] - last_c[0], 2 * cur[1] - last_c[1]) if last_c else cur
            c2 = (num() + ox, num() + oy)
            to = (num() + ox, num() + oy)
            segs.append((cur, c1, c2, to))
            cur, last_c, last_q = to, c2, None
        elif c in "QT":
            if c == "Q":
                q = (num() + ox, num() + oy)
            else:
                q = (2 * cur[0] - last_q[0], 2 * cur[1] - last_q[1]) if last_q else cur
            to = (num() + ox, num() + oy)
            segs.append((cur, (cur[0] + 2 * (q[0] - cur[0]) / 3, cur[1] + 2 * (q[1] - cur[1]) / 3),
                         (to[0] + 2 * (q[0] - to[0]) / 3, to[1] + 2 * (q[1] - to[1]) / 3), to))
            cur, last_c, last_q = to, None, q
        else:
            raise ValueError("path command not supported: " + cmd)
    end(False)
    return subs


def ellipse_path(cx, cy, rx, ry):
    k = 0.5522847498
    p = [(cx + rx, cy), (cx, cy + ry), (cx - rx, cy), (cx, cy - ry)]
    c = [((cx + rx, cy + k * ry), (cx + k * rx, cy + ry)), ((cx - k * rx, cy + ry), (cx - rx, cy + k * ry)),
         ((cx - rx, cy - k * ry), (cx - k * rx, cy - ry)), ((cx + k * rx, cy - ry), (cx + rx, cy - k * ry))]
    return [{"segs": [(p[j], c[j][0], c[j][1], p[(j + 1) % 4]) for j in range(4)], "closed": True}]


def transform_subs(subs, m):
    return [{"segs": [tuple(apply(m, q) for q in s) for s in sp["segs"]], "closed": sp["closed"]} for sp in subs]


def bez(s, t):
    u = 1 - t
    return (u ** 3 * s[0][0] + 3 * u * u * t * s[1][0] + 3 * u * t * t * s[2][0] + t ** 3 * s[3][0],
            u ** 3 * s[0][1] + 3 * u * u * t * s[1][1] + 3 * u * t * t * s[2][1] + t ** 3 * s[3][1])


def seg_len(s):
    pts = [bez(s, j / 8) for j in range(9)]
    return sum(math.dist(pts[j], pts[j + 1]) for j in range(8))


def sample(subs, step=2.0):
    """Each subpath as a polyline: every node kept, curves cut into pieces of about `step` px."""
    out = []
    for sp in subs:
        pts = []
        for s in sp["segs"]:
            n = max(1, int(math.ceil(seg_len(s) / step)))
            pts += [bez(s, j / n) for j in range(n)]
        if not sp["closed"]:
            pts.append(sp["segs"][-1][3])
        out.append(pts)
    return out


def bbox(subs):
    pts = [q for poly in sample(subs, 1.0) for q in poly]
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    return (min(xs), min(ys), max(xs), max(ys))


def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def path_d(subs):
    d = []
    for sp in subs:
        d.append("M %s %s" % (fmt(sp["segs"][0][0][0]), fmt(sp["segs"][0][0][1])))
        for s in sp["segs"]:
            d.append("C %s %s %s %s %s %s" % tuple(fmt(v) for q in s[1:] for v in q))
        if sp["closed"]:
            d.append("Z")
    return " ".join(d)


# --- the document ----------------------------------------------------------------------------

class Part:
    """One drawn object: a path, ellipse or circle."""

    def __init__(self, el, chain, matrix, style):
        self.el, self.chain, self.matrix, self.style = el, chain, matrix, style
        self.id = el.get("id")
        self.label = el.get(INK + "label") or self.id
        tag = el.tag.replace(SVG, "")
        if tag == "path":
            self.local = parse_path(el.get("d"))
        elif tag == "ellipse":
            self.local = ellipse_path(float(el.get("cx", 0)), float(el.get("cy", 0)), float(el.get("rx")), float(el.get("ry")))
        else:
            r = float(el.get("r"))
            self.local = ellipse_path(float(el.get("cx", 0)), float(el.get("cy", 0)), r, r)
        self.page = transform_subs(self.local, matrix)
        self.tag = tag

    def get(self, key, default=None):
        return self.style.get(key, default)

    @property
    def stroke_width(self):
        if self.get("stroke", "none") == "none":
            return 0.0
        m = self.matrix
        return float(re.sub(r"[a-z]+$", "", self.get("stroke-width", "1"))) * math.sqrt(abs(m[0] * m[3] - m[1] * m[2]))

    @property
    def opacity(self):
        return float(self.get("opacity", "1"))


STYLE_KEYS = ("fill", "stroke", "stroke-width", "opacity", "fill-opacity", "stroke-linejoin", "stroke-linecap")


def own_style(el):
    st = {k: el.get(k) for k in STYLE_KEYS if el.get(k) is not None}
    for item in (el.get("style") or "").split(";"):
        if ":" in item:
            k, v = item.split(":", 1)
            st[k.strip()] = v.strip()
    return st


class Design:
    def __init__(self, path):
        self.root = ET.parse(path).getroot()
        self.grads = {g.get("id"): g for g in self.root.iter() if g.tag in (SVG + "linearGradient", SVG + "radialGradient")}
        self.layers = {}
        for layer in self.root:
            if layer.tag == SVG + "g" and layer.get(INK + "groupmode") == "layer":
                name = layer.get(INK + "label")
                hidden = "display:none" in (layer.get("style") or "").replace(" ", "")
                self.layers[name] = {"hidden": hidden, "parts": [], "el": layer}
                self._walk(layer, [], parse_transform(layer.get("transform")), {}, self.layers[name]["parts"])

    def _walk(self, el, chain, matrix, inherited, out):
        for ch in el:
            tag = ch.tag.replace(SVG, "")
            m = mul(matrix, parse_transform(ch.get("transform")))
            st = dict(inherited)
            st.update(own_style(ch))
            label = ch.get(INK + "label") or ch.get("id")
            if tag == "g":
                inh = {k: v for k, v in st.items() if k != "opacity"}
                self._walk(ch, chain + [label], m, inh, out)
            elif tag in ("path", "ellipse", "circle"):
                out.append(Part(ch, chain + [label], m, st))

    def parts(self, layer):
        if layer not in self.layers:
            raise SystemExit("The drawing has no layer named '%s'." % layer)
        return self.layers[layer]["parts"]

    def find(self, layer, *labels):
        """The object whose label trail ends with these labels, e.g. find('Head', 'Ear left', 'Outer')."""
        hits = [q for q in self.parts(layer) if q.chain[-len(labels):] == list(labels)]
        if len(hits) != 1:
            raise SystemExit("Expected one object labelled %s in layer '%s', found %d." % (" / ".join(labels), layer, len(hits)))
        return hits[0]

    # --- gradients ---------------------------------------------------------------------------

    def gradient(self, gid):
        """A gradient with everything it inherits through href filled in."""
        seen, chain = set(), []
        while gid and gid not in seen:
            seen.add(gid)
            g = self.grads[gid]
            chain.append(g)
            gid = (g.get(XLINK + "href") or g.get("href") or "").lstrip("#")
        kind = chain[0].tag.replace(SVG, "")

        def attr(name, default=None):
            for g in chain:
                if g.get(name) is not None:
                    return g.get(name)
            return default
        stops = []
        for g in chain:
            st = [s for s in g if s.tag == SVG + "stop"]
            if st:
                for s in st:
                    o = own_style(s)
                    o.update({k: v for k, v in (i.split(":", 1) for i in (s.get("style") or "").split(";") if ":" in i)})
                    stops.append((s.get("offset"), (o.get("stop-color") or s.get("stop-color") or "#000").strip(),
                                  (o.get("stop-opacity") or s.get("stop-opacity") or "1").strip()))
                break
        geo = {}
        for name, default in (("x1", "0"), ("y1", "0"), ("x2", "1"), ("y2", "0")) if kind == "linearGradient" else \
                (("cx", "0.5"), ("cy", "0.5"), ("r", "0.5"), ("fx", None), ("fy", None)):
            v = attr(name, default)
            if v is not None:
                geo[name] = float(v.rstrip("%")) / (100 if v.endswith("%") else 1)
        return {"kind": kind, "geo": geo, "units": attr("gradientUnits", "objectBoundingBox"),
                "matrix": parse_transform(attr("gradientTransform")), "stops": stops, "base": chain[-1].get("id")}

    def gradient_markup(self, part, new_id, drawn_matrix=None):
        """The part's fill gradient in units of its own box, for geometry drawn through
        `drawn_matrix` (default: flattened onto the page; pass IDENT to keep its local coordinates)."""
        m = re.match(r"url\(#([^)]+)\)", part.get("fill", ""))
        if not m:
            return None
        g = self.gradient(m.group(1))
        t = g["matrix"]
        if g["units"] == "userSpaceOnUse":
            dm = part.matrix if drawn_matrix is None else drawn_matrix
            x0, y0, x1, y1 = bbox(transform_subs(part.local, dm))
            box = (x1 - x0, 0, 0, y1 - y0, x0, y0)
            t = mul(invert(box), mul(dm, t))
        geo = " ".join('%s="%s"' % (k, ("%.5f" % v).rstrip("0").rstrip(".")) for k, v in g["geo"].items())
        stops = "".join('<stop offset="%s" stop-color="%s"%s></stop>' % (o, c, "" if op == "1" else ' stop-opacity="%s"' % op)
                        for o, c, op in g["stops"])
        return '<%s id="%s" %s gradientTransform="matrix(%s)">%s</%s>' % (
            g["kind"], new_id, geo, " ".join(("%.6f" % v).rstrip("0").rstrip(".") for v in t), stops, g["kind"])
