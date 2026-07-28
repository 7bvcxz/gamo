# Art direction

## One rule

**The world is cold and colourless. Every warm hue on screen belongs to the player.**

The environment is restricted to navy, slate and white. Amber, brass and orange are reserved
for the core, the warm pool, machine output and earned heat. A player scanning the frame can
therefore find their factory instantly, and an expanding warm pool reads as literal progress.

## Palette

| Role | Hex | Use |
|---|---|---|
| Void | `0e1320` | Beyond the lit world; clear colour |
| Cold snow | `222c44` | Ground outside the warm radius |
| Warm snow | `dfe7f2` | Ground at the heart of the warm pool |
| Grid | `38445f` | 20% alpha tile grid |
| Core | `ffb347` | Core, frontier ring, heat numbers |
| Core deep | `e0702a` | Core shell |
| Brass | `d8a34a` | Machine trim, panel edges |
| Machine | `2f6d72` | Machine bodies |
| Machine edge | `6fd2c8` | Belt chevrons, highlights |
| Cat fur | `e79a4f` | Miner cats |
| Danger | `e8574c` | Cold, invalid placement, scarf |
| Frost ore | `7fd4e8` | Item and crystal |
| Ember ore | `f0894a` | Item and crystal |
| Alloy | `ffd98a` | Item |

## Rendering approach

Everything is drawn procedurally in `_draw()` at a 32px tile scale. No bitmap sprites, so
there are no import settings to desynchronise, no filtering artefacts, no sprite-sheet frame
boundaries to get wrong, and the whole look can be retuned by editing constants. Texture
filtering is set to nearest in project settings so any future bitmap asset stays crisp.

## Silhouette rules

- Machines fill 20–24px of a 32px tile, leaving a visible gutter so a dense factory still
  reads as discrete objects.
- Every world object gets a soft dark ellipse beneath it. Anchoring objects to the ground is
  what stops a top-down scene looking like floating stickers.
- Cats are chunky: one body rectangle, one head circle, two ear triangles. At this size,
  detail below 2px is noise.

## Motion language

- Idle machines breathe slowly (about 2 Hz); working machines move visibly faster.
- Belt chevrons scroll at half the actual item speed. Matching them exactly reads as strobing.
- Every state change gets one ring expanding outward, never a particle cloud. Rings are
  cheap, readable, and stack legibly when several fire at once.

## Time of day

The ground lerps toward the void colour as the run's clock advances. By the final minute the
world outside the warm pool is nearly black. Time pressure is communicated by the art rather
than only by a number.

## What is deliberately not here

No outlines on world objects (they fight the soft snow), no screen-wide white-out (the
original's worst readability failure), no particle systems (rings and pooled sparks cover
every need at a fraction of the cost).
