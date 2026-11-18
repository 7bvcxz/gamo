# Step 41 evidence — customers, flavored goods, icons

Everything here was drawn by the game's own code (no image tool, no outside art) and measured
by the tools named. No human or AI fun ratings are in this folder.

| file | what |
|---|---|
| `audit/audit.json` | `tools/sprite_audit.gd` (Xvfb, real renderer): five cast members × two looks × six motions, 36 frames each — foot slide (max 0.34 px), centre jump between frames (max 3.48 px, head 21.8), height range (0.91–1.17); atlas edge halo (none: edges at most 0.005 lighter than inside); the 44-machine sign-8 factory 25 s on three screens — atlas sprites' largest on-screen scale (max 1.21× their texels, at 720×1280: the coin), most people at once (7), closest standing people (1.1 heads); the icon set's silhouette overlap (worst IoU 0.74, stock~news) and mean colours. `load.txt` the machine's load around the run |
| `audit/motion_<who>.png` | each cast member's motion strips: rows idle, walk, queue (impatient), receive, delight, leave; every 4th frame |
| `audit/icons.png` | the eleven icons rendered alone |
| `audit/rush_<screen>.png` | the last frame of each audit run (44 machines, sign 8) |
| `xvfb/before_*` · `xvfb/after_*` | the factory at 20 s with 100 coins and at 44 machines / sign 8 after 90 s, 0.40.0 (`before`, captured from a detached worktree of the 0.40.0 source) and 0.41.0 (`after`) |
| `xvfb/sheet_cast_*` · `xvfb/sheet_flavors_*` | the `#cast` sheet (cast, faces, motion strip, icons, goods at runtime size) and the `#flavors` sheet |
| `before_after_F44_phone.png` · `before_after_F44_desktop.png` · `before_after_flavors_desktop.png` | side by side. In 0.40.0 a leaving customer walked over the glass tube and off the floor (top right); in 0.41.0 people fade at a door inside the shop |
| `browser/e2e41*.json` | Playwright JSON (annotations: icon IoU, feet drift, the shop's people at 0/3/30 min, looks, reactions, render). `a` the first run, `b` the focused regression (art40/41, customers36, factory17/18/21/22/23/30/31, news37, flavors34; 51 passed, 6 skipped, 3 failed — customers36: the student's headphones were missing, put back, see `c`), `c` customers36 + art41 9/9, `d` art41 with screenshots |
| `browser/rush_probe_*.json` · `rush_probe.spec.mjs.txt` | the same 30-minute rush (p720, sign 8, 11–14 people) on public 0.40.0, on 0.41.0 with people drawn as shapes, and on 0.41.0 with people baked: draw calls 739 / 961 / 687, objects 1,212 / 1,497 / 1,157 (medians of 12) |
| `browser/*.png` | screenshots of the art41 spec on three screens (0 m, 3 m, 30 m rush, the card over the crowd, the cast sheet) |
| `browser/video/*.webm` | Playwright video of the art41 runs (360×640): `cast_p720` the cast sheet (walkers, hops, delight); the shop run re-encoded to excerpts (ffmpeg VP9) — `shop_p720_first30s` (0 m to the 3-minute milestone) and `shop_p720_rush_last45s` · `shop_desktop_rush_last45s` (the 30-minute rush at sign 8, the badge card and the news paper opened over the crowd). The full recordings (11–17 MB each) and the other screens' cast videos were not kept |
| `economy/` | `tools/sim/career39.gd` 20 min, average/balanced, seeds 3901 and 3902: all 40 rows identical to Step 39's `career_after.csv` (36 columns) and to Step 40's run — the art changes no rule |
