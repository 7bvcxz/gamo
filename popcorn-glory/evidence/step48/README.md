# Step 48 evidence — the release candidate (0.48.1): art/UX pass, fixes, economy, release matrix, real device

Measured on the real game:

- the exported web build in Playwright's Chromium on K12 (software WebGL, a machine shared with
  other sessions);
- the headless suite and the canonical rules model;
- a real Samsung S23, in Chrome and as the Android debug APK.

No person has tested this release candidate, and the owner's go/no-go is pending.

## The art/UX pass at the exported size — `views/`

`tools/views48.mjs` opens each view in a fresh browser on the **published** build at three sizes:
phone 390×844 @2 (touch), 720×1280 portrait (touch) and desktop 1280×800 (mouse). For each it
takes a still after the view settles and a still 0.45 s after a real hold released in the gold.

The views:

| view | how it was set up |
|---|---|
| 0 m | a new factory |
| 3 m, 10 m, 30 m | the career simulation's own saves at those minutes (average hand, balanced policy). `tools/sim/career39.gd` now writes the game's save document at chosen minutes (`views/save_average_balanced_3901_*.json`). A simulation, not a player |
| 44 machines | the prepared save of Step 47 (sign 8) |

| folder | build | stills |
|---|---|---|
| `views/shots_0470/` | 0.47.0 (before) | 30 stills, 0 page errors |
| `views/shots_0480/` | 0.48.0 (factory screens as 0.48.1) | 30 stills, 0 page errors |

**What the pass found** (by eye, on the stills):

- No placeholder art, broken shadows, clipped text or mixed fonts in the 15 views.
- The dimmed ring (D-70) reads as "not now" in the 10- and 30-minute views, where the shelf and bin are full.
- The popped kernels of a burst fly outside the kitchen's frame, over the upgrade card and the page.
  This is noise at worst. It was kept, because it is the burst's celebration, and it is noted.
- On the desktop, a picked machine's card is mostly empty white space (three rows at the top).
  It was noted, not changed.
- The real defects came from the players (Step 47) and from the device (below), not from the stills.

## Fixes (0.48.0 → 0.48.1; D-71)

| what | found by | fix | held by |
|---|---|---|---|
| **The factory could not be reached without `#factory`** | the debug APK on the S23 opened the chooser with the stand and A/B/C only (`android/apk_launch.png`, 0.48.0). Step 16 left the factory off "until its flow is real"; it never went on | the factory is the chooser's first tile (three floors); five tiles fit 1280×800 (`android/apk481_chooser.png`, `../../tests/results/step48/chooser_0481/chooser04_*.png`) | `test_app`, `experiments04` |
| The contests list moved under the finger (a blind player paid for the wrong contest) | Step 47 r3 | the running contest's place is always kept (a dashed slot); the type is fitted to the board's capacity (3), not the current count; for 0.6 s after the list changes, a tap is held back only if another card was under the finger a moment ago | `test_rc48` (fails without the hold) |
| A refused press with the paper open hid the reason | Step 47 r2, r5 | the refused press folds the paper, so the full floors show | `test_rc48` (fails without the fold) |

The first version of the hold broke contests38 and journey46 (`../../tests/results/step48/only_0480/`,
64/3/25). It held taps on the first sight of the page, and taps on a card that had appeared where
there was none. Narrowed, it passed: contests38, journey46 and news37 on three screens, 12/12
(`only_0480/rerun2/`).

## Economy and pacing re-check — `economy/` (`tools/sim/career39.gd`, 60 minutes, eleven hands × policies, seed 3901)

A simulation of the game's own rules, not players.

- **Pacing (average hand, balanced):** first sale 0.19 min, first contest win 5.8, first auto
  cooker 20.0, 10 machines built 32.8, 20 built 57.9. Step 39's table had 10 machines at 30–45
  minutes and 19–20 at 60, so this is unchanged within noise.
- **The B hold's first three minutes are kept:** every hand sells within 0.2–0.7 minutes, and the
  first crowd comes at 3.6.
- **44 machines, maintenance (the forty runs):**

| sign | machines working on average | sold a minute | net a minute | upkeep a minute |
|---|---|---|---|---|
| 6 | 19.3 | 52 | 514 | 32 (6%) |
| 8 | 26.1 | 94 | 894 | 45 (5%) |

- **Upkeep is a small share** of a big factory's income, and demand (the shop) limits how many
  machines work.
- **Contest prizes** (a whole career: 640–1,540) are small beside it. A blind player said the same.
  The economy was not changed in a release candidate; this goes to the owner as an option.

## The real phone: Samsung S23 — `android/`

The phone was borrowed through `tools/coordination/resources/s23.md` and released at its baseline.

**Chrome, the published 0.48.0** (`s23_public_0480.json`, `android48.mjs`). The factory's code is
the same in 0.48.1. The phone was cool (thermal status 0, AP 34.1 °C).

- Load to ready 3.7 s. A new factory runs at **60.1 fps**.
- **Three real touch holds gave three Perfects.** After a reload the factory is the same ($20,
  2 sold).
- **Offline after loading:** a hold still pops and the shop sells (sold 2 → 3).
- **44 machines: 13.2 fps median** (p10 12.3), with 964 draw calls.

**The Android debug APK** (`popcorn-0.48.1-debug.apk`):

- `com.heydive.popcornglory`, versionName 0.48.1, versionCode 49, minSdk 24, targetSdk 36,
  29,310,396 bytes, sha256 `d8c7e656c27458e4361bdd8dce16eae6e5301290ab94da8735845789978dd19d`.
- Signed with Godot's debug key: not for distribution, and not kept in the repository.
- Installed, then:
  - the chooser with the factory first (`apk481_chooser.png`);
  - the factory opened by a tap (`apk481_factory.png`);
  - two real holds (adb swipes of 1.55 s) gave 4 gold dots and 30 coins (`apk481_after_sale.png`);
  - **force-stopped and reopened: the factory came back** with 40 coins, the 30 plus a sale that was
    on its way (`apk481_relaunch.png`);
  - logcat: no game errors (`apk481_logcat_errors.txt` holds only Samsung system lines).
- Then **uninstalled**.
- The 0.48.0 APK opened the chooser without the factory (`apk_launch.png`), which is how D-71 was found.

## Store, credits, teaser

- `store/`: five true screenshots of the published build (`STORE.md` says how each was set up).
- `teaser/teaser_phone_0480.webm`: 25 s, three cuts of genuine footage joined end to end, no effects.
- `../../CREDITS.md`: the rights inventory. Everything shipped is code, hand-written SVG or
  synthesized sound from this repository, plus Godot (MIT) and Open Sans (OFL). The pack contains no
  design, test, tool, evidence or art-source path.

## The release matrix (the published 0.48.1) — `../../tests/results/step48/public_0481/`

`tools/test_all.sh --public` ran on the published 0.48.1 from 05:22 to 08:15 UTC on 2026-11-22. It tested
the pack at the public address (`version_tested.json`: `game-a0c5dc788068.pck`, source `ab57311ac800`).

| stage | result |
|---|---|
| headless | 354 passed, 0 failed (24,130 checks, 31 files, 698 s) |
| browser | **314 passed, 0 failed, 57 skipped**, 0 passed on retry; 45 specs |
| not run | 5 specs of the `--perf` and `--slow` sets (the Step 46 bench table, the render probe, three real-time sessions) |
| load | 2.20 at the start, 10.85 at the end (1-minute average); 33.6 GB memory free; swap nearly full (8.0 of 8.2 GB) |

- **Every skip is one the spec chose.** A check measures on one screen only, for example "desktop
  measures the sound", "mouse paths on the desktop project" or "one browser kill is enough". Each
  reason is on its line in `report.md`. No check was skipped because it failed.
- **The screens:** 720×1280 and 390×844 with touch; 1280×800 with mouse and keyboard. `responsive07`
  and `ui44` add five more sizes: 720×1280, 1920×1080, 360×640, 768×1024 and 844×390.
- **The areas:** load, first play, input, the full line, high load, news, contests, settings,
  save and migration, offline and hidden tab, recovery. `../../RELEASE_CHECKLIST.md` section 4 has
  the table by area and screen.
- **Rollback is not in the browser matrix.**
  - Step 45 checked that old builds read new saves, with the old builds' own code.
  - This run checked that 0.48.1 still writes schema 1 (`save45`).
  - No deploy was actually reverted.
- **The chooser (D-71):** `experiments04` checked, on all three screens, that the list is the five
  tiles with the factory first. It opens only A, B and C by tap. The factory tile was opened by a real
  tap in the debug APK on the S23.

## Not tested (explicitly)

- **PC desktop exports (Windows, Linux, macOS):** this machine's Godot export templates are Web and
  Android only. So these are untested, not passed.
- **iOS:** no macOS or Xcode.
- **An Android release build:** the release signing key and the store accounts are the owner's.
- **A person:** no human has played this release candidate. The fun dimensions are AI proxy
  judgements (Step 47).
- An earlier full public run on 0.48.0 was stopped by me after 15 minutes. The chooser fix made
  0.48.1 the release candidate, so the matrix ran on that build instead
  (`../../tests/results/step48/public_0480/` holds what had run).
