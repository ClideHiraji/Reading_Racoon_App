"""Racoon's clothes (D-029): T-shirts, a jersey, a hoodie, a sailor top, a barong and dresses, one Inkscape
file each in closet/tops/. They replace the chest pins.

    python draw_tops.py <tools/racoon-art/closet folder>

How these 11 were first drawn. The .svg files are the source now: edit them in Inkscape. Running this
again OVERWRITES them and any hand edits.

The game clips a top to Racoon's body fill (like his white belly), so each one is drawn wider than his
body: its sides come out exactly along his outline, and only its neckline, its hem and its print need
shaping. His body at rest on the 400 x 400 page: 136-270 across, 231-385 down (63 either side of x 200.5);
his head hides it down to about y 257; his arms hang from (154, 269) and (247, 269); his white belly is
156-249 across, 266-367 down.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_more_items import Item, INK, f, star4, star5  # noqa: E402

X0, X1 = 112, 289          # wider than his body; the game trims the sides to his outline
TOP = 234                  # under his head
CX = 200.5


def mix(a, b, t):
    A = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    B = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02x" % round(A[i] + (B[i] - A[i]) * t) for i in range(3))


def side(it, base, depth=0.22):
    """A soft roll from his middle to his sides, so the cloth looks round, not flat."""
    it.g += 1
    gid = "gr-%s-%d" % (it.iid.replace("_", "-"), it.g)
    dark = mix(base, INK, depth)
    lite = mix(base, "#ffffff", 0.12)
    it.defs.append('<linearGradient id="%s" x1="0" y1="0" x2="1" y2="0">'
                   '<stop offset="0" style="stop-color:%s" /><stop offset="0.3" style="stop-color:%s" />'
                   '<stop offset="0.55" style="stop-color:%s" /><stop offset="1" style="stop-color:%s" /></linearGradient>'
                   % (gid, dark, base, lite, dark))
    return "url(#%s)" % gid


def tee(hem=350):
    """A T-shirt's shape: straight across under his head, a gently curved hem."""
    return "M %d %d L %d %d L %d %d C %s %d %s %d %d %d Z" % (
        X0, TOP, X1, TOP, X1, hem - 4, f(CX + 52), hem + 10, f(CX - 52), hem + 10, X0, hem - 4)


def dress(hem=372, scallops=7):
    """A dress's shape, down to a scalloped hem above his feet."""
    d = "M %d %d L %d %d L %d %d" % (X0, TOP, X1, TOP, X1, hem)
    w = (X1 - X0) / scallops
    for i in range(scallops):
        x = X1 - i * w
        d += " Q %s %s %s %s" % (f(x - w / 2), f(hem + 9), f(x - w), f(hem))
    return d + " Z"


def collar(it, color, width=7):
    it.line("Collar", "M 170 251 C 184 270 217 270 231 251", INK, width + 4)
    it.line("Collar", "M 170 251 C 184 270 217 270 231 251", color, width)


def shine(it, d="M 150 262 C 148 280 148 300 152 318"):
    it.line("Shine", d, "#ffffff", 5, "opacity:0.35")


def flower(it, cx, cy, r, petal, center="#ffd23f", sw=1.6):
    for k in range(5):
        import math
        a = math.radians(k * 72 - 90)
        it.circle("Petal", cx + math.cos(a) * r, cy + math.sin(a) * r, r * 0.75, petal, INK, sw)
    it.circle("Centre", cx, cy, r * 0.55, center, INK, sw)


# --- tops ---------------------------------------------------------------------------------------------
def river_tee(it):
    teal = "#3fb7a8"
    it.path("Shirt", tee(), teal)
    collar(it, "#7fd6ca")
    it.line("Wave", "M 162 302 C 171 293 180 311 189 302 C 198 293 207 311 216 302 C 225 293 234 311 240 302",
            "#e6fbf6", 5)
    shine(it)


def striped_tee(it):
    it.path("Shirt", tee(), side(it, "#fff3dc", 0.15))
    for y in (262, 284, 306, 326):
        it.path("Stripe", "M %d %d L %d %d L %d %d L %d %d Z" % (X0, y, X1, y, X1, y + 10, X0, y + 10), "#f08a3c", None)
    it.path("Hem line", tee(), "none")
    collar(it, "#f08a3c")
    shine(it)


def book_tee(it):
    it.path("Shirt", tee(), side(it, "#ffc918"))
    collar(it, "#ffe27a")
    it.path("Cover", "M 172 287 L 199 291 Q 200.5 292.5 202 291 L 229 287 L 229 318 L 202 322 Q 200.5 323.5 199 322 L 172 318 Z",
            "#5c9bd4", INK, 2.8)
    it.path("Page", "M 176 289 C 184 287 193 288 199.4 292 L 199.4 318 C 193 315 184 314 176 316 Z", "#fffaf0", INK, 2)
    it.path("Page", "M 225 289 C 217 287 208 288 201.6 292 L 201.6 318 C 208 315 217 314 225 316 Z", "#fffaf0", INK, 2)
    it.line("Lines", "M 180 297 Q 189 296 196 299 M 180 304 Q 189 303 196 306 M 205 299 Q 212 296 221 297 "
            "M 205 306 Q 212 303 221 304", "#c9b893", 1.6)
    shine(it)


def jersey(it):
    blue = "#3f86c8"
    it.path("Jersey", tee(354), side(it, blue))
    it.line("Neck trim", "M 176 250 L 200.5 281 L 225 250", INK, 11)
    it.line("Neck trim", "M 176 250 L 200.5 281 L 225 250", "#ffffff", 7)
    for sx in (-1, 1):
        it.line("Arm trim", "M %s 248 C %s 262 %s 284 %s 300" % (f(CX + sx * 54), f(CX + sx * 40), f(CX + sx * 40),
                f(CX + sx * 52)), "#ffffff", 6, "opacity:0.95")
        it.line("Side stripe", "M %s 304 L %s 354" % (f(CX + sx * 50), f(CX + sx * 50)), "#ffd23f", 6)
    it.circle("Ball", 200.5, 312, 15, "#f08a3c", INK, 2.6)
    it.line("Seams", "M 200.5 297 L 200.5 327 M 185.5 312 L 215.5 312 M 190 301 C 196 306 196 318 190 323 "
            "M 211 301 C 205 306 205 318 211 323", INK, 1.8)


def sundress(it):
    it.path("Dress", dress(372), side(it, "#ffd84d", 0.18))
    for (x, y) in [(164, 324), (226, 330), (190, 352), (240, 356), (160, 360), (212, 276), (176, 270)]:
        flower(it, x, y, 4.2, "#ffffff")
    it.path("Ribbon", "M %d 300 L %d 300 L %d 309 L %d 309 Z" % (X0, X1, X1, X0), "#ffffff", INK, 2.4)
    it.path("Bow", "M 200.5 304 C 192 296 182 298 184 305 C 186 311 194 309 200.5 304 C 207 309 215 311 217 305 "
            "C 219 298 209 296 200.5 304 Z", "#ffffff", INK, 2.4)
    it.circle("Knot", 200.5, 304, 3.2, "#ffd84d", INK, 2)
    collar(it, "#ffffff", 6)
    shine(it, "M 150 262 C 148 290 148 320 152 350")


def dino_tee(it):
    green = "#6aab4c"
    it.path("Shirt", tee(), side(it, green))
    collar(it, "#a6d68a")
    # a little dinosaur on his chest, with orange plates
    it.path("Plates", "M 180 296 L 186 283 L 192 296 Z M 191 292 L 198 278 L 205 292 Z M 204 296 L 210 284 L 216 297 Z",
            "#f39a2f", INK, 2.2)
    it.path("Tail", "M 180 305 C 170 309 163 316 158 314 C 165 305 172 299 182 298 Z", "#3f8a2e", INK, 2.4)
    it.ellipse("Body", 197, 307, 21, 14, "#3f8a2e", INK, 2.6)
    it.path("Neck", "M 211 302 C 216 290 224 283 232 286 C 238 289 236 297 228 298 C 223 299 219 305 216 312 Z",
            "#3f8a2e", INK, 2.4)
    it.path("Legs", "M 185 316 L 185 327 L 192 327 L 192 316 Z M 203 316 L 203 327 L 210 327 L 210 316 Z",
            "#3f8a2e", INK, 2.2)
    it.circle("Eye", 229.5, 290.5, 2, INK, None)
    shine(it)


def hoodie(it):
    red = "#e2574c"
    it.path("Hoodie", tee(356), side(it, red))
    it.path("Hood edge", "M 162 244 C 174 274 227 274 239 244 L 246 252 C 232 288 169 288 155 252 Z", mix(red, INK, 0.2),
            INK, 3)
    for sx in (-1, 1):
        it.line("String", "M %s 266 L %s 296" % (f(CX + sx * 11), f(CX + sx * 12)), "#fff7e6", 3.4)
        it.circle("Tip", CX + sx * 12, 298, 2.6, "#fff7e6", INK, 1.6)
    it.path("Pocket", "M 166 324 L 235 324 L 246 350 C 216 358 185 358 155 350 Z", mix(red, INK, 0.12), INK, 3)
    it.line("Pocket seam", "M 168 328 L 233 328", "#ff8a7e", 2, "opacity:0.8")
    shine(it)


def party_dress(it):
    pink = "#ff9fbf"
    it.path("Dress", dress(374, 9), side(it, pink, 0.16))
    it.path("Tulle", dress(374, 9).replace("M %d %d" % (X0, TOP), "M %d 304" % X0, 1).replace(
        "L %d %d L" % (X1, TOP), "L %d 304 L" % X1, 1), "#ffd0e0", INK, 2.6, "fill-opacity:0.85")
    it.path("Tulle", dress(360, 8).replace("M %d %d" % (X0, TOP), "M %d 318" % X0, 1).replace(
        "L %d %d L" % (X1, TOP), "L %d 318 L" % X1, 1), "#ffe3ee", INK, 2, "fill-opacity:0.8")
    it.path("Sash", "M %d 298 L %d 298 L %d 308 L %d 308 Z" % (X0, X1, X1, X0), "#b48fd0", INK, 2.4)
    it.path("Bow", "M 200.5 303 C 190 293 177 296 180 304 C 183 312 193 310 200.5 303 C 208 310 218 312 221 304 "
            "C 224 296 211 293 200.5 303 Z", "#b48fd0", INK, 2.4)
    it.circle("Knot", 200.5, 303, 3.6, "#d8b8ee", INK, 2)
    for (x, y, r) in [(168, 336, 4), (232, 344, 3.4), (198, 356, 3.6), (214, 330, 2.8), (180, 362, 2.8)]:
        it.path("Sparkle", star4(x, y, r), "#ffffff", None)
    collar(it, "#ffd0e0", 6)
    shine(it, "M 150 262 C 148 274 148 286 150 294")


def sailor_top(it):
    navy = "#2d3e6b"
    it.path("Shirt", tee(), side(it, "#fbf8f2", 0.14))
    it.path("Sailor collar", "M 128 242 L 273 242 L 262 264 L 200.5 304 L 139 264 Z", navy)
    it.line("Collar stripe", "M 146 260 L 200.5 296 L 255 260", "#ffffff", 3)
    it.path("Neckerchief", "M 190 294 L 211 294 L 206 316 L 200.5 322 L 195 316 Z", "#e2574c", INK, 2.6)
    it.circle("Knot", 200.5, 296, 5, "#e2574c", INK, 2.4)
    it.path("Hem band", "M %d 340 L %d 340 L %d 348 C %s 358 %s 358 %d 348 Z" % (X0, X1, X1, f(CX + 52), f(CX - 52), X0),
            navy, None)
    shine(it, "M 150 270 C 148 288 148 304 152 320")


def barong(it):
    sheer = "#fbf2dc"
    it.path("Barong", tee(358), side(it, sheer, 0.12), INK, 4.4, "fill-opacity:0.9")
    it.path("Embroidery panel", "M 180 262 L 221 262 L 221 360 L 180 360 Z", "#f6e7c2", None)
    gold = "#c99a3a"
    for y in range(270, 358, 13):
        it.path("Motif", "M 200.5 %s L 206 %s L 200.5 %s L 195 %s Z" % (f(y - 5), f(y), f(y + 5), f(y)), "none", gold, 1.6)
        it.line("Vine", "M 186 %s Q 190 %s 194 %s M 207 %s Q 211 %s 215 %s" % (
            f(y - 2), f(y + 4), f(y - 2), f(y - 2), f(y + 4), f(y - 2)), gold, 1.4)
    it.line("Panel edge", "M 180 262 L 180 360 M 221 262 L 221 360", gold, 1.8)
    for y in (276, 296, 316, 336, 352):
        it.circle("Button", 200.5, y, 2.4, "#f2c94c", INK, 1.2)
    collar(it, "#f6e7c2", 6)
    it.line("Collar gold", "M 172 254 C 186 270 215 270 229 254", gold, 1.6)


def filipiniana(it):
    rose = "#f3a6b8"
    it.path("Saya", dress(374, 8), side(it, rose, 0.18))
    for x in range(124, 286, 14):
        it.line("Saya stripe", "M %d 300 L %d 372" % (x, x), "#e98aa2", 3, "opacity:0.9")
    it.path("Gold hem", dress(374, 8).replace("M %d %d" % (X0, TOP), "M %d 360" % X0, 1).replace(
        "L %d %d L" % (X1, TOP), "L %d 360 L" % X1, 1), "#f2c94c", INK, 2.4)
    it.path("Bodice", "M %d %d L %d %d L %d 302 L %d 302 Z" % (X0, TOP, X1, TOP, X1, X0), side(it, "#ffc2d1", 0.16), None)
    it.path("Panuelo", "M 132 244 L 269 244 L 200.5 304 Z", "#fff6ea", INK, 3, "fill-opacity:0.92")
    it.line("Panuelo lace", "M 140 250 L 200.5 298 L 261 250", "#f2c94c", 2.2)
    for (x, y) in [(170, 262), (231, 262), (200.5, 278)]:
        it.path("Flower", star5(x, y, 4.5, 2.2), "#f2c94c", None)
    it.circle("Brooch", 200.5, 302, 5, "#f2c94c", INK, 2)
    it.circle("Brooch gem", 200.5, 302, 2.4, "#ff6f86", None)
    collar(it, "#fff6ea", 5)


# id: (function, name, tier, about)
TOPS = {
    "river_tee": (river_tee, "River tee", "copper", "a teal T-shirt with a river wave"),
    "striped_tee": (striped_tee, "Striped tee", "silver", "a cream T-shirt with orange stripes"),
    "book_tee": (book_tee, "Book tee", "silver", "a yellow T-shirt with an open book"),
    "jersey": (jersey, "Basketball jersey", "silver", "a blue jersey with white trim and a ball"),
    "sundress": (sundress, "Sundress", "silver", "a yellow dress with white flowers and a bow"),
    "dino_tee": (dino_tee, "Dino tee", "violet", "a green T-shirt with a dinosaur"),
    "hoodie": (hoodie, "Cozy hoodie", "violet", "a red hoodie with a pocket and drawstrings"),
    "party_dress": (party_dress, "Party dress", "violet", "a pink dress with tulle, a sash and sparkles"),
    "sailor_top": (sailor_top, "Sailor top", "violet", "a white top with a navy sailor collar"),
    "barong": (barong, "Barong", "gold", "a sheer barong with gold embroidery"),
    "filipiniana": (filipiniana, "Filipiniana dress", "gold", "a rose terno with a lace panuelo and gold hem"),
}


def build(iid):
    fn, name, tier, about = TOPS[iid]
    it = Item(iid, name, tier, "tops", about)
    fn(it)
    return it


if __name__ == "__main__":
    out = os.path.join(sys.argv[1], "tops")
    os.makedirs(out, exist_ok=True)
    for iid in TOPS:
        with open(os.path.join(out, iid + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(build(iid).svg())
        print("wrote tops/" + iid + ".svg")
