"""Measures each paper-mode picture and writes fit.json: a square view box round what's drawn, so every
picture fills its box the same way in the game (D-027).

    python fit.py "<Godot.exe>" <scratch Godot project with fit_render.gd>

Run it after changing a drawing's size or adding a picture. Use a scratch Godot project (copy
fit_render.gd into an empty folder with a project.godot), never the game's own folder.
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import icon_set  # noqa: E402

SCALE = 4          # render at 512 px for a precise edge
MARGIN = 2.5       # drawing units left round the picture


def main():
    godot, project = sys.argv[1], sys.argv[2]
    icon_set.FIT.clear()
    work = tempfile.mkdtemp(prefix="icon_fit_")
    svg_dir, png_dir = os.path.join(work, "svg"), os.path.join(work, "png")
    os.makedirs(svg_dir)
    os.makedirs(png_dir)
    for n in icon_set.ICONS:
        with open(os.path.join(svg_dir, n + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(icon_set.draw(n, mode="paper").svg())
    out = subprocess.run([godot, "--headless", "--path", project, "-s", "fit_render.gd", "--", svg_dir.replace("\\", "/"), png_dir.replace("\\", "/"),
                          str(SCALE)], capture_output=True, text=True)
    print("\n".join(l for l in out.stdout.splitlines() if "fit_render" in l))
    fit = {}
    for n in icon_set.ICONS:
        im = Image.open(os.path.join(png_dir, n + ".png")).convert("RGBA")
        box = im.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
        x0, y0, x1, y1 = (v / SCALE for v in box)
        side = max(x1 - x0, y1 - y0) + 2 * MARGIN
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        fit[n] = [round(cx - side / 2, 2), round(cy - side / 2, 2), round(side, 2), round(side, 2)]
    with open(os.path.join(HERE, "fit.json"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("{\n" + ",\n".join('  "%s": %s' % (n, json.dumps(v)) for n, v in sorted(fit.items())) + "\n}\n")
    print("fit.json:", len(fit), "pictures")


if __name__ == "__main__":
    main()
