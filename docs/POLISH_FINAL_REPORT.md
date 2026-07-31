# Polish Final Report — Motorio: One Shot

Second autonomous pass. Baseline `24d99b6` (v0.5.5) -> **v0.6.0**.

## Baseline summary

The systems worked and the build was stable — 11/11 tests, 0 console errors,
0.5.5 had just tripled the frame rate by baking the fog. What was thin was the
game underneath: one currency did every job, the player could not produce
anything for the first two minutes, the desktop HUD rendered body text at about
seven device pixels, and the plateau was silent between nine one-shot effects.

## The five weaknesses, and what happened to them

**1. Progression had no decisions.** Heat bought machines *and* measured
progress, so spending was never a trade-off. Heat is now only the progress
meter; machines are bought with materials banked at the base, and heat comes
from exactly one converter. The player's question each minute is now "does this
crystal become distance or production?", which did not exist before.

**2. No agency in the opening.** The player can hand-mine from the first frame.
The shard lands on the floor as a real object, and an idle cat walks it to the
base — which is also the first thing that teaches what cats are for.

**3. Desktop HUD unreadable.** Measured ~7 device px at 1100x760. Base scale
0.5 -> 0.9, slider floor lowered so the previous look is still reachable.

**4. Nothing to hear.** Two procedurally generated loops: wind that swells into
the night, and a cold layer that tracks actual exposure, so the ear warns before
the vignette is unmistakable.

**5. No feedback hierarchy.** Placing a belt shook the screen almost as hard as
completing a tech. One scale now lives in `Defs`, ordered by how often the event
happens.

## Scores, baseline -> now

| Area | Before | After | Why |
|---|---|---|---|
| Core interaction | 4 | 8 | The player produces, by hand, in the first ten seconds |
| Progression | 3 | 8 | Two currencies with a real conversion between them |
| Pacing | 3 | 7 | Something to do immediately; copper is a 3-day goal, asserted |
| UI/UX | 3 | 7 | Legible HUD; the hotbar is a visible tech tree |
| Game feel | 4 | 7 | Progress arc, declared intensity scale |
| Sound | 3 | 6 | Two reactive ambient beds |
| Atmosphere | 4 | 7 | The cold is now audible as well as visible |
| Content density | 3 | 6 | Five machines, three materials, power as a second axis |
| Onboarding | 5 | 7 | Objective tracks all three levels; locked cards state their condition |
| Stability | 9 | 9 | 12/12 tests, 0 console errors |
| **Overall** | **4.5** | **7.3** | |

Scores are my own judgement against the runtime evidence in the other documents,
not a measurement.

## Systems changed

`Defs.gd` (items, machines, costs, unlocks, power, feedback scale),
`Sim.gd` (stock, ground items, hand mining, cat hauling, exchanger, generator,
power accounting, save schema 2), `Main.gd` (mine input, pickup, unlock
announcements, ambience, objective), `HUD.gd` (stock row, hotbar tech tree,
scale), `MachineLayer.gd` (ground items, generator, progress arc, cat loads),
`Audio.gd` (ambient beds), `PlayerActor.gd`, `project.godot` (mine action),
plus `assets/sfx/wind.wav` and `cold.wav`, the `/doc` pages, and the tests.

## Verification

12/12 headless suites including the new `test_progression`, 0 editor errors,
and a real-browser run on desktop and an iPhone 13 viewport with synthetic
input: 15.5 and 7.1 FPS under a software rasteriser, 0 console errors. Full
detail in `POLISH_QA_REPORT.md`.

## Remaining limitations

- **Mobile cannot hand-mine.** The new core verb is bound to C with no pad
  button. This is the single biggest gap left and is recorded in the Todo page.
- Deep states (a running copper economy, a power brown-out) are asserted in
  simulation but were not driven through a browser.
- No hardware GPU here; all performance figures are software-rendered ratios.
- The cat economy may be tight: four staffed miners plus haulers wants roughly
  eight cats. Suspected, not demonstrated.

## Deferred on purpose

Splitters, multi-floor, and the data-driven recipe layer. The recipe layer is
the right next structural job, but the economy had to settle first or its
numbers could not have been verified.

## Running it

```
godot --headless --path motorio-oneshot --editor --quit          # parse check
godot --headless --path motorio-oneshot --script res://tests/test_progression.gd
./deploy-web.sh motorio-oneshot                                  # web build
```
Play: **C** mines the seam you face, **Z** builds or picks up a cat, **X**
reclaims, **R** rotates, **1-4** select, **Esc** pauses. Live at
`https://7bvcxz.github.io/gamo/motorio-oneshot/`.
