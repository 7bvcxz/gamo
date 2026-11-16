#!/usr/bin/env python3
"""Step 25: turns tools/sim/economy.gd's output into a report with SVG charts (no libraries).
   python3 economy_report.py <sim_out_dir> <report_dir>"""
import csv, json, os, statistics, sys

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
rows = list(csv.DictReader(open(f"{src}/runs.csv")))
buys = list(csv.DictReader(open(f"{src}/purchases.csv")))
summ = json.load(open(f"{src}/summary.json"))
runs = [k for k in summ if not k.startswith("_")]
COL = ["#d6352a", "#e8a93a", "#3a8fd6", "#58b368", "#8e5bd6", "#555555", "#c06090", "#2aa5a0", "#a0522d"]

def line_chart(name, key, title, ylab):
    W, H, L, B = 760, 380, 60, 40
    series = {r: [(int(x["min"]), float(x[key])) for x in rows if x["run"] == r] for r in runs}
    xmax = max(m for s in series.values() for m, _ in s)
    ymax = max(v for s in series.values() for _, v in s) or 1
    sx = lambda m: L + (W - L - 180) * m / xmax
    sy = lambda v: H - B - (H - B - 30) * v / ymax
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="sans-serif" font-size="12">',
           f'<rect width="{W}" height="{H}" fill="white"/><text x="{L}" y="18" font-size="14">{title}</text>',
           f'<line x1="{L}" y1="{H-B}" x2="{W-180}" y2="{H-B}" stroke="#333"/><line x1="{L}" y1="30" x2="{L}" y2="{H-B}" stroke="#333"/>']
    for t in (0, 10, 30, 60):
        if t <= xmax:
            out.append(f'<line x1="{sx(t):.0f}" y1="{H-B}" x2="{sx(t):.0f}" y2="30" stroke="#ddd"/><text x="{sx(t)-6:.0f}" y="{H-B+16}">{t}m</text>')
    for k in range(5):
        v = ymax * k / 4
        out.append(f'<text x="4" y="{sy(v)+4:.0f}">{v:,.0f}</text>')
    for i, (r, s) in enumerate(series.items()):
        pts = " ".join(f"{sx(m):.1f},{sy(v):.1f}" for m, v in s)
        out.append(f'<polyline points="{pts}" fill="none" stroke="{COL[i % len(COL)]}" stroke-width="2"/>')
        out.append(f'<rect x="{W-170}" y="{34+i*18}" width="12" height="12" fill="{COL[i % len(COL)]}"/><text x="{W-152}" y="{44+i*18}">{r}</text>')
    out.append(f'<text x="{L}" y="{H-6}" fill="#666">{ylab}</text></svg>')
    open(f"{dst}/{name}.svg", "w").write("\n".join(out))

def strip_chart():
    W, rowh, L = 760, 22, 130
    cols = {"production": "#d6352a", "packaging": "#e8a93a", "demand": "#3a8fd6", "": "#e8e8e8"}
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{40+rowh*len(runs)+30}" font-family="sans-serif" font-size="12">',
           '<rect width="100%" height="100%" fill="white"/><text x="10" y="18" font-size="14">The bottleneck at each minute (red production, amber packaging, blue demand, grey none)</text>']
    for i, r in enumerate(runs):
        ms = [x for x in rows if x["run"] == r]
        w = (W - L - 10) / max(1, len(ms))
        out.append(f'<text x="6" y="{44+i*rowh+14}">{r}</text>')
        for j, x in enumerate(ms):
            out.append(f'<rect x="{L+j*w:.1f}" y="{44+i*rowh}" width="{w+0.5:.1f}" height="{rowh-4}" fill="{cols.get(x["bottleneck"], "#ccc")}"/>')
    out.append("</svg>")
    open(f"{dst}/bottleneck_strip.svg", "w").write("\n".join(out))

line_chart("revenue", "revenue", "Revenue over time, by hand and purchase policy (simulated)", "minutes (revenue in coins)")
line_chart("served_per_min", "served_pm", "Portions served per minute (simulated)", "minutes (portions a minute)")
strip_chart()

L = ["# Step 25 — 공장 경제 보고 (시뮬레이션)", "",
     "**이것은 시뮬레이션의 목표치이지 플레이어의 재미가 아니다.** 같은 규칙 코드(`variants/factory/factory_rules.gd`)를 손 모델과 구매 정책이 돌렸다(`tools/sim/economy.gd`, 시드 20261116). 매 분 보존을 단언했다: 모든 인분이 어딘가에 있고, 돈 = 매출 − 구매 − 유지비, 돈은 음수가 되지 않는다.", "",
     "손: fast(반응 0.3초, 완벽 80%), average(1초, 50%), slow(8초, 30%·탐 5%), specialist(0.3초, 95%), idle(30초). 정책: early(지금 병목을 푸는 것을 살 수 있으면 바로), late(값의 두 배가 모이면), supply(간판을 사지 않음), demand(간판만), auto(자동 냄비 위주).", "",
     "![매출](revenue.svg)", "", "![분당 판매 인분](served_per_min.svg)", "", "![분마다의 병목](bottleneck_strip.svg)", "",
     "## 3·10·30·60분", "", "| 판 | 분 | 매출 | 판매 | 놓친 손님 | 냄비 | 포장대 | 간판 | 자동 냄비 | 유지비 | 첫 구매 |", "|---|---|---|---|---|---|---|---|---|---|---|"]
for r in runs:
    m = summ[r]["marks"]
    for t in ("3", "10", "30", "60"):
        if t in m:
            x = m[t]
            L.append(f"| {r} | {t} | {x['revenue']:,} | {x['sold']} | {x['lost']} | {x['kettle']} | {x['station']} | {x['sign']} | {x['cookers']} | {x['upkeep']} | {x['first_purchase_s']:.0f}초 |")
L += ["", "## 병목이 차지한 시간 (60분)", "", "| 판 | 생산 | 포장 | 수요 |", "|---|---|---|---|"]
for r in runs:
    s = summ[r]["shares"]
    L.append(f"| {r} | {s['production']:.0%} | {s['packaging']:.0%} | {s['demand']:.0%} |")
L += ["", "## 구매가 본전을 찾는 시간 (전 2분 대비 후 2분의 분당 매출 증가로 추정)", "", "| 무엇 | 횟수 | 중앙 값 | 본전(분) 중앙 | 본전을 못 찾은 구매 |", "|---|---|---|---|---|"]
by = {}
for b in buys:
    by.setdefault(b["what"], []).append(b)
L.insert(len(L) - 2, "")
own = {"buy": "production", "buy_packer": "packaging", "buy_sign": "demand", "buy_auto": "production"}
for w, bs in sorted(by.items()):
    mine = [b for b in bs if b["bottleneck"] == own[w] or (w == "buy_sign" and b["bottleneck"] == "")]
    pm = [float(b["payback_min"]) for b in mine if float(b["payback_min"]) > 0]
    if mine:
        L.append(f"| {w} — 제 병목일 때 산 것 | {len(mine)} | {statistics.median(int(b['cost']) for b in mine):,.0f} | {(statistics.median(pm) if pm else float('nan')):.1f} | {len(mine)-len(pm)} |")
for w, bs in sorted(by.items()):
    pays = [float(b["payback_min"]) for b in bs if float(b["payback_min"]) > 0]
    L.append(f"| {w} | {len(bs)} | {statistics.median(int(b['cost']) for b in bs):,.0f} | {statistics.median(pays):.1f} | {len(bs)-len(pays)} |" if pays else f"| {w} | {len(bs)} | {statistics.median(int(b['cost']) for b in bs):,.0f} | — | {len(bs)} |")
L += ["", "## 경계 상황", "", "| 상황 | 분 | 만든 인분 | 판매 | 매출 | 놓친 손님 | 유지비 | 남은 재고(인분) | 미납 정지(초) | 막힘(냄비·초) | 분당 순이익 |", "|---|---|---|---|---|---|---|---|---|---|---|"]
for k, v in summ["_scenarios"].items():
    L.append(f"| {k} | {v['minutes']:.1f} | {v['made']} | {v['sold']} | {v['revenue']:,} | {v['lost']} | {v['upkeep']} | {v['stock_portions']} | {v['unpaid_ms']/1000:.0f} | {v['blocked_ms']/1000:,.0f} | {v['net_per_min']:.1f} |")
open(f"{dst}/REPORT.md", "w").write("\n".join(L) + "\n")
print("ok", dst)
