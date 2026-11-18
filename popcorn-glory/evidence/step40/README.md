# Step 40 evidence — final environment art (0.40.0)

All art is original and procedural (`art/env_art.gd`, `art/factory_art.gd`): no generated, stock or
reference images. The local image tools were inventoried: `~/Workspace/tools/imagegen` (OpenAI
`gpt-image-2`, billed per image -- a dry run was made, no image generated) and
`~/Workspace/tools/topview` (TopView credits) are paid services, which this issue queue does not
authorize; so no raster source exists to keep in `art_src/` (DECISIONS D-57).

| file | what |
|---|---|
| `final_phone_before_after_0_and_44.png` | 720×1280 Xvfb: 0.39.0 at 0 machines · 0.40.0 at 0 (money 100: the upgrade card in colour) · 0.39.0 at 44 · 0.40.0 at 44 with sign 8 |
| `final_desktop_before_after_44.png` | 1280×800: the 44-machine factory, 0.39.0 and 0.40.0 |
| `levels_phone_L111_L222_L332.png` | the rooms at lines 1/1/1, 2/2/2, 3/3/2 (kitchen: steel wainscot, second pipe, then a checkered floor and a gauge; packing: a mint band and a second window, then a clock and a plant; shop: a second row of lights and an entrance mat) |
| `before_after_phone_0_3_10_40.png`, `before_after_desktop_0_40.png` | the first pass (b2abc825): 0.39.0 against the rooms at 0/3/10/40 machines |
| `xvfb/before_*` | 0.39.0 (before) at 0/3/10/40 machines, phone and desktop |
| `xvfb/after_*` | the first pass (b2abc825), same scenes (and four kettles: three lamps lit) |
| `xvfb/levels_*`, `xvfb/final_*` | the final build: the floor levels; money 100 (card in colour); lines 3/3/2 with sign 6; 44 machines with sign 8 |
| `xvfb/final_*_360x640.png` | the review procedure's small screen (ART_DIRECTION 6): money 100, and 44 machines with sign 8 |
| `browser/art40_*.png` | `art40.spec.mjs` screenshots on three screens (the rooms at 0 minutes; the card in colour) |
| `browser/e2e40pre.json` | `art40` (rooms) run against the **public 0.39.0** -- it fails (no rooms there), recorded for the "before" render cost |
| `browser/e2e40b_unbaked.json` | `art40` + `factory33` on the first full 0.40.0 build, walls drawn as rects (objects +50% at 44 machines) |
| `browser/e2e40c.json`, `e2e40d.json`, `e2e40e.json` | after baking the kitchen and packing walls (c), and the shop windows too (d: desktop art40 + factory33, e: art40 on three screens) |
| `browser/load40*.txt` | `uptime` before and after each of those runs |
| `economy/` | `tools/sim/career39.gd` average/balanced, seeds 3901·3902, 20 min, on this build: the 40 rows are identical to `evidence/step39/economy/career_after.csv` (art does not touch the rules) |

## Render cost (browser, `dev_render_info`)

| scene | build | draw calls | objects | fps | load |
|---|---|---|---|---|---|
| 0 min, p720 | 0.39.0 public | 289 | 554 | 37 | 8.7 |
| 0 min, p720 | 0.40.0 walls as rects | 360 | 838 | 32 | 3–9 |
| 0 min, p720 | 0.40.0 final (baked) | 361 | 644 | 33 | 9.3 |
| 44 machines, desktop (median of 6) | 0.39.0 public (step39 suite) | ~950 | ~1,100 | 16.4 | 7.8 → 5.3 |
| 44 machines, desktop | 0.40.0 walls as rects | ~1,115 | ~1,650 | 14.6 | 7.5 → 9.3 |
| 44 machines, desktop | 0.40.0 final (baked) | ~1,120 | ~1,300 | 14.9 | 6.3 → 6.3 |

Heap kept over the 44-machine minute: 8.29 MB (0.39.0) and 8.27 MB (final). Pack: 679,536 → 693,220 bytes
(+13.7 KB, +2.0 %). The baked textures are made at the screen's scale, once per size and level
(at most nine kept): about 1.2 MB of texture for the kitchen at 720×1280.
