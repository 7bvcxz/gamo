# Step 42 evidence — the factory's motion (light, belts, steam, budgets)

Everything here is the real game: Playwright videos and screenshots of the exported web build,
Xvfb captures by the game's own renderer, and the headless test logs. No concept video, no human
or AI fun ratings. The design is `design/MOTION.md`; the decision D-62.

| file | what |
|---|---|
| `browser/e2e42_motion.json` · `load_motion.txt` | `motion42.spec.mjs` on p720, phone and desktop, 12/12 (local 0.42.0 build), with the machine's load before/after (6.4 → 10.8, other sessions busy). Annotations: the batch's light times (kitchen 3.0 s < packing 7.9 s < shop 10.3 s, p720), the sign's celebration climbing the tube (0.05 → 0.21 → 0.35 → 0.77 → 0.91 → 1) with the ring moved 0 px, the 44-machine crescendo (tier swarm, pieces ≤ 105 of 400, six belts running, draw calls / objects 1,156 / 1,375 p720 · 1,140 / 1,365 phone · 1,343 / 1,658 desktop, 123–124 journeys followed, none ending twice, ring 0 px after a rotation and a 3 s hidden tab), `?fx=low` (54–56 ambient pieces in ~13.5 s, belts moving) and `?motion=reduce` (0 ambient pieces, belts at phase 0) |
| `browser/e2e42_desktop_factory33_motion.json` · `load_desktop_factory33.txt` | the like-for-like render check: Step 33's own 44-machine spec on desktop, 0.42.0 vs the 0.41.0 public run (`tests/results/step41/public`) — FPS median 14.3 vs 14.5, draw calls ~1,167 vs ~1,160, objects ~1,375 vs ~1,360, kept memory 13.6 MB vs 13.6 MB |
| `browser/shots/` | screenshots on three screens: the sweep mid-climb, after the sign, the crescendo at 44 machines, rotated, low effects, reduced motion |
| `browser/video/` | VP9 re-encodes of the Playwright recordings: `chain_*` (one hand-popped batch from the kettle to the sale, then the sign bought and its celebration), `crescendo44_*` (44 machines at sign 8, the hand popping, a rotation and a hidden tab), `reduced_p720`, `low_phone` |
| `video_review/` | what was looked at and what it found. `chain_desktop_first_try_2fps_*`: the first build — at the sign's celebration the packing floor washes out white. `sweep_additive_vs_tint_p720.png`: the same moment, additive light over the goods (left) vs the final warm tint under the goods (right): the shelf and its bag read again. `sweep_frames_final_p720.jpg` and `tube_during_after_sweep_p720.png`: the final sweep — a soft gold glow climbing behind the glass tube, gone after. `crescendo44_p720_1fps.jpg`: 24 s of the 44-machine run: money rising every second, the shelf filling and emptying, customers coming and going, no piece or person vanishing between frames |
| `xvfb/` | `F44G8_step41_vs_step42_first.png` (44 machines, sign 8, 90 s: 0.41.0 left, the first 0.42 build right — the belts' chevrons), `kitchen_belts_steam_zoom.png` (chevrons on the kitchen belts, steam wisps over the working kettles) |
| `headless/` | `test_motion.log` (7/7) and the first full headless run (308/0) |
| `economy/` | `tools/sim/career39.gd` 20 min, average/balanced, seeds 3901 and 3902: all 41 rows identical to Step 41's run — the motion changes no rule |

Limits, said plainly: the browser here renders in software (headless Chromium, ~10–12 FPS with 44
machines), so the automatic low-effects budget switched itself on in every crowded browser run;
the full swarm budget was measured headless and in the Xvfb captures. The recordings are
800-pixel videos: they show the flow, the light and the crowd, not each steam wisp. No real phone
was used (Step 48).
