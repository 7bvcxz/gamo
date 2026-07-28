# Motorio: One Shot — game design

## Pitch

One night. One plateau. Build a cat-powered factory around a dying heat core and hoard as
much heat as you can before the dark takes the map. Five minutes, one score, one more try.

## Why a scored run

The audit's finding was that the original had no terminal goal, so nothing was worth
optimising. A fixed 300-second run converts every design question into a legible one:
"does this earn more heat per second than the alternative?" It also matches the platform —
a mobile web session — and makes the whole game a compelling first five minutes, because the
first five minutes *are* the game.

## Core loop

```
walk out  →  place a Miner on ore  →  belt the ore home  →  core converts it to Heat
   ↑                                                              │
   │                                    heat buys more machines   │
   └──────────  warm radius grows, richer ore becomes safe  ←─────┘
```

## The one interesting decision

Heat is simultaneously the **currency**, the **score**, and the **map key**. Spending it on
machines lowers your bankable score right now but raises your rate. Every purchase is a bet
on how much time is left. Late in a run, buying a furnace is usually wrong; early, refusing
to is fatal.

## Systems

**Warm radius.** `7 + 0.022 × total heat ever earned`, capped at 22 tiles. It grows from
lifetime earnings, not from your current balance, so investing is what opens the map.

**Cold.** Outside the radius the player loses 13 warmth/second and regains 26/second inside.
At zero the player blacks out, loses 25% of banked heat and wakes at the core after 1.6s.
It is a tax on carelessness, never a run-ending failure.

**Frost throttle.** Machines outside the warm radius run at 45% speed. This is the mechanic
that makes the radius matter to the *factory* and not only to the player's body; it is the
reason to keep feeding the core rather than hoarding.

**Ore.** Two types in concentric bands. Frost ore (blue, value 3) sits at radius 4–9.5, inside
the opening radius. Ember ore (orange, value 6) sits at radius 11–17 and is unreachable at
first. Patches, not single tiles, so a miner placement is a commitment.

**Machines.**

| Machine | Cost | Behaviour |
|---|---|---|
| Miner cat | 12 | On an ore tile; emits one ore every 1.15s in its facing direction |
| Belt | 2 | Carries up to 3 items at 2.6 tiles/s toward its facing |
| Furnace | 30 | 1 frost + 1 ember → 1 Alloy (value 22) every 2.2s |

**The alloy is the design's payoff.** It requires physically routing two different ore bands
into one building, which is the first moment the player must think spatially rather than
just build a straight line. Its value (22) is more than three times the sum of its inputs (9),
so the layout puzzle pays for itself.

## Five-minute arc

- 0:00–0:45 — one miner, one short belt, first deliveries. Heat ticks up. Radius creeps.
- 0:45–2:00 — a second and third miner; the player notices belts are cheap and miners are not.
- 2:00–3:30 — radius reaches ember ore. The furnace becomes affordable and the routing
  problem appears.
- 3:30–4:30 — alloy chain running; the score curve bends upward sharply.
- 4:30–5:00 — no time to recoup an investment; the player spends nothing and banks.

## Failure and restart

There is no lose state, only a lower number. The result screen shows total heat, a breakdown
by item, and the session best. Enter restarts instantly with a fresh ore layout.

## Controls

WASD/arrows move, Shift sprints, 1/2/3 pick a machine, R rotates, Z builds at the facing
tile, X reclaims it for 75% of cost, Esc pauses, Enter restarts from the result screen.

Building targets the tile the player faces, shown by a pip on the character and a preview
rectangle, so there is no cursor and no mouse dependency — this keeps a touch port viable.

## Balance levers

All in `scripts/Defs.gd`: `DAY_SECONDS`, `START_HEAT`, `MINER_PERIOD`, `BELT_SPEED`,
`ITEM_VALUES`, `MACHINE_COSTS`, `WARM_PER_HEAT`, `COLD_DRAIN`. No balance number lives in
logic files.
