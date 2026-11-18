#!/bin/bash
# One loop round for the 3D Racoon (D-024): render in Blender, compare with the 2D drawing,
# test in the game, and keep everything in <scratch>/round<n>/.
#
#   NSP=<scratch folder> bash round.sh <n>
#
# The scratch folder must hold rr/, a copy of the game (never reading-racoon/ itself while the
# editor is open; see README). The 2D references go to <scratch>/ref/ on the first run, from
# out/racoon_C_idle.svg and out/racoon_C_happy.svg (run make_racoons.py first).
set -u
N="$1"
NSP="${NSP:?set NSP to the scratch folder that holds rr/}"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.0/blender.exe}"
GODOT="${GODOT:-/c/Program Files/Godot/Godot.exe}"
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ART="$(dirname "$HERE")"
R="$NSP/round$N"

case "$(cd "$NSP/rr" 2>/dev/null && pwd)" in
  "" ) echo "no game copy at $NSP/rr"; exit 1 ;;
  */reading-racoon ) echo "rr must be a scratch copy, not the game itself"; exit 1 ;;
esac

# the 2D drawing at 800 x 800, framed like the 3D front_match render (2 px per drawing px)
mkdir -p "$NSP/ref"
for mood in idle happy; do
  if [ ! -f "$NSP/ref/ref_C_$mood.png" ]; then
    cp "$ART/out/racoon_C_$mood.svg" "$NSP/ref/" || exit 1
    printf '<html><head><style>html,body{margin:0;background:transparent}</style></head><body><img src="racoon_C_%s.svg" width="800" height="800"></body></html>' \
      "$mood" > "$NSP/ref/c_$mood.html"
    # software rasterising (--disable-gpu) keeps the edges the same from run to run
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$(cygpath -w "$NSP/chrome_tmp")" \
      --default-background-color=00000000 --window-size=800,800 --screenshot="$(cygpath -w "$NSP/ref/ref_C_$mood.png")" "file:///$(cygpath -m "$NSP/ref/c_$mood.html")" 2>/dev/null
  fi
done

mkdir -p "$R"
cp "$ART/racoon_3d.py" "$R/racoon_3d.py"
echo "== render"
t0=$(date +%s)
"$BLENDER" -b --factory-startup --python-exit-code 1 -P "$R/racoon_3d.py" -- "$(cygpath -w "$R")" > "$R/blender.log" 2>&1
echo "blender exit $? in $(( $(date +%s) - t0 )) s"
grep -E "Error|Traceback|line [0-9]+," "$R/blender.log" | head -8

echo "== compare"
python "$HERE/compare.py" "$(cygpath -w "$R")" "round $N" "$(cygpath -w "$NSP/ref/ref_C_idle.png")" | head -60

echo "== in game"
"$GODOT" --path "$NSP/rr" --resolution 576x1024 -s "$HERE/ingame.gd" -- \
  "$(cygpath -w "$R/racoon_C_3d_front_match.png")" "$(cygpath -w "$R")" > "$R/godot.log" 2>&1
grep -E "SCRIPT ERROR" "$R/godot.log" | sort | uniq -c | head -5
python - "$R" <<'PYEOF'
import os
import sys

from PIL import Image

r = sys.argv[1]
names = ["ingame_home", "ingame_lesson", "ingame_practice"]
ims = [Image.open(os.path.join(r, n + ".png")).convert("RGB") for n in names if os.path.exists(os.path.join(r, n + ".png"))]
if ims:
    w, h = ims[0].size
    sheet = Image.new("RGB", (w * len(ims), h), (255, 255, 255))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * w, 0))
    sheet.save(os.path.join(r, "ingame.png"))
    print("ingame sheet", sheet.size)
PYEOF
