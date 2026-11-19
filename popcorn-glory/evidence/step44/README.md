# Step 44 evidence — usability without words, readable management, accessibility

Everything here was measured on the real game: the exported web build in Chromium (Playwright), the
headless suite, and the canonical rules model (`variants/factory/factory_rules.gd`). The decisions
are D-64 (the hand is not starved by its own machines), D-65 (usability without words) and D-66 (a
coater starved for over a minute goes first).

**The blind players are fresh-context AI agents, not people.** What they report is an observation of
an AI reading screenshots. It is not a fun rating and not a human test.

| file | what |
|---|---|
| `blind/before_A/` | The blind AI player on the **public 0.43.0** `#factory` (400×860 touch, 3 minutes). Its first action came at 23.6 s. Outcomes: early 8, near 1, perfect 5. It bought 2 upgrades. Its confusions became this step's list: a tap works too, so it found the hold late; it found the bottleneck only by opening panels; it never understood the gold dots. `controller/player_report.md` is its report. The controller logs and `player/shots/` are kept here; the browser profile and the 24 MB session video stay out of git. |
| `blind/after_*/` | Blind AI players on the public 0.44.0 (added after the deploy; see the issue report). |
| `sizes/` | **Target sizes**, measured in `ui44.spec`. There are six scenes per screen: fresh, 12 machines, the overview, the picker opened from a rate, 44 machines, and the 44-machine overview. They run on seven screens (360×640, 390×844, 720×1280, 768×1024, 844×390, 1280×800, 1920×1080). `targets_<screen>.json` gives the short side of every target in css px. The frame's buttons are ≥ 40 css px and everything else ≥ 24 (WCAG 2.5.8). The two exceptions are the landscape phone (frame buttons ≥ 24, a compromise) and the dense 44-machine packing/shop places on the 360 phone (14.8–21 css px, a known limit). The screenshots are `fresh_0s_*`, `twelve_*`, `overview_*`, `picker_from_rate_*`, `forty_*`, `forty_overview_*`, the hint after a tap (`coach_after_tap_*`), the refused press's bin cue (`full_bin_cue_*`) and calm motion (`motion_calm_*`). |
| `headless/full_try1.log` · `full_try2.log` · `full_try3_coater.log` | The full headless suite. **Try 1: 323/1.** The shop's 2×2 places pushed the queue into overlapping places at sign tier 6 (`test_factory` 391); the queue was refitted. **Try 2: 324/0.** **Try 3, after the coater rule (D-66): 325/0** (load 2.9). |
| `economy/m90` · `m90_oldrule` · `m90_try1_trap` | The 90-minute career, seeds 3901 and 3902, with the hand reserve (D-64). New rule: books 24,637 and 26,444, with 0 zero-sale minutes. Old rule (`hand_first = false`): 22,472 and 25,313. `m90_try1_trap` is the first version of the reserve, which kept room even when nothing was packing: seed 3901 had zero-sale minutes, with the bin at 20 and 7 waiting. It is kept as it failed. `career.csv` at the top is the 20-minute run, identical to Step 42. |
| `economy/m90_coater` · `m20_coater` | The same careers after the coater rule. **The 90-minute careers are byte-identical** (`cmp`). The 20-minute seed-3901 rows are identical too. No coater in these careers ever waits 60 s. |
| `economy/flavor35_old` · `flavor35_fair` | The canonical flavor hour (Step 35's sim, 17 policies and demands). `COATER_FAIR=0` is the old build order; the default is the rescue rule. **14 of 17 runs are identical.** The other three: auto_mode_hand 593.7 → 582.9 net a minute (−1.8%), craze_machines 417.0 → 419.6 (+0.6%), craze_tier2 572.6 → 582.4 (+1.7%). |
| `economy/cocoa_sweep/` | **The starving coater**, headless. The script is `cocoa44.gd.txt`. It builds the `flavors34` factory (two kettles, a hopper, the base mixer; sprayer cheese, coater caramel, sprayer spicy, coater cocoa) over 40 seeds × 4 hand habits (early releases, just after the window, random, every 10 s), 10 minutes each. The results are in the table below. `trace_seed22.log` follows seed 22 every 30 s: the bin's plain never reaches four for the coater built last, and the coaters ahead of it take every batch. |
| `browser/e2e44_regression.log` · `load_regression.txt` | **The full browser suite, first run**, under `timeout 9000`. The machine was crowded: load 11.05 at 14:06, swap 8 GB of 8 GB. 240 of 353 tests ran before the timeout: 201 passed, 6 failed, 33 skipped. The failures were factory26 (p720, phone) and factory31 (phone), plus sessions22 on p720 ×3. factory26/31 failed because the picker's icons grew to 84 px and now cover the shop places under the card. sessions22 is a harness failure: the spec needs `OUT=`, and `undefined/sessions22.json` was missing. |
| `browser/e2e44_factory26_31_before_fix.log` · `after_fix.log` · `load_factory26_31.txt` | factory26/31 before and after the specs close the card first, as a player would (`closeCardOver`: the floor's badge): 3 failed → 4/4. The after-fix log also contains the sessions22 harness failure above. |
| `browser/e2e44_tail_desktop.log` · `e2e44_tail_matrix.log` · `e2e44_sessions_p720.log` · `load_tail.txt` | **The 113 tests the timeout left out**, run separately (load 5.1 → 12.8). Desktop: 56 passed, 9 skipped, **1 failed (flavors34: cocoa sold 0)**. Matrix (responsive07 + ui44 on five screens): 34 passed, 16 skipped. sessions22 on p720 with `OUT`: 3/3. |
| `browser/e2e44_flavors_rerun.log` · `flavors_shots/` | flavors34 on desktop again: passed in 1.1 min, with cocoa coated 4 and sold 1. **We did not file the failure as load.** In the failed run, 12.5 game minutes passed with no cocoa coated while caramel coated 67. The game time came from `dev_advance`; load changes only when the hand lets go. The headless sweep then found the same starvation. |
| `browser/e2e44_focused_final.log` · `load_focused_final.txt` | **The local 0.44.0 build after the coater rule**: flavors34, craft35, customers36, news37, contests38, ui44, factory26 and factory31 on p720, phone and desktop: **40 passed, 0 failed, 2 skipped** (43 min, load 2.0 → 8.2). |

## The coater sweep (40 seeds each; seconds until the first cocoa batch)

| rule | early releases | just after the window | random, every 10 s | random, every 5 s |
|---|---|---|---|---|
| build order (0.43.0 and 0.44.0 before D-66) | **2/40 never** (seeds 22, 39), median 175, max 550 | 0/40, median 60, max 155 | 0/40, median 210, max 460 | 0/40, median 135, max 365 |
| full fairness (longest wait always first) — rejected | 0/40, median 60, max 130 | 0/40, 45 / 80 | 0/40, 70 / 170 | 0/40, 55 / 80 |
| **rescue: starved over 60 s goes first (shipped)** | **0/40**, median 80, max 175 | 0/40, 55 / 130 | 0/40, 80 / 170 | 0/40, 65 / 95 |

Full fairness fixed the starvation but changed the economy. On seed 22 of the unit test's factory,
sales were 258 in build order, 150 with full fairness and 227 with the rescue (cocoa 0 → 8 coated).
The rescue cost that plain-poor factory 12% of its sales, because cocoa now gets the plain that used
to sell as plain. Full fairness also moved the flavor hour by several percent on most runs, while
the rescue leaves 14 of 17 runs identical. `unit/test_usability44.gd` replays seed 22. The old order
must coat no cocoa there, and the new one must coat at least 4 of every flavor.

## Honest limits

- No human tested this step. The blind players are AI.
- In the 44-machine layout, the packing and shop places on a 360 css px phone are 14.8–21 css px,
  under 24. They are kept from getting worse but not fixed. The landscape phone's frame buttons
  are ≥ 24 css px, not ≥ 40.
- A tap on an empty part of an open machine card still reaches the slot or badge beneath it.
  This is old behavior and Step 44 did not change it. The specs close the card first, as a player
  would.
- The screen-reader channel is a canvas label plus a polite live region. It was checked in the
  DOM. No real screen reader was used.
