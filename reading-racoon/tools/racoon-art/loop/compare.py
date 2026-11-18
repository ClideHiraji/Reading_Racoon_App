"""Compare a 3D render round with the 2D drawing of option C.

    python compare.py <round_dir> <label> <ref_png>

Reads <round_dir>/racoon_C_3d_{front_match,side,back,three_quarter}.png, writes
<round_dir>/review.png and <round_dir>/metrics.json, and appends a line to log.jsonl.
Both front images are 800 x 800 with the same framing (2 px per px of the 400 px
drawing), so silhouettes and landmarks compare directly. Offsets are in 2D px.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

rdir, label, ref_path = sys.argv[1], sys.argv[2], sys.argv[3]
CREAM = (254, 253, 224)


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)


ref = load(ref_path)
d3 = load(os.path.join(rdir, "racoon_C_3d_front_match.png"))


def mask(a):
    return a[..., 3] > 128


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def landmarks(a):
    m = mask(a)
    ys, xs = np.nonzero(m)
    out = {}
    for name, sel in (("ear_left", xs < 400), ("ear_right", xs >= 400)):
        if sel.any():
            y = ys[sel].min()
            out[name] = (float(xs[sel][ys[sel] == y].mean()), float(y))
    x = xs.max()
    out["tail_tip"] = (float(x), float(ys[xs == x].mean()))
    out["feet"] = (float(xs[ys == ys.max()].mean()), float(ys.max()))
    yy, xx = np.mgrid[0:800, 0:800]
    dark = (lum(a) < 33) & (a[..., 3] > 200)
    for name, (cx, cy) in (("pupil_left", (315, 348)), ("pupil_right", (485, 348))):
        sel = dark & ((xx - cx) ** 2 + (yy - cy) ** 2 < 70 ** 2)
        if sel.sum() > 20:
            out[name] = (float(xx[sel].mean()), float(yy[sel].mean()))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    solid = a[..., 3] > 200
    teal = solid & (g - r > 40) & (b - r > 25)
    orange = solid & (r > 190) & (g > 90) & (g < 175) & (b < 90)
    for name, sel in (("scarf", teal), ("book_cover", orange)):
        if sel.sum() > 50:
            out[name] = (float(xx[sel].mean()), float(yy[sel].mean()))
    return out


m2, m3 = mask(ref), mask(d3)
iou = float((m2 & m3).sum() / max(1, (m2 | m3).sum()))
l2, l3 = landmarks(ref), landmarks(d3)
offsets = {}
for k in l2:
    if k in l3:
        dx, dy = (l3[k][0] - l2[k][0]) / 2, (l3[k][1] - l2[k][1]) / 2
        offsets[k] = {"dx": round(dx, 1), "dy": round(dy, 1), "dist": round((dx * dx + dy * dy) ** 0.5, 1)}
    else:
        offsets[k] = "missing in 3D"
checks_path = os.path.join(rdir, "checks.json")
checks = json.load(open(checks_path, encoding="utf-8")) if os.path.exists(checks_path) else {}
metrics = {"round": label, "iou": round(iou, 4), "offsets_2d_px": offsets, "checks": checks}
json.dump(metrics, open(os.path.join(rdir, "metrics.json"), "w", encoding="utf-8"), indent=1)
with open(os.path.join(os.path.dirname(rdir.rstrip("/\\")), "log.jsonl"), "a", encoding="utf-8") as fh:
    fh.write(json.dumps(metrics) + "\n")


# --- the review sheet ------------------------------------------------------------------------

def on_cream(img, size):
    bg = Image.new("RGBA", img.size, CREAM + (255,))
    bg.alpha_composite(img)
    return bg.convert("RGB").resize((size, size), Image.LANCZOS)


ref_img = Image.open(ref_path).convert("RGBA")
d3_img = Image.open(os.path.join(rdir, "racoon_C_3d_front_match.png")).convert("RGBA")
P = 400
sheet = Image.new("RGB", (P * 4, P * 2 + 40), CREAM)
sheet.paste(on_cream(ref_img, P), (0, 40))
sheet.paste(on_cream(d3_img, P), (P, 40))

# overlay: the 3D render, faded, with the 2D silhouette edge in magenta
edge2 = Image.fromarray((m2 * 255).astype(np.uint8))
edge2 = Image.fromarray(((np.asarray(edge2) > 0) & ~(np.asarray(edge2.filter(ImageFilter.MinFilter(5))) > 0)).astype(np.uint8) * 255)
ov = on_cream(d3_img, 800).convert("RGBA")
ov = Image.blend(Image.new("RGBA", ov.size, CREAM + (255,)), ov, 0.55)
mag = Image.new("RGBA", ov.size, (230, 0, 160, 255))
ov.paste(mag, (0, 0), edge2)
sheet.paste(ov.convert("RGB").resize((P, P), Image.LANCZOS), (2 * P, 40))

# difference: grey both, red only in 2D, blue only in 3D
diff = np.full((800, 800, 3), CREAM, dtype=np.uint8)
diff[m2 & m3] = (190, 186, 196)
diff[m2 & ~m3] = (220, 60, 60)
diff[~m2 & m3] = (60, 110, 220)
sheet.paste(Image.fromarray(diff).resize((P, P), Image.NEAREST), (3 * P, 40))

for i, view in enumerate(("side", "back", "three_quarter")):
    path = os.path.join(rdir, f"racoon_C_3d_{view}.png")
    if os.path.exists(path):
        sheet.paste(on_cream(Image.open(path).convert("RGBA"), P), (i * P, P + 40))

# game sizes: the 2D drawing on top, the 3D model below, at 180, 100 and 56 px
sizes = Image.new("RGB", (P, P), CREAM)
x = 10
for s in (180, 100, 56):
    sizes.paste(on_cream(ref_img, s), (x, 190 - s))
    sizes.paste(on_cream(d3_img, s), (x, 390 - s))
    x += s + 14
sheet.paste(sizes, (3 * P, P + 40))

draw = ImageDraw.Draw(sheet)
draw.text((8, 8), f"{label}   IoU {iou:.3f}   (2D | 3D | overlay: 2D edge in magenta | diff: red 2D only, blue 3D only)",
          fill=(58, 42, 31))
draw.text((8, 22), "   ".join(f"{k} {v['dist'] if isinstance(v, dict) else v}" for k, v in offsets.items()),
          fill=(58, 42, 31))
# the happy mood, when this round has it: 2D happy | 3D happy | 3D happy three-quarter
hp = os.path.join(rdir, "racoon_C_3d_front_match_happy.png")
ref_happy = ref_path.replace("ref_C_idle", "ref_C_happy")
if os.path.exists(hp) and os.path.exists(ref_happy):
    m2h, m3h = mask(load(ref_happy)), mask(load(hp))
    iou_h = float((m2h & m3h).sum() / max(1, (m2h | m3h).sum()))
    metrics["iou_happy"] = round(iou_h, 4)
    json.dump(metrics, open(os.path.join(rdir, "metrics.json"), "w", encoding="utf-8"), indent=1)
    big = Image.new("RGB", (P * 4, P * 3 + 40), CREAM)
    big.paste(sheet, (0, 0))
    big.paste(on_cream(Image.open(ref_happy).convert("RGBA"), P), (0, 2 * P + 40))
    big.paste(on_cream(Image.open(hp).convert("RGBA"), P), (P, 2 * P + 40))
    tq = os.path.join(rdir, "racoon_C_3d_three_quarter_happy.png")
    if os.path.exists(tq):
        big.paste(on_cream(Image.open(tq).convert("RGBA"), P), (2 * P, 2 * P + 40))
    ImageDraw.Draw(big).text((3 * P + 10, 2 * P + 60), f"happy: IoU {iou_h:.3f}", fill=(58, 42, 31))
    sheet = big
sheet.save(os.path.join(rdir, "review.png"))
print(json.dumps(metrics, indent=1))
