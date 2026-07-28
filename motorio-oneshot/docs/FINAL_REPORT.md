# Final report — Motorio: One Shot

A five-minute scored automation run built in `motorio-oneshot/`, taking only the *idea*
from the existing `motorio` project. Playable at
`https://7bvcxz.github.io/gamo/motorio-oneshot/`.

## What was built and why

The audit of the original found a technically sound game with no terminal goal: base
level 7 was the end of the ladder, nothing was worth optimising, and six minutes of play
left the screen looking like minute zero. Rather than bolt a score onto that structure,
the run itself became the structure. One night, 300 seconds, one number at the end.

That single decision resolves several audit findings at once. The compelling-first-five-
minutes requirement becomes identical to the whole product. Heat serves as currency,
score and map key simultaneously, so every purchase is a bet on remaining time. And the
warm radius — the original's best idea — becomes the pacing mechanism instead of a
side effect.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Move |
| Shift | Sprint |
| 1 / 2 / 3 | Select miner / belt / furnace |
| R | Rotate the machine's output direction |
| Z | Build on the tile you face |
| X | Reclaim it for 75% of its cost |
| Esc | Pause |
| Enter | Restart from the result screen |

Building targets the faced tile — there is no cursor and no mouse dependency, which keeps
a touch port viable.

## Architecture changes from the original

The original put a `RigidBody2D` on every carried item and a 1,670-line orchestrator in
charge of everything. Here the simulation is a single `Sim` node holding two dictionaries
keyed by tile; items are plain `{type, t}` dictionaries inside a belt's own array. `Sim`
never draws and never reads input, which is what lets `tests/test_sim.gd` prove the entire
core loop headlessly. All balance numbers live in `Defs.gd`. Full detail in
`ARCHITECTURE.md`.

## Generated assets

No third-party assets are used. Every visual is drawn procedurally in `_draw()` — there
are no sprite files, no import settings to drift, and no sprite-sheet slicing to get
wrong. The nine sound effects were synthesised with the Python standard library
(`wave` + `math`) and are committed as 100 KB of WAV; they are original and carry no
licence obligations. The one third-party file is Noto Sans CJK (SIL Open Font License),
required because Godot's built-in font has no Korean glyphs.

## Test results

`tests/test_sim.gd` — **PASS**. Nine cases covering generation, the deterministic opening,
build rules, miner→core delivery, belt transport, the furnace recipe, the economy and
warmth relationship, the frost throttle, and blocked-output preservation.

`tests/test_flow.gd` — **PASS**. Title → play → pause → end of run → restart on the real
scene, including that a worse run cannot overwrite the session best.

Browser smoke paths and the defects they exposed are itemised in `QA_REPORT.md`. Five real
bugs were found by running the game that reading the code would not have surfaced —
including a starter ore layout that made the guaranteed opening unwinnable, and an input
handler that silently dropped key presses.

## Review cycles

An independent visual critic reviewed representative screenshots across successive
revisions, with pixel measurements rather than impressions. Its findings drove the work
directly: the warm pool desaturating to **saturation 0.01** (the game's premise
contradicted by its own terrain), belts sitting at **hue 222°** — the same family as the
cold they are fighting — and reading **1.13:1** against the ground, ember ore at
**1.66:1**, a control legend clipped by the viewport edge, and centred text that was never
centred because `draw_string` ignores alignment without a width argument.

It also caught a regression I introduced: fixing the centring moved the warm-radius label
directly onto the Heat Core at **1.22:1**, defacing the hero object. That label is now gone
and a ring pulse marks expansion instead.

## Performance

Measured by sampling `requestAnimationFrame` deltas during active gameplay at 960×540.

| Stage | Mean frame | FPS |
|---|---|---|
| First playable | 86.1 ms | 11.6 |
| Repaint throttled to 30 Hz | 68.6 ms | 14.6 |
| Warm pool baked to a texture | 41.0 ms | 24.4 |
| Final build (machine outlines added) | 44.0 ms | 22.7 |

The middle row is the useful one: throttling repaints changed nothing, which proved the
cost was fill rate rather than script time. The warm pool had been forty concentric filled
circles — about 2.9M pixels of fill per frame, re-rasterised every frame because Godot
rebuilds draw commands regardless of `queue_redraw()`. Baking the scale-invariant ramp into
a 192×192 texture drawn as one quad halved the frame time.

The final row is a deliberate trade: outlining every machine cost about 3 ms per frame
and bought the readability fix that had the miner cat sitting at 1.19:1 against its own
ground. The cost scales with machine count, so a very large factory would pay more; that
has not been measured.

**These numbers come from SwiftShader, a CPU software rasteriser, and are a worst case.**
No GPU was available in this environment. The comparison between stages is valid because
the method was identical; the absolute figures are not a desktop result. A
hardware-accelerated measurement remains outstanding and is the largest gap in this report.

## Remaining limitations

- No hardware-GPU performance measurement (above).
- No save system, no settings screen, no volume control — deliberate for a five-minute run,
  but it does mean nothing persists between sessions, including the best score.
- The result screen reports totals but not a rate, so comparing two runs takes effort.
- Audio was verified to load and play without error, but its *mix* was never heard; balance
  between the nine effects is set by construction, not by listening.
- Automated play drives fixed key timings and cannot judge feel. Statements about game feel
  in this report rest on stills and code, not on a human playing.
- The critic's deferred item stands: the outer quarter of the warm pool still loses
  saturation as it meets the night. Fixing it properly needs perceptual-space interpolation
  rather than the current linear RGB ramp.
