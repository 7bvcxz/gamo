# Polish QA Report

## Automated

| Suite | Result |
|---|---|
| `test_sim` | PASS |
| `test_flow` | PASS |
| `test_animation` | PASS |
| `test_facing` | PASS |
| `test_cold` | PASS |
| `test_workers` | PASS |
| `test_save` | PASS |
| `test_tiles` | PASS |
| `test_settings` | PASS |
| `test_build` | PASS |
| `test_fog` | PASS |
| `test_progression` (new) | PASS — `copper at 3.0 days with two miners (73 crystal)` |

`godot --headless --editor --quit`: **0** parse or script errors.

## Runtime, real browser (Playwright + Chromium, SwiftShader)

| Viewport | FPS | Console errors |
|---|---|---|
| desktop 1100x760 | 15.3 | 0 |
| iPhone 13, real touch | 6.7 | 0 |

FPS is from a software rasteriser and is only meaningful as a ratio. Numbers
across builds are only compared at identical viewport sizes, after the lesson
recorded in AGENTS.md about single-sample FPS readings.

## Paths exercised

Title -> start -> walk -> hand-mine a full ten-second swing -> shard drops and
is collected -> unlock fires -> hotbar slots 1-4 selected -> rotate -> pause ->
resume -> settings panel. Phone: title tap, play, touch pad visible and laid
out.

## Defects found and fixed during the pass

1. `MINER_PERIOD` left at the old value, breaking the exchanger ratio (caught by test).
2. Power capacity lagged one tick behind fuel (caught by test).
3. `test_build` inherited another test's save file and picked an occupied seam.
4. A runtime type error in a test aborted `_run` before `quit()`, hanging the
   SceneTree forever instead of failing.
5. Locked hotbar cards hid the machine name.
6. The mining arc was invisible against the warm floor.
7. Korean particle error in the unlock hint.

## Known limitations

- No hardware GPU is reachable in this environment; all rendering measurements
  are software.
- Deep-game states (a full copper economy, power brown-out in motion) are
  asserted in simulation but were not driven through the browser, because
  steering the game that far with synthetic input proved unreliable earlier in
  the project.
