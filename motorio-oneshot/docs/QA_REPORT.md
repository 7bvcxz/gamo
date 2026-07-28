# QA report

Every result below was produced by running the game, not by reading the code.
Godot 4.7.stable. Web build served over local HTTP and driven by headless Chromium
(SwiftShader software WebGL) via Playwright.

## Automated simulation tests

`godot --headless --path . --script res://tests/test_sim.gd` — **PASS** (exit 0).

| Case | What it proves |
|---|---|
| generation | Both ore types generate; frost is reachable at the opening radius; ember is not; no ore under the core |
| deterministic opening | The guaranteed ore row and the clear belt lane exist for any run seed |
| build rules | Miners only on ore, belts only off ore, nothing over the core, cost is charged, reclaim refunds, unaffordable builds rejected |
| miner → core | A miner facing the core earns heat and increments the delivery counter |
| belt transport | Miner → 2 belts → core delivers, and items are visibly on the belt in transit |
| furnace | One ore type alone produces nothing; frost + ember yields alloy; alloy is worth more than its inputs |
| economy and warmth | Delivery credits both spendable and lifetime heat; lifetime heat grows the radius; the radius is capped; **spending heat never shrinks the map**; blackout costs a share of banked heat |
| frost throttle | An identical belt outside the radius moves items measurably slower (<80% of the warm one) but does not stop |
| blocked output | A miner with nowhere to send its ore holds the finished item instead of discarding it |

## Executed smoke paths (browser)

| Path | Result |
|---|---|
| Project startup | Canvas initialises, 0 console errors |
| Title screen → gameplay | Any key enters the run |
| Core player action (build) | Miner placed on the starter ore, cost deducted |
| Belt placement and rotation | R cycles direction; belts placed along the lane |
| Machine interaction | Miner → belt → core delivers; heat and lifetime heat both rise |
| Progression | Warm radius observed growing from 7.0 to 8.1 tiles during play |
| Cold excursion | Walking out drains the temperature bar; the bar is docked and always visible |
| Blackout and recovery | Temperature reaching zero locks input, costs heat, and returns the player to the core |
| Pause and resume | Esc pauses with the world dimmed and the HUD readable; Esc resumes |
| Restart flow | Enter from the result screen starts a fresh run with new ore |
| Scene transition | Single-scene game; state transitions verified instead |
| Save/load | Not present by design — see UPGRADE_PLAN.md |
| Settings persistence | Not present by design |

## Defects found by running the game, and their fixes

1. **Nothing was ever delivered in the first automated playthrough.** Screenshot showed
   `누적 0` with belts placed. Cause: the starter ore patch was a 2×2 block, so the
   miner's output tile was itself ore and could never accept a belt. Fixed by making
   the guaranteed patch a single row with a clear lane home.
2. **A build press was silently dropped.** Heat showed one belt paid for when two were
   attempted. Cause: `Input.is_action_just_pressed` inside an event handler is
   frame-scoped. Fixed by testing `event.is_action_pressed`.
3. **Korean popups rendered as boxes.** `FxLayer` used `ThemeDB.fallback_font`, which
   has no CJK glyphs. Fixed by using the bundled Noto Sans CJK.
4. **`draw_colored_polygon` parser error** on first import (passed a `PackedColorArray`
   where Godot 4 wants a single `Color`). Fixed before the first successful run.
5. **Centred text was not centred.** `draw_string` ignores alignment unless a width is
   supplied, so every "centred" string was left-aligned at the screen midpoint. Fixed by
   drawing text inside explicit boxes.

## Performance

Sampled `requestAnimationFrame` deltas during active gameplay (factory built, player
moving, camera following) at 960×540.

| Build | Mean | FPS | p50 | p95 | p99 | Worst |
|---|---|---|---|---|---|---|
| Before optimisation | 86.1 ms | 11.6 | 83.3 | 116.6 | 133.3 | 166.6 |
| Layer repaint throttled to 30 Hz | 68.6 ms | 14.6 | 66.7 | 83.4 | 100.0 | 116.7 |
| Warm pool baked to a texture | **39.1 ms** | **25.6** | 33.4 | 50.1 | 66.6 | 83.3 |

JS heap stayed at 31–48 MB with no upward drift across runs.

**Caveat, stated plainly:** these numbers come from SwiftShader, a CPU software
rasteriser, which is a worst case and is not representative of ordinary desktop
hardware with a GPU. The comparison between builds is meaningful because the method was
identical; the absolute FPS is not a desktop figure. No GPU was available in this
environment, so a hardware-accelerated measurement remains outstanding.

The middle row is the useful diagnostic: throttling repaints changed almost nothing,
which is what proved the cost was fill rate rather than script time and pointed at the
gradient.

## Known remaining limitations

- No hardware-GPU performance measurement (see caveat above).
- No save system, no settings screen, no audio volume control.
- The result screen reports totals but no rate, so comparing runs takes mental effort.
- Automated play drives fixed key timings; it cannot detect subtle feel problems.
