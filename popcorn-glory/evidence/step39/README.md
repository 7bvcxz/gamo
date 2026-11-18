# Step 39 evidence — 30–60 minute progression

**AUTOMATIC SIMULATION.** Everything under `economy/` was produced by `tools/sim/career39.gd`
on the game's own rules (`variants/factory/factory_rules.gd`) with simulated hands and purchase
policies. These are not players and not fun ratings (the blind playtests are Step 47).

| file | what |
|---|---|
| `economy/career_before.csv` · `career_after.csv` | one row a minute for every run (22 runs: 4 hands × policies × seeds 3901/3902, 90 min). Before = the 0.38.1 rules, after = 0.39.0, the same bot |
| `economy/purchases_*.csv` | every purchase (minute, what, cost, the bottleneck chip at that moment) |
| `economy/career_*.json` | per run: milestones (minutes), book, machines, contests, dead-zone minutes; `forty`: the 44-machine factory for an hour at sign 6 and 8 |
| `economy/traps_*.json` | the issue's seven traps measured (`tools/sim/career39_traps.py`) |
| `economy/SEGMENTS.md` | per run and segment (0–3, 3–10, 10–20, 20–30, 30–60, 60–90): before → after (`career39_table.py`) |
| `economy/charts/index.html` | SVG charts from the CSV (`career39_charts.py`): production, packaging, service, lost, net, upkeep, money, machines, working machines, stock; one floors chart per run |
| `economy/long150/` | the balanced policy for 150 minutes (the 40-machine milestone) |
| `economy/first_bot/` | the first bot run (0.38.1, before the bot skipped duplicates): it bought three to five menu boards — the one-is-enough trap |
| `economy/dump_*.txt` | the factory's state at minute 65 of the two locks the sim found (coaters starving on a filler-less line; the ticket printer behind a full shelf) |
| `economy/forty_gap1000/` | the 44-machine hour with the old 1000 ms arrival gap (sign 8 served 59.9 a minute: the cap) |
| `economy/data_md5_after.txt` | the data files the after run read |
| `xvfb_*.png` | Xvfb captures: the sign at tiers 6/7/8 (zoomed), the 44-machine factory at sign 8 (phone and desktop) |
| `charts_page.png` | the charts page as rendered |
| `browser/` | real-browser runs of `career39.spec.mjs` (local, three screens: the real-clock three minutes, the sign tiers, the money counter -- JSON with annotations, the load before and after), their screenshots, the focused local regression log (40 passed / 3 failed / 11 skipped: two were the new spec's measurements, fixed; factory33 p720 37 of 38 machines at load 9.4 passed alone) |

Reproduce: `godot --headless --path popcorn-glory --script res://tools/sim/career39.gd -- <out> 90 "" 3901,3902`
then `python3 popcorn-glory/tools/sim/career39_traps.py <out>`.
