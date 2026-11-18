"""Twelve new Closet items (D-026), drawn to fit Racoon in his ink style, one Inkscape file each:
sports, builders, pirates, captains, pilots, heroes, rockets, a dinosaur and a jeepney.

    python draw_more_items.py <tools/racoon-art/closet folder>

How the 12 items added on 2026-11-18 were first drawn. The .svg files are the source now: edit them in
Inkscape. Running this again OVERWRITES those 12 files and any hand edits to them.

Racoon at rest on the 400 x 400 page: head centre (200.5, 165.6), radii 108 x 92 (top y 73.6); ears near
(129, 90) and (272, 90); eyes (158.3, 169.1) and (242.9, 169.1), r 15.6; neck (200.5, 263.6); chest
pin (174, 312); paws hold an item 142-260 across, around y 323.
"""
import math
import os
import sys

INK = "#3b2d3a"
K = 0.5523


def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def style(fill, stroke=INK, sw=4.4, extra=""):
    st = "fill:%s" % fill
    if stroke:
        st += ";stroke:%s;stroke-width:%s;stroke-linejoin:round;stroke-linecap:round" % (stroke, f(sw))
    return st + (";" + extra if extra else "")


def ell(cx, cy, rx, ry, rev=False):
    """An ellipse as four cubic curves (the build reads no arcs). rev winds it the other way, for a hole."""
    a = [(cx + rx, cy), (cx + rx, cy + K * ry), (cx + K * rx, cy + ry), (cx, cy + ry),
         (cx - K * rx, cy + ry), (cx - rx, cy + K * ry), (cx - rx, cy),
         (cx - rx, cy - K * ry), (cx - K * rx, cy - ry), (cx, cy - ry),
         (cx + K * rx, cy - ry), (cx + rx, cy - K * ry), (cx + rx, cy)]
    if rev:
        a = [(cx + rx, cy), (cx + rx, cy - K * ry), (cx + K * rx, cy - ry), (cx, cy - ry),
             (cx - K * rx, cy - ry), (cx - rx, cy - K * ry), (cx - rx, cy),
             (cx - rx, cy + K * ry), (cx - K * rx, cy + ry), (cx, cy + ry),
             (cx + K * rx, cy + ry), (cx + rx, cy + K * ry), (cx + rx, cy)]
    d = "M %s %s" % (f(a[0][0]), f(a[0][1]))
    for i in range(1, 13, 3):
        d += " C %s %s %s %s %s %s" % (f(a[i][0]), f(a[i][1]), f(a[i + 1][0]), f(a[i + 1][1]), f(a[i + 2][0]), f(a[i + 2][1]))
    return d + " Z"


def star4(cx, cy, r, k=0.22):
    return ("M {x} {t} Q {a} {b} {rr} {y} Q {a} {c} {x} {bt} Q {d} {c} {l} {y} Q {d} {b} {x} {t} Z").format(
        x=f(cx), y=f(cy), t=f(cy - r), bt=f(cy + r), rr=f(cx + r), l=f(cx - r),
        a=f(cx + r * k), b=f(cy - r * k), c=f(cy + r * k), d=f(cx - r * k))


def star5(cx, cy, R, r, k=0.16):
    pts = [(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(-90 + 36 * i)),
            cy + (R if i % 2 == 0 else r) * math.sin(math.radians(-90 + 36 * i))) for i in range(10)]
    d = []
    for i in range(10):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % 10]
        p0 = (b[0] + (a[0] - b[0]) * k, b[1] + (a[1] - b[1]) * k)
        p1 = (b[0] + (c[0] - b[0]) * k, b[1] + (c[1] - b[1]) * k)
        d.append(("M" if i == 0 else "L") + " %s %s Q %s %s %s %s" % (f(p0[0]), f(p0[1]), f(b[0]), f(b[1]), f(p1[0]), f(p1[1])))
    return " ".join(d) + " Z"


class Item:
    def __init__(self, iid, name, tier, folder, about):
        self.iid, self.name, self.tier, self.folder, self.about = iid, name, tier, folder, about
        self.out, self.defs, self.n, self.g = [], [], 0, 0

    def _id(self):
        self.n += 1
        return "%s-%d" % (self.iid.replace("_", "-"), self.n)

    def lin(self, top, bottom, x2=0, y2=1):
        self.g += 1
        gid = "gr-%s-%d" % (self.iid.replace("_", "-"), self.g)
        self.defs.append('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s"><stop offset="0" style="stop-color:%s" />'
                         '<stop offset="1" style="stop-color:%s" /></linearGradient>' % (gid, x2, y2, top, bottom))
        return "url(#%s)" % gid

    def rad(self, inner, outer, cx=0.35, cy=0.3, r=0.8):
        self.g += 1
        gid = "gr-%s-%d" % (self.iid.replace("_", "-"), self.g)
        self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s"><stop offset="0" style="stop-color:%s" />'
                         '<stop offset="1" style="stop-color:%s" /></radialGradient>' % (gid, cx, cy, r, inner, outer))
        return "url(#%s)" % gid

    def path(self, label, d, fill, stroke=INK, sw=4.4, extra=""):
        self.out.append('<path id="%s" inkscape:label="%s" d="%s" style="%s" />' % (self._id(), label, d, style(fill, stroke, sw, extra)))

    def line(self, label, d, stroke, sw, extra=""):
        self.path(label, d, "none", stroke, sw, extra)

    def circle(self, label, cx, cy, r, fill, stroke=INK, sw=4.4, extra=""):
        self.out.append('<circle id="%s" inkscape:label="%s" cx="%s" cy="%s" r="%s" style="%s" />' % (
            self._id(), label, f(cx), f(cy), f(r), style(fill, stroke, sw, extra)))

    def ellipse(self, label, cx, cy, rx, ry, fill, stroke=INK, sw=4.4, extra=""):
        self.out.append('<ellipse id="%s" inkscape:label="%s" cx="%s" cy="%s" rx="%s" ry="%s" style="%s" />' % (
            self._id(), label, f(cx), f(cy), f(rx), f(ry), style(fill, stroke, sw, extra)))

    def group(self, label, hidden=False, transform=""):
        st = ' style="display:none"' if hidden else ""
        tr = ' transform="%s"' % transform if transform else ""
        self.out.append('<g id="%s" inkscape:label="%s"%s%s>' % (self._id(), label, tr, st))

    def end(self):
        self.out.append("</g>")

    def svg(self):
        sid = self.iid.replace("_", "-")
        body = "\n     ".join(self.out)
        return '''<?xml version="1.0" encoding="UTF-8"?>
<!-- Racoon's Closet: {name} ({tier}, {folder}). FR-07, D-026.
     Drawn to fit Racoon at rest: the bottom layer links ../../parts/racoon_C_inkscape.svg (locked).
     Draw on the "Item" layer. The file's name is the item's id; its name, tier, price and how it's
     earned are in reading-racoon/content/closet.json. motion-demo/build_racoon.py reads this file
     and never writes it. -->
<svg
   width="400"
   height="400"
   viewBox="0 0 400 400"
   version="1.1"
   id="svg-{sid}"
   sodipodi:docname="{iid}.svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:xlink="http://www.w3.org/1999/xlink"
   xmlns="http://www.w3.org/2000/svg">
  <title>{name}</title>
  <sodipodi:namedview
     id="namedview-{sid}"
     pagecolor="#fefde0"
     bordercolor="#666666"
     inkscape:document-units="px"
     inkscape:zoom="2"
     inkscape:cx="200"
     inkscape:cy="200"
     inkscape:current-layer="layer-item" />
  <defs id="defs-{sid}">
    {defs}
  </defs>
  <g
     inkscape:groupmode="layer"
     id="layer-reference"
     inkscape:label="Racoon (reference)"
     sodipodi:insensitive="true">
    <image
       id="racoon-reference"
       inkscape:label="Racoon (linked from racoon_C_inkscape.svg)"
       xlink:href="../../parts/racoon_C_inkscape.svg"
       x="0"
       y="0"
       width="400"
       height="400"
       preserveAspectRatio="none" />
  </g>
  <g inkscape:groupmode="layer" id="layer-item" inkscape:label="Item">
   <g id="item-{sid}" inkscape:label="{iid}">
     <title>{name}: {about} ({tier})</title>
     {body}
   </g>
  </g>
</svg>
'''.format(name=self.name, tier=self.tier, folder=self.folder, sid=sid, iid=self.iid,
           defs="\n    ".join(self.defs), about=self.about, body=body)


SHINE = "fill:none;stroke:#ffffff;stroke-width:5;stroke-linejoin:round;stroke-linecap:round;opacity:0.5"


# --- hats -------------------------------------------------------------------------------------------
def hard_hat(it, back=False):
    dome = "M 116 118 C 112 68 152 38 200.5 38 C 249 38 289 68 285 118 C 245 110 156 110 116 118 Z"
    it.path("Dome", dome, it.lin("#ffe27a", "#f2ae0b"))
    it.path("Ridge", "M 188 41 C 186 68 186 94 188 112 L 213 112 C 215 94 215 68 213 41 C 205 38 196 38 188 41 Z",
            it.lin("#ffd23f", "#e39b0d"), sw=3.6)
    it.line("Rib", "M 158 52 C 150 72 148 94 150 113", "#d18c08", 3)
    it.line("Rib", "M 243 52 C 251 72 253 94 251 113", "#d18c08", 3)
    it.path("Brim", "M 100 120 C 130 105 271 105 301 120 C 295 133 262 138 200.5 138 C 139 138 106 133 100 120 Z",
            it.lin("#ffd23f", "#d99307"))
    if not back:
        it.ellipse("Lamp", 200.5, 84, 15, 12, it.lin("#9aa3b5", "#5c6475"), sw=3.6)
        it.ellipse("Lamp light", 200.5, 84, 9.5, 7.5, it.rad("#ffffff", "#fff0a8"), sw=2.6)
        it.line("Shine", "M 138 74 C 150 56 168 46 184 44", "#ffffff", 5, "opacity:0.55")


def pirate_hat(it, back=False):
    it.path("Crown", "M 140 98 C 138 52 168 30 200.5 30 C 233 30 263 52 261 98 Z", it.lin("#4a4258", "#2b2534"))
    if not back:
        it.path("Feather", "M 246 62 C 252 36 268 18 288 12 C 286 30 276 50 258 66 Z", it.lin("#ff7a6e", "#d6453a"), sw=3.6)
        it.line("Quill", "M 250 64 C 260 44 272 28 286 15", "#a8322a", 2.4)
        it.circle("Anchor ring", 200.5, 40, 4.5, "none", "#fff7e6", 3)
        it.line("Anchor", "M 200.5 45 L 200.5 70 M 191 53 L 210 53 M 187 61 Q 189 72 200.5 72 Q 212 72 214 61",
                "#fff7e6", 3.6)
    it.path("Brim", "M 90 118 C 106 72 150 58 200.5 84 C 251 58 295 72 311 118 C 270 104 231 108 200.5 130 "
            "C 170 108 131 104 90 118 Z", it.lin("#3d364a", "#211c29"))
    it.line("Gold trim", "M 97 110 C 114 76 152 66 200.5 90 C 249 66 287 76 304 110", "#f2c94c", 4)
    if not back:
        it.path("Gem", "M 200.5 92 L 208 100 L 200.5 108 L 193 100 Z", it.lin("#ff8fb1", "#d6456e"), sw=2.8)
        it.line("Shine", "M 152 46 C 162 38 172 34 182 33", "#ffffff", 4, "opacity:0.4")


def captain_hat(it, back=False):
    it.path("Top", "M 104 98 C 100 70 140 50 200.5 50 C 261 50 301 70 297 98 C 300 106 270 110 200.5 110 "
            "C 131 110 101 106 104 98 Z", it.lin("#ffffff", "#e3ded4"))
    it.path("Band", "M 122 102 L 279 102 L 276 124 C 240 130 161 130 125 124 Z", it.lin("#3a4f86", "#26355f"), sw=4)
    if not back:
        it.path("Visor", "M 126 122 C 160 131 241 131 275 122 C 270 140 237 149 200.5 149 C 164 149 131 140 126 122 Z",
                it.lin("#3d3846", "#1e1b24"))
        it.line("Visor shine", "M 146 132 C 166 138 190 140 210 140", "#ffffff", 3, "opacity:0.35")
        it.line("Gold braid", "M 130 123 C 165 132 236 132 271 123", "#f2c94c", 4.2)
        it.circle("Button", 132, 123, 5, "#ffd23f", sw=2.6)
        it.circle("Button", 269, 123, 5, "#ffd23f", sw=2.6)
        for sx in (-1, 1):
            it.path("Laurel", "M %s 116 C %s 108 %s 98 %s 90 C %s 98 %s 108 %s 116 Z" % (
                f(200.5 + sx * 14), f(200.5 + sx * 22), f(200.5 + sx * 26), f(200.5 + sx * 25),
                f(200.5 + sx * 20), f(200.5 + sx * 17), f(200.5 + sx * 14)), it.lin("#ffe27a", "#d99307"), sw=2.4)
        it.ellipse("Badge", 200.5, 104, 14, 13, it.rad("#fff3b0", "#e3a50d"), sw=3)
        it.path("Badge star", star5(200.5, 104.5, 9, 4), "#3a4f86", INK, 1.6)
        it.line("Shine", "M 136 66 C 152 58 170 55 186 54", "#ffffff", 4, "opacity:0.6")


# --- glasses (painted on his face) ------------------------------------------------------------------
def hero_mask(it, back=False):
    outer = ("M 122 160 C 124 141 150 136 173 145 C 186 150 194 153 200.5 153 C 207 153 215 150 228 145 "
             "C 251 136 277 141 279 160 C 281 181 263 197 243 195 C 226 193 214 183 200.5 181 "
             "C 187 183 175 193 158 195 C 138 197 120 181 122 160 Z")
    it.path("Tie", "M 278 158 L 300 148 L 296 168 Z", it.lin("#ff7a6e", "#c43d33"), sw=3.4)
    it.path("Tie", "M 279 164 L 298 176 L 288 182 Z", it.lin("#ff7a6e", "#c43d33"), sw=3.4)
    it.path("Mask", outer + " " + ell(158.3, 169.1, 17, 15, rev=True) + " " + ell(242.9, 169.1, 17, 15, rev=True),
            it.lin("#ff6f61", "#d6453a"))
    it.line("Shine", "M 134 155 C 142 146 156 143 168 146", "#ffffff", 3.4, "opacity:0.55")
    it.line("Shine", "M 266 155 C 258 146 244 143 232 146", "#ffffff", 3.4, "opacity:0.4")


def pilot_goggles(it, back=False):
    leather = it.lin("#a8693f", "#7a4a2a")
    it.path("Strap", "M 134 158 L 100 152 L 100 176 L 134 176 Z", leather, sw=3.6)
    it.path("Strap", "M 267 158 L 301 152 L 301 176 L 267 176 Z", leather, sw=3.6)
    it.path("Bridge", "M 180 160 Q 200.5 149 221 160 L 221 171 Q 200.5 161 180 171 Z", leather, sw=3.4)
    for cx in (158.3, 242.9):
        it.circle("Lens", cx, 169.1, 19, "#a9dcf2", INK, 2.8, "fill-opacity:0.45")
        it.path("Rim", ell(cx, 169.1, 25, 25) + " " + ell(cx, 169.1, 19, 19, rev=True), it.lin("#f2cf6b", "#b8801e"), sw=3.4)
        it.line("Glint", "M %s 160 L %s 168" % (f(cx - 8), f(cx - 1)), "#ffffff", 3.4, "opacity:0.85")
    for x in (110, 122, 279, 291):
        it.circle("Rivet", x, 164, 2.6, "#f2cf6b", INK, 1.6)


# --- neck (it wraps round him in 3D: drawn at its true width) ---------------------------------------
def bandana(it, back=False):
    it.path("Bandana", "M 156 254 C 180 262 221 262 245 254 L 241 268 C 232 274 222 280 214 290 L 200.5 305 "
            "L 187 290 C 179 280 169 274 160 268 Z", "#e2574c")
    it.line("Fold", "M 165 266 C 184 276 217 276 236 266", "#a8322a", 2.6)
    for (x, y) in [(171, 262), (189, 268), (212, 268), (230, 262), (192, 283), (209, 283), (200.5, 295)]:
        it.circle("Dot", x, y, 2.6, "#fff7e6", None)
    it.line("Shine", "M 168 259 C 180 263 192 265 204 265", "#ffffff", 3, "opacity:0.45")


def whistle(it, back=False):
    it.line("Cord outline", "M 160 255 C 171 278 186 292 196 296", INK, 8.2)
    it.line("Cord outline", "M 241 255 C 231 276 219 288 210 293", INK, 8.2)
    it.line("Cord", "M 160 255 C 171 278 186 292 196 296", "#3f86c8", 4.4)
    it.line("Cord", "M 241 255 C 231 276 219 288 210 293", "#3f86c8", 4.4)
    steel = it.lin("#f4f6fa", "#a9b1c0")
    it.path("Mouthpiece", "M 205 296 L 226 293 C 229 293 230 295 230 297 L 230 302 C 230 304 229 306 226 306 L 207 307 Z",
            steel, sw=3.4)
    it.circle("Barrel", 199, 305, 13, steel, sw=3.6)
    it.ellipse("Hole", 203, 297, 4.2, 2.2, "#4b4458", None)
    it.circle("Ring", 192, 292, 4, "none", "#a9b1c0", 2.6)
    it.line("Shine", "M 191 300 C 192 296 195 294 198 294", "#ffffff", 3, "opacity:0.8")


# --- pins (retired 2026-11-18, D-029: clothes took their slot; their drawings are in parts/retired-pins) ---
def pin_rocket(it, back=False):
    it.circle("Pin", 174, 312, 16, it.lin("#3a4f86", "#26355f"), sw=3.4)
    it.circle("Ring", 174, 312, 12.4, "none", "#8fb8e8", 1.8)
    for (x, y) in [(165, 304), (184, 317), (167, 321)]:
        it.circle("Star", x, y, 1.1, "#ffffff", None)
    it.group("Rocket", transform="rotate(35 174 312)")
    it.path("Body", "M 174 300 C 179 304 180 312 179 320 L 169 320 C 168 312 169 304 174 300 Z", "#fdfbf6", INK, 1.6)
    it.path("Nose", "M 174 300 C 177 302 178.5 305 179 307 L 169 307 C 169.5 305 171 302 174 300 Z", "#e2574c", INK, 1.4)
    it.circle("Window", 174, 312, 2.4, "#8fd3f2", INK, 1.2)
    it.path("Fin", "M 169 315 L 165 322 L 169 321 Z", "#e2574c", INK, 1.2)
    it.path("Fin", "M 179 315 L 183 322 L 179 321 Z", "#e2574c", INK, 1.2)
    it.path("Flame", "M 171 321 Q 174 328 177 321 Z", "#ffb52e", INK, 1.2)
    it.end()


def pin_dino(it, back=False):
    it.circle("Pin", 174, 312, 16, it.lin("#fff3c4", "#ffd97a"), sw=3.4)
    it.circle("Ring", 174, 312, 12.4, "none", "#b48fd0", 2)
    it.circle("Gem", 174, 297.6, 2.2, "#b48fd0", INK, 1.2)
    green = "#5fae4c"
    it.path("Plates", "M 165 309 L 167.5 303.5 L 170 309 Z M 169.5 308 L 172.5 302 L 175.5 308 Z "
            "M 175 309 L 177.5 303.5 L 180 309.5 Z", "#f39a2f", INK, 1.2)
    it.path("Tail", "M 165 313 C 161 315 158 318 156 317 C 159 313 162 310 166 310 Z", green, INK, 1.4)
    it.ellipse("Body", 172.5, 313.5, 8.5, 5.8, green, INK, 1.6)
    it.path("Neck", "M 178 311 C 180 306 183 303 186.5 304 C 189 305 188.5 308.5 185 309 C 183 310 181 313 180 316 Z",
            green, INK, 1.4)
    it.path("Legs", "M 167.5 318 L 167.5 322.5 L 170.5 322.5 L 170.5 318 Z M 174.5 318 L 174.5 322.5 L 177.5 322.5 L 177.5 318 Z",
            green, INK, 1.2)
    it.circle("Eye", 185.4, 305.6, 0.9, INK, None)


# --- paws (held in both paws, 142-260 across) ------------------------------------------------------
def basketball(it, back=False):
    it.circle("Ball", 200.6, 320, 52, it.rad("#ffb06a", "#d9661f", 0.38, 0.32, 0.75))
    it.line("Seam", "M 200.6 268 L 200.6 372", INK, 3.4)
    it.line("Seam", "M 148.6 320 L 252.6 320", INK, 3.4)
    it.line("Seam", "M 165 282 C 184 300 184 340 165 358", INK, 3.4)
    it.line("Seam", "M 236.2 282 C 217.2 300 217.2 340 236.2 358", INK, 3.4)
    it.line("Shine", "M 168 290 C 174 282 182 277 190 275", "#ffffff", 5, "opacity:0.45")


def jeepney(it, back=False):
    it.path("Roof", "M 140 302 C 140 293 146 289 156 289 L 230 289 C 236 289 242 293 242 302 Z",
            it.lin("#fffaf0", "#e8e2d6"), sw=4)
    it.line("Roof rack", "M 150 285 L 234 285 M 158 285 L 158 290 M 182 285 L 182 290 M 206 285 L 206 290 M 230 285 L 230 290",
            "#e3a50d", 3)
    it.path("Flag", "M 236 285 L 236 270 L 248 274 L 236 278", "#e2574c", INK, 2.4)
    it.path("Body", "M 144 302 L 238 302 C 242 302 244 305 245 309 L 253 312 C 258 314 260 318 260 324 L 260 344 "
            "C 260 348 257 350 253 350 L 146 350 C 142 350 140 347 140 343 L 140 306 C 140 303 142 302 144 302 Z",
            it.lin("#ff6f61", "#d6453a"))
    for i in range(5):
        x = 147 + i * 18
        it.path("Window", "M %s 308 L %s 308 L %s 320 L %s 320 Z" % (f(x), f(x + 13), f(x + 13), f(x)), "#bfe6f7", INK, 2.4)
    it.path("Windshield", "M 241 310 L 251 313 L 251 321 L 241 321 Z", "#bfe6f7", INK, 2.4)
    it.path("Stripe", "M 141 326 L 259 326 L 259 332 L 141 332 Z", "#ffc918", None)
    it.path("Stripe", "M 141 334 L 259 334 L 259 338 L 141 338 Z", "#3f86c8", None)
    it.line("Gold trim", "M 142 323 L 258 323", "#f2c94c", 2.6)
    it.path("Bumper", "M 238 344 L 262 344 L 262 351 L 238 351 Z", it.lin("#f4f6fa", "#a9b1c0"), sw=2.6)
    it.circle("Headlight", 255.5, 330, 3.6, "#fff3b0", INK, 2)
    for x in (166, 232):
        it.circle("Wheel", x, 352, 12.5, "#3a3346", INK, 3.6)
        it.circle("Hub", x, 352, 5, "#c9cfdb", INK, 2)
    it.line("Shine", "M 150 296 C 170 292 196 292 216 292", "#ffffff", 3, "opacity:0.55")


def galaxy_rocket(it, back=False):
    crystal = it.lin("#d9f6ff", "#7fd3f0")
    it.path("Fin", "M 170 326 L 146 360 L 151 369 L 170 356 Z", crystal, sw=3.6)
    it.path("Fin", "M 231 326 L 255 360 L 250 369 L 231 356 Z", crystal, sw=3.6)
    it.path("Flame", "M 186 362 C 188 378 196 386 200.6 394 C 205 386 213 378 215 362 Z", it.lin("#fff0a8", "#ff8a3c"), sw=3.2)
    it.path("Body", "M 200.6 262 C 222 278 232 302 232 330 L 232 354 L 169 354 L 169 330 C 169 302 179 278 200.6 262 Z",
            it.lin("#7b6cf0", "#2d2f6b"))
    it.path("Nose", "M 200.6 262 C 214 272 221 282 225 292 L 176 292 C 180 282 187 272 200.6 262 Z", it.lin("#ffd6f0", "#e98ad0"),
            sw=3.6)
    it.line("Facet", "M 200.6 292 L 200.6 352 M 186 300 L 176 340 M 215 300 L 225 340", "#b8b0ff", 1.8, "opacity:0.6")
    if not back:
        it.circle("Window", 200.6, 316, 13, it.rad("#e8fbff", "#58c8ec"), sw=3.6)
        it.circle("Window ring", 200.6, 316, 13, "none", "#f2cf6b", 2.4)
    for (x, y, r) in [(184, 338, 5), (219, 344, 4), (213, 298, 3.6), (186, 300, 2.8)]:
        it.path("Sparkle", star4(x, y, r), "#ffffff", None)
    it.path("Base", "M 174 354 L 227 354 L 221 363 L 180 363 Z", it.lin("#c9cfdb", "#8a93a6"), sw=3.2)
    it.line("Shine", "M 186 276 C 182 286 180 296 179 308", "#ffffff", 4, "opacity:0.5")


# id: (function, name, tier, folder, about, needs a back view)
ITEMS = {
    "hard_hat": (hard_hat, "Builder's hard hat", "silver", "hats", "a yellow builder's helmet with a headlamp", True),
    "pirate_hat": (pirate_hat, "Pirate hat", "violet", "hats", "a tricorne with a gold trim, an anchor, a gem and a feather", True),
    "captain_hat": (captain_hat, "Captain's hat", "gold", "hats", "a ship captain's cap with a gold badge, laurels and braid", True),
    "hero_mask": (hero_mask, "Hero mask", "silver", "glasses", "a red hero's eye mask with ties", False),
    "pilot_goggles": (pilot_goggles, "Pilot goggles", "violet", "glasses", "brass flying goggles on a leather strap", False),
    "bandana": (bandana, "Explorer bandana", "copper", "neck", "a red bandana with white dots", False),
    "whistle": (whistle, "Coach's whistle", "silver", "neck", "a silver whistle on a blue cord", False),
    "basketball": (basketball, "Basketball", "silver", "paws", "an orange basketball", True),
    "jeepney": (jeepney, "Toy jeepney", "gold", "paws", "a bright toy jeepney with gold trims", True),
    "galaxy_rocket": (galaxy_rocket, "Galaxy rocket", "diamond", "paws", "a crystal rocket full of stars", True),
}


def build(iid):
    fn, name, tier, folder, about, has_back = ITEMS[iid]
    it = Item(iid, name, tier, folder, about)
    fn(it)
    if has_back:
        it.group("Back view", hidden=True)
        fn(it, back=True)
        it.end()
    return it


if __name__ == "__main__":
    closet = sys.argv[1]
    for iid, v in ITEMS.items():
        p = os.path.join(closet, v[3], iid + ".svg")
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(build(iid).svg())
        print("wrote", v[3] + "/" + iid + ".svg")
