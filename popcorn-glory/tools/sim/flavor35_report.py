#!/usr/bin/env python3
"""Step 35: the flavor craftsmanship hour as a table (from tools/sim/flavor35.gd's JSON).

    python3 popcorn-glory/tools/sim/flavor35_report.py <flavor35.json> <out.md>
"""
import json
import sys

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
runs = d["runs"]
base = runs["paused"]["net_per_min"]

NAMES = {
    "paused": "코팅기 모두 멈춤 (기준)",
    "machines": "기계 혼자 (단계 0)",
    "hand_skilled": "숙련 손이 마무리 (완벽 80%)",
    "hand_average": "보통 손이 마무리 (완벽 50%)",
    "auto_mode": "AUTO 넷, 기계 혼자",
    "auto_mode_hand": "AUTO 넷 + 숙련 손",
    "tier2_machines": "기계 혼자, 코팅기 단계 2",
    "low_demand_paused": "수요 ×0.5 · 멈춤",
    "low_demand_machines": "수요 ×0.5 · 기계 혼자",
    "low_demand_hand": "수요 ×0.5 · 숙련 손",
    "high_demand_paused": "수요 ×1.5 · 멈춤",
    "high_demand_machines": "수요 ×1.5 · 기계 혼자",
    "high_demand_hand": "수요 ×1.5 · 숙련 손",
    "high_demand_tier2": "수요 ×1.5 · 단계 2",
    "craze_machines": "수요 ×2 (모두 맛) · 기계 혼자",
    "craze_tier2": "수요 ×2 · 단계 2",
    "craze_hand": "수요 ×2 · 숙련 손",
}

lines = []
lines.append("# Step 35 — 손 마무리, 기계의 품질과 손실, 섞은 봉지, AUTO, 특선 (시뮬레이션)")
lines.append("")
lines.append(f"`tools/sim/flavor35.gd` {d['minutes']}분 판. Step 34의 맛 공장(포장 줄 둘, 코팅기 넷, M12, 간판 6)을 정책과 수요만 바꿔 같은 시드로 돌렸다. "
             "손은 4.5초마다 냄비를 1.5초 누르고, 마무리 정책이면 그 사이에 드럼의 판 하나를 숟가락으로 끝낸다(숟가락을 쥔 동안 냄비는 누르지 않는다). "
             "순이익 = 매출 − 유지비 − 낟알·기름 − 재료 코인. **시뮬레이션의 목표값이며 플레이어의 재미가 아니다.**")
lines.append("")
lines.append("| 판 | 분당 순이익 | 기준 대비 | 판매 | 놓친 손님(떠남+지나감) | 섞은 봉지 | 손 마무리 인분 | 잃은 인분 | 재료 코인 |")
lines.append("|---|---|---|---|---|---|---|---|---|")
for k, name in NAMES.items():
    if k not in runs:
        continue
    r = runs[k]
    pb = "paused" if not k.startswith(("low", "high", "craze")) else ("low_demand_paused" if k.startswith("low") else "high_demand_paused")
    if k.startswith("craze"):
        pb = "paused"
    rel = (r["net_per_min"] / runs[pb]["net_per_min"] - 1.0) * 100.0
    lines.append(f"| {name} | {r['net_per_min']:.1f} | {rel:+.1f}% | {r['sold']} | {r['abandoned']}+{r['passed_by']} | {r['mix_sold']} | {r['hand_portions']} | {r['lost_portions']} | {r['ingredient_coins']} |")
lines.append("")
lines.append("기준 대비: 같은 수요의 '멈춤' 판(수요 ×2는 맛이 없으면 주문이 바뀌지 않으므로 기본 멈춤 판)과 비교.")
lines.append("")
lines.append("## 맛별 판매와 손 마무리의 판정")
lines.append("")
lines.append("| 판 | 치즈 | 매콤 | 카라멜 | 코코아 | 손 판정 (완벽/좋음/이름/늦음) |")
lines.append("|---|---|---|---|---|---|")
for k in ["machines", "hand_skilled", "hand_average", "auto_mode", "auto_mode_hand", "tier2_machines"]:
    r = runs[k]
    fs = r["flavor_sold"]
    hf = r["hand_finish"]
    lines.append(f"| {NAMES[k]} | {fs.get('cheese', 0)} | {fs.get('spicy', 0)} | {fs.get('caramel', 0)} | {fs.get('cocoa', 0)} | "
                 f"{hf.get('perfect', 0)}/{hf.get('near', 0)}/{hf.get('early', 0)}/{hf.get('late', 0)} |")
lines.append("")
lines.append("## 코팅기의 본전: 짓기 전 추정 대 실제 (기계 혼자, 단계 0)")
lines.append("")
lines.append("| 코팅기 | 낸 값 | 추정 분당 순 | 추정 본전(분) | 실제 분당 순 | 실제 본전(분) | 마진 | 재료 | 유지비 |")
lines.append("|---|---|---|---|---|---|---|---|---|")
for k in ["machines", "hand_skilled", "tier2_machines"]:
    for fl, c in runs[k]["coaters"].items():
        e = c["estimate"]
        pb = c["paid_back_min"]
        lines.append(f"| {NAMES[k]} · {fl} | {c['paid']} | {e.get('net_per_min')} | {e.get('payback_min')} | {c['net_per_min']} | {pb if pb >= 0 else '아직'} | {c['margin']} | {c['ingredients']} | {c['upkeep']} |")
lines.append("")
lines.append("추정은 간판의 손님 수 × 그 맛의 몫 × 평균 봉지 크기와 기계의 능력 중 작은 것으로 셈한다(줄의 다른 맛·섞은 봉지·옆에서 기다림은 모른다). "
             "실제는 그 기계가 코팅한 인분이 든 봉지가 같은 크기·품질의 버터 봉지보다 더 받은 돈의 몫에서 재료와 유지비를 뺀 것이다.")
lines.append("")
lines.append("## 남은 맛의 회복 (특선)")
lines.append("")
sp = d["surplus"]
lines.append("남은 매콤 24인분(분무기는 멈춤)을 작은 봉지 한 개만큼 남을 때까지 판 시간:")
lines.append("")
lines.append("| | 특선이 켜진 때 | 다 판 때 | 매콤 판매 | 떠난 손님 |")
lines.append("|---|---|---|---|---|")
for k, name in [("special", "특선 있음"), ("no_special", "특선 없음")]:
    r = sp[k]
    lines.append(f"| {name} | {r['special_on_s']}초 | {r['sold_down_min']}분 | {r['spicy_sold']} | {r['abandoned']} |")
open(out, "w").write("\n".join(lines) + "\n")
print("wrote", out)
