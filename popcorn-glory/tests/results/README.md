# tests/results — AUTOMATED results (not human play)

Everything here is made by scripts on the game's own rules. It says what the numbers do; it does **not**
say whether anyone enjoyed it.

| folder | made by | what |
|---|---|---|
| `step06/` | `godot --headless --path popcorn-glory --script res://tools/sim/runner.gd -- --out res://tests/results/step06` | 21 scripted behaviours x 180 s (seed 7): `sim.md` (table), `sim.json` (every run, every upgrade time), `chart.svg`/`chart.png` (upgrades over time), sensitivity of each experiment's steady player to cost x0.8/x1.25 and growth +-0.1 |

The chart PNG is drawn by Chromium (`NODE_PATH=popcorn-glory/tests/e2e/node_modules node popcorn-glory/tools/svg_png.cjs …`):
Godot's SVG rasteriser draws no text.

**What a simulation cannot establish**: whether a newcomer finds the first action (the scripts already know
where to press), whether a press feels tactile, whether the art and sound delight, whether anyone wants to go
on after three minutes. Those are Step 08 (blind AI, labelled as AI) and the owner's own scores.
