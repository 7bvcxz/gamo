# Step 45 evidence — saves that come back, and never silently go

Measured on the real game: the exported web build in Chromium (Playwright, real localStorage),
the headless suite, and the old builds' own source in detached worktrees. The decision is D-67
and the design is `design/SAVES.md`. No person tested this step, and no real phone was used.

| file | what |
|---|---|
| `fixtures/old_builds_read_045.log` · `write45.gd.txt` · `read_old.gd.txt` | **Reversibility.** A 0.45 save was written by the current code (`write45`): the 44-machine factory and a stand. The **old builds' own load path** then read it (`read_old`: parse, schema 1, game, exp, rules dict, `from_save`). Each ran in a detached worktree of that version: 0.43.0 (`6cd69a6c`) and 0.12.2 (`f2941053`). 0.43.0 accepted the factory (44 machines, money kept, conserved, still conserved after 60 s more) and the stand. 0.12.2 accepted the stand. The schema stays 1 for exactly this. |
| `../../tests/fixtures/saves/` | **The migration fixtures**, written by the old builds themselves (`fixture_gen.gd.txt` in worktrees of 0.12.2, 0.22.0 and 0.43.0) and pinned by `SHA256SUMS`: `stand_0.12.2.json` (level 9, 6 min, 123 pops), `stand_0.43.0.json`, `factory_0.22.0.json` (the first factory save), `factory_0.43.0_forty.json` (44 machines, 10 min, 65 KB). The folder has a `.gdignore`, and the pack holds none of it (`strings` on the pack: 0). |
| `headless/full_try1.log` · `full_try2.log` · `full_try3.log` | The full headless suite. **Try 1: 335/1.** `test_app`'s broken-stand-save case now restores the backup (the stand before the restart) instead of starting fresh, so the test now checks both paths. **Try 2: 336/0.** **Try 3, on the final source (the icon's new place): 336/0** (load 6.5 → 1.4). |
| `browser/e2e45_save.log` · `.json` | `save45` first run, three screens: **15 passed, 3 failed.** The three failures were the process-termination test: CDP `Page.crash` closed the whole Playwright context ("Target page, context or browser has been closed"), so no page could reopen. That measured the harness. Tries 2 and 3 (`e2e45_crash_try2/3_desktop.log`) opened a second tab first, and that tab died too. |
| `browser/e2e45_kill_desktop.log` | **Process termination, the real one.** A throwaway Chromium with its own profile on disk; every process of it killed with SIGKILL (no unload, no last save); a new Chromium on the same profile. The surviving save was at clock 31,574 against 38,778 at the kill: **7.2 s lost** while the game saves every 5 s, because Chromium commits localStorage to disk a little late. Sold 14 at the kill, 12 in the save and in the restored game: nothing sold twice. Every machine was back. |
| `browser/e2e45_focused.log` · `.json` · `load_focused.txt` | **The focused regression on 0.45.0**: save45, factory22, release12, progression07, news37, contests38, craft35, motion42, ui44, experiments04, stub03 on p720, phone and desktop: **106 passed, 0 failed, 11 skipped** (37.7 min, load 1.6 → 10.1). |
| `browser/e2e45_save_final.*` · `load_save45_final.txt` | `save45` after the set-aside icon moved: **16 passed, 0 failed, 2 skipped** (the kill runs on desktop only). The kill again lost 7.2 s (38,664 → 31,510), and sold was 14 → 12 → 12. |
| `browser/shots/` | `save45_old_forty_*`: the 0.43.0 factory opened. `save45_recover_icon_*`: the set-aside icon after a refused save. Its first place covered the shop floor's badge on the phone; the final shots show it left of the upgrade, and the spec now checks it covers nothing else. `save45_saves_page_*`: the recovery page with a broken save, an intact backup (0.43.0, 44 machines) and the set-aside copy. `save45_restart_armed_*`: the restart button armed after one tap. |

## What the tests guarantee

- **Old progress opens:**
  - a 0.12.2 stand at level 9;
  - a 0.43.0 stand;
  - a 0.22.0 factory;
  - a 0.43.0 factory with 44 machines.
  Each comes back headless and in the browser, keeps its numbers, and plays on with every
  portion conserved.
- **The factory's save is its own.** The factory never writes the stand's save, and restarting
  the factory leaves the stand alone. A, B and C store nothing.
- **A damaged save is refused with a reason, and changes nothing:** an edited number
  (checksum), a cut-short text, another experiment, another game, a newer schema. So are 8
  saves that add up but are not a factory play can make. With the limits switched off, 6 of
  those 8 were accepted.
- **A refused save is set aside, never written over.** The backup comes back. If both are
  broken, a fresh run starts, the set-aside save stays, and the frame shows the icon.
- **Restart takes two taps in the factory too.** Until 0.44, one tap erased a 44-machine
  factory: the arming followed the stand's auto offer. The old factory stays in the backup for
  ten minutes of new play.
- **Saves cut at the worst moment go on exactly the same.** A save taken with a pack, a serve
  and a lift in flight across 44 machines continues identically through the envelope. Earlier
  tests already cover news and contests (no prize twice).
- **Away is paused.** A reload continues the saved clock, and a hidden tab adds under 1.5 s
  (`factory33`).

## Honest limits

- No real phone storage, no person.
- "Old build reads new save" was checked headless with the old builds' own source. The previous
  public build (0.44.0) was not opened in a browser on a 0.45 save.
- A killed browser loses the last save that had not reached the disk (7.2 s measured), not
  just one 5 s interval.
- The saves page warns when the game is open in another tab only after the game writes (a
  `storage` event). Importing while the game is open can be overwritten by the game's next save.
