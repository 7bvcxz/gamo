# Architecture

## Shape

```
Main (Node2D)            orchestrator: state machine, input routing, camera, run timer
├── Sim (Node)           pure simulation: grid, machines, items, economy
├── Ground (Node2D)      night fill + baked warm-pool texture          z -20
├── World (Node2D)       frontier ring, tile grid, ore                 z -10
├── Machines (Node2D)    machines, items in transit, build preview     z  0
├── Player (Node2D)      the engineer, owns the Camera2D               z  5
├── Fx (Node2D)          pooled popups, rings and sparks               z  20
├── Audio (Node)         eight-voice sound pool
└── UI/HUD (Control)     every screen-space element
```

## Rules this structure enforces

**Simulation never draws; drawing never simulates.** `Sim` has no reference to any
visual node and emits signals instead (`heat_gained`, `build_rejected`,
`warmth_changed`). That is what makes `tests/test_sim.gd` able to prove the whole core
loop headlessly, with no rendering and no scene.

**Main stays thin.** It owns the state enum, routes input, and translates simulation
signals into feedback. It contains no balance numbers and no drawing.

**All tuning lives in `Defs.gd`.** Costs, values, periods, radii, the palette and the
warm ramp are constants in one file. Rebalancing never touches logic.

**No per-item nodes.** Items on belts are dictionaries (`{type, t}`) inside the belt's
own array. The original Motorio used a `RigidBody2D` per item, which put the physics
server on the critical path and capped factory size. Here a few hundred items cost
nothing measurable.

## Data model

`Sim.machines: Dictionary[Vector2i, Machine]` is the single source of truth for what
exists where. `Sim.ore: Dictionary[Vector2i, int]` is the terrain. Both are keyed by
tile, so lookups are O(1) and there is never a scene search.

`Machine` is a `RefCounted` inner class with `type`, `cell`, `dir`, `progress`,
`flash`, `items` and `buffer`. One class covers every machine because the behaviour
differences are three small functions (`_tick_miner`, `_tick_belt`, `_tick_furnace`)
rather than a class hierarchy. Adding a machine means adding one tick function, one
draw function, one entry in three `Defs` arrays — not eleven scattered edits.

`_push_into(cell, item_type)` is the only transfer path between machines and returns
whether the destination accepted the item. Every "output blocked" behaviour in the
game falls out of that one boolean.

## Rendering

Everything is immediate-mode `_draw()`; there are no sprite assets, so there is no
import configuration to drift and no sprite-sheet slicing to get wrong.

Godot re-rasterises every draw command each frame regardless of `queue_redraw()`, so
the optimisation that mattered was not redrawing less often but **emitting less fill**.
The warm pool is baked once into a 192×192 texture and drawn as one quad; that single
change took the software-WebGL build from 11.6 to 25.6 FPS. `queue_redraw()` throttling
on the HUD and machine layers was measured and made no difference, which is what
identified fill rate as the real cost.

World layers cull against `view_rect`, which `Main` publishes once per frame.

## Input

One handler in `Main._unhandled_input`. It tests `event.is_action_pressed(...)` rather
than the `Input` singleton: `Input.is_action_just_pressed` is frame-scoped and silently
drops a press when two arrive in the same frame, which the player experiences as a dead
key. This was observed in automated play before it was fixed.

## Known limitations

- There is no save system; a run is a session and the best score lives in memory only.
- The `Machine` class carries fields only some types use (`buffer` is furnace-only).
  A three-machine game does not justify the indirection of separate classes yet.
- `Sim` is a `Node` purely so it can sit in the scene tree; it uses none of `Node`'s
  lifecycle beyond that.
