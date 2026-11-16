#!/usr/bin/env python3
"""Step 27: design/MACHINES.md from data/machines.json (the table, the unlock map, the no-fake
matrix). python3 tools/catalog/catalog_doc.py"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
doc = json.load(open(os.path.join(HERE, "..", "..", "data", "machines.json")))
ms, have = doc["machines"], doc["systems_present"]
G = {"manufacturing": "제조 기초", "advanced": "제조 고급", "packaging": "포장", "storefront": "가게", "support": "보조"}
def pre(p):
    bits = []
    if p.get("sign"): bits.append(f"간판 {p['sign']}")
    if p.get("packer"): bits.append(f"포장대 {p['packer']}")
    if p.get("machines"): bits.append("+" + ",".join(p["machines"]))
    return " · ".join(bits) or "—"
def contract(c):
    return c["kind"] + (" (" + ", ".join(f"{k}={v}" for k, v in c.items() if k != "kind") + ")" if len(c) > 1 else "")
L = ["# MACHINES — 기계 40종 카탈로그 (Step 27, 생성 문서)", "",
     "`data/machines.json`이 단일 원본이다(생성: `tools/catalog/build_catalog.py`, 이 문서: `tools/catalog/catalog_doc.py`). 그림은 게임 안 `#machines`(실제 자리 크기, 다섯 묶음 × 8, 그 아래 40대가 층에 접힌 배치). 수치는 [proposal].", "",
     "**가짜 효과 없음**: 모델에서 돌지 않는 기계(`runtime` 없음)나 아직 없는 체계(`requires`)가 필요한 기계는 지을 수 없고 아무것도 약속하지 않는다(`err.not_yet`, 시험 `test_no_machine_is_sold_that_would_do_nothing`). 지금 있는 체계: " + ", ".join(have) + ".", "",
     "## 해금 지도 (간판 단계 → 열리는 기계)", "", "| 간판 | 열리는 기계 |", "|---|---|"]
by = {}
for m in ms:
    by.setdefault(m["prereq"].get("sign", 0), []).append(m)
for s in sorted(by):
    L.append(f"| {s} | " + ", ".join(f"{m['id']}{' ●' if m['runtime'] else ''}" for m in by[s]) + " |")
L += ["", "● = 지금 돈다(Step 26: M07 자동 냄비, P03 부피 충전기, S07 셀프 키오스크).", ""]
for g in G:
    rows = [m for m in ms if m["group"] == g]
    L += [f"## {G[g]} ({rows[0]['id']}–{rows[-1]['id']}, Step {rows[0]['step'] if not rows[0]['runtime'] else rows[1]['step']})", "",
          "| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |", "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for m in rows:
        missing = [r for r in m["requires"] if r not in have]
        state = "돈다" if m["runtime"] and not missing else ("체계 대기: " + ", ".join(missing) if missing else f"Step {m['step']}")
        tiers = " / ".join(", ".join(f"{k} {v}" for k, v in t.items() if k != "cost") or "—" for t in m["tiers"])
        L.append(f"| {m['id']} | {m['name']} | {m['floor']} · {m['slots']} | {m['motion']} | {contract(m['contract'])} | {', '.join(m['inputs']) or '—'} → {', '.join(m['outputs'])} | {m['queue']} | {pre(m['prereq'])} | {', '.join(m['requires']) or '—'} | {m['cost']} / {m['upkeep_per_min']}분 | {tiers} | {m['marginal']} | {state} |")
    L.append("")
L += ["## 다른 체계와의 고리 (아직 없는 것)", "",
      "| 체계 | 기다리는 기계 | 생기는 Step |", "|---|---|---|"]
need = {}
for m in ms:
    for r in m["requires"]:
        if r not in have:
            need.setdefault(r, []).append(m["id"])
steps = {"flavors": 34, "news": 37, "customer_preferences": 36, "kernels": 28, "oil": 28, "heat_model": "28–29", "premium_sku": 29, "cup_sku": 30,
         "portion_variance": 30, "multi_queue": 31, "four_lanes": 31, "faults": 32, "aging": 32, "parallel_lines": 33}
for r, ids in sorted(need.items()):
    L.append(f"| {r} | {', '.join(ids)} | {steps.get(r, '—')} |")
L += ["", "## 40대가 함께 (Step 33)", "",
      "- 층마다 자리가 늘어난다(지금 부엌 4·가운데층 3·가게 2 → M10이 부엌 +2–4, Step 33에서 층마다 줄을 더해 40 자리). 기계 40대는 같은 크기의 작은 그림으로 층마다 줄지어 접히고(`#machines` 아래 배치), 고르면 펼쳐진다.",
      "- 같은 종류를 여러 대 둘 수 있다(값은 대수마다 ×1.25). 40대는 실행기의 상한(`auto_cooker.max`)이고, 수요가 상한일 때 남는 기계는 막혀 쉬고 유지비를 내지 않는다(Step 25 시뮬레이션).", ""]
open(os.path.join(HERE, "..", "..", "design", "MACHINES.md"), "w").write("\n".join(L) + "\n")
print("ok")
