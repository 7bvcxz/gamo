#!/usr/bin/env python3
"""Step 39: the issue's linearization traps, measured on the career sim's output (AUTOMATIC
SIMULATION -- simulated hands and policies on the game's rules, not players).
   python3 career39_traps.py <dir>   -> prints JSON (and writes <dir>/traps.json)
Each check names what it measures; a trap is flagged only by these numbers."""
import csv, json, os, sys, statistics, collections

KITCHEN = {"M%02d" % i for i in range(1, 17)} | {"kettle"}
FLOOR = lambda w: ("sign" if w == "sign" else "station" if w == "packer" else "kettle" if w == "kettle" else
                   "line" if w.startswith("line:") else "coater" if w in ("P05", "P06") else
                   "kitchen" if w in KITCHEN else "packing" if w.startswith("P") or w == "bagger" or w in ("U04", "U05", "U08") else
                   "shop" if w.startswith("S") or w == "kiosk" or w == "U07" else "support")
MILESTONE_TARGETS = {   # minutes for the average hand: the Step 39 schedule (design/PROGRESSION.md 1)
    "first_sale": [0, 0.5], "first_packing_line": [5, 20], "first_auto_cooker": [10, 25], "first_flavor_line": [15, 50],
    "first_contest_win": [3, 25], "three_floors": [25, 75], "built_10": [20, 40], "built_20": [45, 95],
}
OLD_HYPOTHESIS = {   # Step 13's guesses (before any measurement), kept for the comparison
    "first_auto_cooker": [6, 8], "first_flavor_line": [12, 18], "built_10": [10, 30], "built_20": [30, 60], "built_40": [30, 60],
}


def main():
    d = sys.argv[1]
    rows = list(csv.DictReader(open(os.path.join(d, "career.csv"))))
    by = collections.defaultdict(list)
    for r in rows:
        by[r["run"]].append(r)
    buys = list(csv.DictReader(open(os.path.join(d, "purchases.csv"))))
    js = json.load(open(os.path.join(d, "career.json")))
    out = {"_doc": "AUTOMATIC SIMULATION. Each check: what it measures, the numbers, flagged or not."}
    F = lambda r, k: float(r[k])
    # T1 automation cannot pay its upkeep: minutes after the first machine where upkeep+inputs
    # exceed sales, and the kettles' unpaid time.
    t1 = {}
    for run, rs in by.items():
        first = next((int(r["min"]) for r in rs if int(r["machines"]) > 0), None)
        after = [r for r in rs if first is not None and int(r["min"]) > first + 1]
        neg = sum(1 for r in after if F(r, "net_pm") < 0)
        t1[run] = {"minutes_after_first_machine": len(after), "minutes_net_negative": neg, "unpaid_ms": int(rs[-1]["unpaid_ms"]),
                   "upkeep_share_30_60": round(sum(F(r, "upkeep_pm") + F(r, "inputs_pm") for r in rs if 30 < int(r["min"]) <= 60) / max(1, sum(F(r, "revenue_pm") for r in rs if 30 < int(r["min"]) <= 60)), 3)}
    out["T1_automation_cannot_pay"] = {"what": "minutes with net < 0 after the first machine; kettles' unpaid ms; upkeep+inputs as a share of sales in 30-60",
                                      "runs": t1, "flagged": any(v["minutes_net_negative"] > 3 or v["upkeep_share_30_60"] > 0.5 for v in t1.values())}
    # T2 the shop draws too few customers for what the factory makes: in 30-60, the share of
    # minutes the chip says demand, and machines built that did not work.
    t2 = {}
    for run, rs in by.items():
        s = [r for r in rs if 30 < int(r["min"]) <= 60]
        if not s:
            continue
        dem = sum(1 for r in s if r["bottleneck"] == "demand") / len(s)
        idle = 1 - sum(F(r, "running") for r in s) / max(1, sum(F(r, "machines") for r in s))
        t2[run] = {"demand_share_30_60": round(dem, 2), "idle_machine_share_30_60": round(idle, 2), "sign_at_60": s[-1]["sign"]}
    out["T2_too_few_customers"] = {"what": "share of minutes 30-60 whose bottleneck is demand; share of built machines not working",
                                  "runs": t2, "flagged": any(v["demand_share_30_60"] > 0.5 and v["idle_machine_share_30_60"] > 0.3 for v in t2.values())}
    # T3 a recipe strictly superior: per flavor, coins a coater-minute could earn (price -
    # ingredients for its batch, over its coating time) x the share who ask -- and what sold.
    eco = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "data", "economy.json")))["factory"]["flavors"]["recipes"]
    t3 = {}
    for fl, r in eco.items():
        if not r.get("machine"):
            continue
        batch_ms = r["coat_ms_per_portion"] * r["in"]
        margin = r["price"] * r["in"] / 2 - r["ingredient_coins"]   # a batch = in portions = in/2 small bags
        t3[fl] = {"margin_per_batch": margin, "coins_per_coater_min": round(margin * 60000 / batch_ms, 1), "order_share": r["order_share"], "loss": r.get("loss", 0),
                  "demand_weighted": round(margin * r["order_share"], 2)}
    sold = collections.Counter()
    for run, v in js["runs"].items():
        for fl, n in v.get("flavor_sold", {}).items():
            sold[fl] += n
    best = sorted(t3.items(), key=lambda kv: -kv[1]["demand_weighted"])
    out["T3_recipe_superior"] = {"what": "per flavor: margin a batch, coins a coater-minute, order share, margin x share; bags sold over all runs",
                                 "flavors": t3, "sold_all_runs": dict(sold),
                                 "flagged": len(best) > 1 and best[0][1]["demand_weighted"] > 1.5 * best[1][1]["demand_weighted"] and best[0][1]["coins_per_coater_min"] >= max(v["coins_per_coater_min"] for v in t3.values())}
    # T4 the expensive sign beats every other upgrade: measured payback by kind (net a minute in
    # the 4 minutes after against the 3 before), and the share of money that went to the sign.
    pay = collections.defaultdict(list)
    spent = collections.Counter()
    for b in buys:
        rs = by.get(b["run"], [])
        m = int(b["t_s"]) // 60
        pre = [F(r, "net_pm") for r in rs if m - 3 <= int(r["min"]) <= m]
        post = [F(r, "net_pm") for r in rs if m + 1 < int(r["min"]) <= m + 5]
        k = FLOOR(b["what"])
        spent[k] += int(b["cost"])
        if pre and post:
            gain = statistics.mean(post) - statistics.mean(pre)
            pay[k].append(int(b["cost"]) / gain if gain > 0 else 999.0)
    med = {k: round(statistics.median(v), 1) for k, v in pay.items()}
    tot = max(1, sum(spent.values()))
    out["T4_sign_beats_all"] = {"what": "median measured payback (minutes; 999 = no gain seen) by kind; share of all money spent",
                                "payback_median_min": med, "spent_share": {k: round(v / tot, 3) for k, v in spent.items()},
                                "flagged": "sign" in med and all(med["sign"] < v for k, v in med.items() if k != "sign") and spent["sign"] / tot > 0.35}
    # T5 overflow locks the factory: minutes after 5 where the factory made portions but sold
    # nothing, or the kettles were blocked a whole minute.
    t5 = {}
    for run, rs in by.items():
        locked = 0
        prev_b = 0
        for r in rs:
            blk = int(r["blocked_ms"]) - prev_b
            prev_b = int(r["blocked_ms"])
            if int(r["min"]) > 5 and ((F(r, "made_pm") > 0 and F(r, "sold_pm") == 0) or blk >= 60000 * max(1, int(r["machines"]) // 2)):
                locked += 1
        t5[run] = locked
    # ... and the slow lock the career sim found (Step 39): after minute 10, a stretch of five or
    # more minutes where under a quarter of the machines work and the shop nets under 40% of its
    # best ten minutes so far (stock or orders the line cannot serve hold everything).
    stall = {}
    for run, rs in by.items():
        roll = [statistics.mean(F(x, "net_pm") for x in rs[max(0, k - 9):k + 1]) for k in range(len(rs))]
        best = 0.0
        streak = longest = 0
        for k, r in enumerate(rs):
            bad = int(r["min"]) > 15 and roll[k] < 0.5 * best
            streak = streak + 1 if bad else 0
            longest = max(longest, streak)
            best = max(best, roll[k])
        stall[run] = longest
    out["T5_overflow_lock"] = {"what": "minutes after minute 5 with portions made and no sale (or the kettles blocked all minute); longest stall: minutes after 15 whose ten-minute net is under half the run's best ten minutes so far",
                               "runs": t5, "stall_longest_min": stall, "flagged": any(v > 2 for v in t5.values()) or any(v >= 5 for v in stall.values())}
    # T6 a single optimal build: the policies' book at the end, and whether one policy leads
    # every segment by more than 20%.
    books = {k: v["book"] + v.get("prizes", 0) - v.get("fees", 0) for k, v in js["runs"].items()}
    avg = {k: v for k, v in books.items() if k.startswith("average/")}
    ranked = sorted(avg.items(), key=lambda kv: -kv[1])
    seg_lead = collections.Counter()
    for a, b in [(0, 10), (10, 20), (20, 30), (30, 60), (60, 90)]:
        sums = {run: sum(F(r, "net_pm") for r in rs if a < int(r["min"]) <= b) for run, rs in by.items() if run.startswith("average/")}
        if sums:
            top = sorted(sums.items(), key=lambda kv: -kv[1])
            if len(top) > 1 and top[0][1] > 1.2 * max(1, top[1][1]):
                seg_lead[top[0][0]] += 1
    out["T6_single_optimal_build"] = {"what": "the average hand's policies: book + prizes - fees at the end (ranked); segments one policy led by > 20%",
                                      "ranked": ranked, "spread_best_to_median": round(ranked[0][1] / max(1, statistics.median(v for _, v in ranked)), 2) if ranked else None,
                                      "segment_leads": dict(seg_lead), "flagged": bool(ranked) and (ranked[0][1] > 1.3 * statistics.median(v for _, v in ranked) or max(seg_lead.values() or [0]) >= 4)}
    # T7 numbers explode: the largest wallet, minute's revenue and price on screen.
    mx = max(int(r["money"]) for r in rows)
    mr = max(int(r["revenue_pm"]) for r in rows)
    out["T7_numbers"] = {"what": "largest wallet and minute's sales in any run (the counter groups thousands: 1,234,567)", "max_money": mx, "max_revenue_pm": mr,
                         "flagged": mx > 9_999_999 or mr > 99_999}
    # Milestones against the targets (average hand) and the dead zones.
    ms = {}
    for k, v in js["runs"].items():
        ms[k] = v["milestones"]
    tgt = {}
    for key, (lo, hi) in MILESTONE_TARGETS.items():
        got = [v.get(key) for k, v in ms.items() if k.startswith("average/balanced")]
        tgt[key] = {"target": [lo, hi], "step13_guess": OLD_HYPOTHESIS.get(key), "average_balanced": got, "ok": all(g is not None and lo <= g <= hi for g in got)}
    out["milestones_vs_target"] = tgt
    out["dead_zone"] = {k: {"dead_min": v["dead_min"], "dead_longest_min": v["dead_longest_min"], "no_buy_longest_min": v["no_buy_longest_min"]} for k, v in js["runs"].items()}
    out["presses_per_min_idle"] = {k: round(v["presses"] / max(1, js["minutes"]), 1) for k, v in js["runs"].items() if k.startswith("idle/")}
    json.dump(out, open(os.path.join(d, "traps.json"), "w"), indent=1)
    print(json.dumps({k: (v.get("flagged") if isinstance(v, dict) else v) for k, v in out.items() if k.startswith("T")}, indent=0))


if __name__ == "__main__":
    main()
