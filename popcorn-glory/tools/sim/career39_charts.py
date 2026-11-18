#!/usr/bin/env python3
"""Step 39: SVG charts and an HTML page from the career sim's own CSV (tools/sim/career39.gd).
AUTOMATIC SIMULATION -- simulated hands and purchase policies on the game's rules, not players.
   python3 career39_charts.py <out_dir> <after_dir> [<before_dir>]
Each chart draws the after run (solid) and, when given, the before run (dashed) of the same
hand/policy/seed. Nothing here is typed in by hand: every point is a row of career.csv."""
import csv, html, json, os, sys, collections

METRICS = [
    ("made_pm", "portions made a minute (production)"),
    ("packed_pm", "packs sealed a minute (packaging)"),
    ("sold_pm", "customers served a minute (service)"),
    ("lost_pm", "customers lost a minute (left or passed by)"),
    ("net_pm", "net coins a minute (sales - upkeep - inputs)"),
    ("upkeep_pm", "upkeep coins a minute"),
    ("money", "coins in the wallet"),
    ("machines", "machines built"),
    ("running", "machines working (this minute)"),
    ("stock", "stock: bin portions + shelf packs"),
]
COLORS = ["#c0392b", "#2471a3", "#1e8449", "#b9770e", "#7d3c98", "#117a65", "#566573", "#a04000", "#1f618d", "#922b21", "#196f3d"]


def load(d):
    by = collections.defaultdict(list)
    for r in csv.DictReader(open(os.path.join(d, "career.csv"))):
        r["stock"] = str(float(r["bin"]) + float(r["shelf"]))
        by[r["run"]].append(r)
    return by


def chart(title, series, w=560, h=250):
    """series: [(label, color, dashed, [(x, y)])] -> an SVG string."""
    pad_l, pad_b, pad_t, pad_r = 52, 30, 26, 10
    xs = [x for s in series for x, _ in s[3]] or [0, 1]
    ys = [y for s in series for _, y in s[3]] or [0, 1]
    x0, x1 = 0, max(xs) or 1
    y0, y1 = min(0, min(ys)), max(ys) or 1
    if y1 == y0:
        y1 = y0 + 1
    X = lambda x: pad_l + (x - x0) / (x1 - x0) * (w - pad_l - pad_r)
    Y = lambda y: h - pad_b - (y - y0) / (y1 - y0) * (h - pad_b - pad_t)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" font-family="sans-serif" font-size="11">',
           f'<rect width="{w}" height="{h}" fill="#fffdf8"/>',
           f'<text x="{pad_l}" y="15" font-size="12" font-weight="bold">{html.escape(title)}</text>',
           f'<text x="{w - pad_r}" y="15" text-anchor="end" fill="#a00" font-size="10">AUTOMATIC SIMULATION</text>']
    for k in range(5):
        yv = y0 + (y1 - y0) * k / 4
        out.append(f'<line x1="{pad_l}" x2="{w - pad_r}" y1="{Y(yv):.1f}" y2="{Y(yv):.1f}" stroke="#e5e1d8"/>')
        out.append(f'<text x="{pad_l - 4}" y="{Y(yv) + 4:.1f}" text-anchor="end" fill="#555">{yv:,.0f}</text>')
    for m in range(0, int(x1) + 1, 10):
        out.append(f'<text x="{X(m):.1f}" y="{h - 12}" text-anchor="middle" fill="#555">{m}</text>')
    out.append(f'<text x="{w - pad_r}" y="{h - 1}" text-anchor="end" fill="#555">minutes</text>')
    for label, color, dashed, pts in series:
        if not pts:
            continue
        d = " ".join(f"{X(x):.1f},{Y(y):.1f}" for x, y in pts)
        dash = ' stroke-dasharray="5,4" stroke-opacity="0.6"' if dashed else ""
        out.append(f'<polyline fill="none" stroke="{color}" stroke-width="1.8"{dash} points="{d}"><title>{html.escape(label)}</title></polyline>')
    out.append("</svg>")
    return "\n".join(out)


def main():
    out, after = sys.argv[1], sys.argv[2]
    before = sys.argv[3] if len(sys.argv) > 3 else None
    os.makedirs(out, exist_ok=True)
    A = load(after)
    B = load(before) if before else {}
    runs = sorted(A.keys())
    files = []
    # the overview charts: one seed, the four hands on the balanced policy and two other policies
    # (every run has its own floors chart below)
    main = [r for r in runs if r.endswith("/3901") and (r.split("/")[1] == "balanced" or r.startswith("average/early") or r.startswith("average/variety"))] or runs
    for metric, title in METRICS:
        series = []
        for i, run in enumerate(main):
            c = COLORS[i % len(COLORS)]
            series.append((run + " (after)", c, False, [(int(r["min"]), float(r[metric])) for r in A[run]]))
            if run in B:
                series.append((run + " (before)", c, True, [(int(r["min"]), float(r[metric])) for r in B[run]]))
        name = f"{metric}.svg"
        open(os.path.join(out, name), "w").write(chart(title, series))
        files.append((name, title))
    # one chart per run: the three floors' rates against each other (where the line binds)
    for i, run in enumerate(runs):
        rs = A[run]
        series = [("made / 2.3 (bag-equivalents)", "#b9770e", False, [(int(r["min"]), float(r["made_pm"]) / 2.3) for r in rs]),
                  ("packed", "#2471a3", False, [(int(r["min"]), float(r["packed_pm"])) for r in rs]),
                  ("served", "#1e8449", False, [(int(r["min"]), float(r["sold_pm"])) for r in rs]),
                  ("lost", "#c0392b", False, [(int(r["min"]), float(r["lost_pm"])) for r in rs])]
        name = "floors_" + run.replace("/", "_") + ".svg"
        open(os.path.join(out, name), "w").write(chart(f"{run}: made / packed / served / lost a minute", series))
        files.append((name, run))
    legend = "".join(f'<li><span style="color:{COLORS[i % len(COLORS)]}">&#9632;</span> {html.escape(r)}</li>' for i, r in enumerate(main))
    imgs = "".join(f'<figure><img src="{n}" alt="{html.escape(t)}"><figcaption>{html.escape(t)}</figcaption></figure>' for n, t in files)
    page = f"""<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Popcorn career curves</title>
<style>body{{font-family:sans-serif;background:#f6f2ea;color:#222;margin:16px}}figure{{display:inline-block;margin:6px}}img{{max-width:100%;height:auto;border:1px solid #ddd}}
.warn{{color:#a00;font-weight:bold}}</style>
<h1>Popcorn Glory — career curves (Step 39)</h1>
<p class="warn">AUTOMATIC SIMULATION: simulated hands and purchase policies on the game's own rules
(tools/sim/career39.gd). Not players, not fun ratings. Solid: after the Step 39 tuning; dashed: before.</p>
<p>Data: <a href="../career_after.csv">career_after.csv</a>{' · <a href="../career_before.csv">career_before.csv</a>' if before else ''} · <a href="../career_after.json">career_after.json</a> · <a href="../traps_after.json">traps_after.json</a></p>
<ul>{legend}</ul>{imgs}"""
    open(os.path.join(out, "index.html"), "w").write(page)
    print(json.dumps({"charts": len(files), "runs": len(runs)}))


if __name__ == "__main__":
    main()
