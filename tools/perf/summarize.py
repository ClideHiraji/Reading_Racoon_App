"""Per-phase frame stats from perf_tour.gd's JSON: python summarize.py frames.json [pass]"""
import json, sys
from collections import OrderedDict
fr = json.load(open(sys.argv[1]))
want = int(sys.argv[2]) if len(sys.argv) > 2 else None
ph = OrderedDict()
for p, name, wall, proc, rcpu, gpu in fr:
    if want and p != want:
        continue
    ph.setdefault((p, name), []).append((wall, proc, rcpu, gpu))
print("%-4s %-34s %5s %7s %7s %7s %6s %6s %8s %8s %7s" % ("pass", "phase", "n", "mean", "p95", "max", ">16.7", ">33", "maxProc", "meanProc", "maxRcpu"))
for (p, name), rows in ph.items():
    w = sorted(r[0] for r in rows)
    n = len(w)
    p95 = w[min(n - 1, int(n * 0.95))]
    print("%-4d %-34s %5d %7.2f %7.2f %7.1f %6d %6d %8.1f %8.2f %7.2f" % (p, name[:34], n, sum(w) / n, p95, w[-1],
          sum(1 for x in w if x > 16.7), sum(1 for x in w if x > 33.3), max(r[1] for r in rows), sum(r[1] for r in rows) / n, max(r[2] for r in rows)))
