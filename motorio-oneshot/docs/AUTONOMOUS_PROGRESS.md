# Autonomous progress log

Newest last. Every entry records what was run, not only what was written.

## 1 — Audit and baseline
Read the existing `motorio` project (3,439 lines, 18 scenes, 17 tests) and ran it
headless: exit 0, no errors. Recorded its core loop, its strengths (warmth-as-progression,
cold/warm colour story, fixed-world resources) and its failures (no terminal goal, factory
never visibly grows, one-step production chain, per-item rigid bodies, 1,670-line
orchestrator). Written up in `GAME_AUDIT.md`.

## 2 — Design decision
Chose a five-minute scored run rather than an open-ended base ladder. This converts the
audit's central failure ("nothing is worth optimising") into the shape of the game itself,
and makes the compelling-first-five-minutes requirement identical to the whole product.
Recorded in `GAME_DESIGN.md` and `ART_DIRECTION.md`.

## 3 — First playable
Built `Defs`, `Sim`, layers, player, HUD and audio. First import produced a parser error
(`draw_colored_polygon` given a `PackedColorArray`); fixed. Headless launch: exit 0.
Web export ran in Chromium with 0 console errors. **Checkpoint committed.**

## 4 — Core loop proven, not assumed
Wrote `tests/test_sim.gd` driving the simulation directly. Caught that one assertion could
never fail and rewrote it as a real warm-vs-frozen belt comparison. All cases pass.

## 5 — First real playthrough exposed a design bug
Automated play placed belts but delivered nothing (`누적 0`). Cause: the guaranteed
starter ore was a 2×2 block, so the miner's output tile was itself ore and could never
take a belt. Changed to a single row with a clear lane home, and added tests that pin the
deterministic opening across seeds.

## 6 — Dropped input found by playing
Heat showed one belt paid for when two were attempted. `Input.is_action_just_pressed` is
frame-scoped and drops presses inside an event handler. Switched to
`event.is_action_pressed`. This would have read to a player as a dead key.

## 7 — Independent visual critique, cycle 1
An independent critic scored the build 3–4 across most categories with measured evidence:
the warm pool desaturated to **(166,166,169), saturation 0.01** — the game's entire premise
contradicted by its own terrain; belts at **1.13:1** against cold ground; ember ore at
**1.66:1**; the HUD hint running through the hotbar; the control legend clipped by the
viewport edge; and centred text that was not centred.

## 8 — Cycle 1 fixes
Re-keyed the terrain to an amber ramp (verified independently: saturation now 0.21–0.46
across the radius), gave machines self-lit bodies and warm rim light, recoloured ember ore
to copper with outlines on both ore types, doubled the core, cooled and shrank the clock,
fixed the missing `draw_string` width that broke every centred string, rebuilt the bottom
HUD, docked the temperature bar permanently, made pause dim only the world, split the build
preview into three states, and moved rejection text onto the target tile. Fixed Korean
popups rendering as boxes. **Checkpoint committed.**

## 9 — Performance measured, then optimised
Sampled frame deltas during active gameplay: **86.1 ms, 11.6 FPS**. Throttling the HUD and
machine layers to 30 Hz changed nothing (68.6 ms), which proved the cost was fill rate, not
script time. The warm pool was forty concentric filled circles — roughly 2.9M pixels of
fill per frame, re-rasterised every frame because Godot rebuilds draw commands regardless
of `queue_redraw()`. Baked the scale-invariant ramp into a 192×192 texture drawn as one
quad: **39.1 ms, 25.6 FPS**, no visual regression. **Checkpoint committed.**

## 10 — Flow and onboarding
Added `tests/test_flow.gd` covering title → play → pause → end of run → restart on the real
scene, including that a worse run cannot overwrite the session best. Added a single
always-on objective line derived from world state, so onboarding needs no modal tutorial
and stays correct whatever order the player plays in. Removed a startup notification that
announced a radius which had not changed. **Checkpoint committed.**
