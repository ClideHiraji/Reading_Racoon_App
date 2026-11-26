"""Builds the app icon (assets/brand/app_icon.svg) from the user's Racoon drawing
(tools/racoon-art/parts/racoon_C_inkscape.svg): his head and shoulders on a mango
rounded square with soft paper rays, like the game's sunburst (D-009, D-037).

    python tools/racoon-art/brand/make_icon.py    # run from reading-racoon/

Every line stays short (the editor dislikes very long lines). Inkscape-only markup is dropped.
"""
import math, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "tools", "racoon-art", "parts", "racoon_C_inkscape.svg")
OUT = os.path.join(ROOT, "assets", "brand", "app_icon.svg")
SIZE, RADIUS = 512, 112
MANGO, RAY, EDGE = "#ffc918", "#ffe27a", "#cc8a00"
SCALE, HEAD = 1.55, (200.0, 150.0)    # the drawing's head centre, set a little above the middle
AT = (256.0, 236.0)


def drawing_body(svg: str) -> str:
    """The drawing's defs and layers, without the Inkscape and Sodipodi markup."""
    svg = re.sub(r"<sodipodi:namedview.*?</sodipodi:namedview>", "", svg, flags=re.S)
    svg = re.sub(r"<sodipodi:namedview[^>]*/>", "", svg, flags=re.S)
    svg = re.sub(r"<inkscape:[a-z]+[^>]*/>", "", svg, flags=re.S)
    svg = re.sub(r"<title.*?</title>", "", svg, flags=re.S)
    svg = re.sub(r'\s(inkscape|sodipodi):[a-zA-Z-]+="[^"]*"', "", svg)
    inner = svg[svg.index(">", svg.index("<svg")) + 1: svg.rindex("</svg>")]
    return inner.strip()


def rays() -> str:
    out = []
    c, r, n = SIZE / 2, SIZE, 14
    for i in range(n):
        a, w = math.tau * i / n, math.tau / n * 0.32
        p = [(c, c), (c + r * math.cos(a - w), c + r * math.sin(a - w)), (c + r * math.cos(a + w), c + r * math.sin(a + w))]
        out.append('<path fill="%s" opacity="0.55" d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z"/>' % ((RAY,) + sum(p, ())))
    return "\n".join(out)


def wrap(text: str, width: int = 96) -> str:
    """Breaks long lines at a space, or just after a ';' or ','. Inside attribute values a
    newline reads as a space, which path data and style declarations both allow there."""
    lines = []
    for line in text.split("\n"):
        while len(line) > width:
            indent = len(line) - len(line.lstrip())
            cut = max(line.rfind(" ", 0, width), line.rfind(";", 0, width) + 1, line.rfind(",", 0, width) + 1)
            if cut <= indent:
                break
            lines.append(line[:cut].rstrip())
            line = "  " + line[cut:].lstrip()
        lines.append(line)
    return "\n".join(lines)


def main() -> None:
    body = drawing_body(open(SRC, encoding="utf-8").read())
    tx, ty = AT[0] - HEAD[0] * SCALE, AT[1] - HEAD[1] * SCALE
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
  width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
<title>Reading Racoon</title>
<defs>
<clipPath id="tile"><rect width="{SIZE}" height="{SIZE}" rx="{RADIUS}"/></clipPath>
</defs>
<g clip-path="url(#tile)">
<rect width="{SIZE}" height="{SIZE}" fill="{MANGO}"/>
{rays()}
<g transform="translate({tx:.2f} {ty:.2f}) scale({SCALE})">
{body}
</g>
</g>
<rect x="6" y="6" width="{SIZE - 12}" height="{SIZE - 12}" rx="{RADIUS - 6}" fill="none"
  stroke="{EDGE}" stroke-opacity="0.35" stroke-width="12"/>
</svg>
"""
    svg = wrap(svg)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8", newline="\n").write(svg)
    print(OUT, len(svg), "chars, longest line", max(len(l) for l in svg.split("\n")))


if __name__ == "__main__":
    main()
