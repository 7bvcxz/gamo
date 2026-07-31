# Balance Review

The redesign lives or dies on its numbers, so they are asserted in
`tests/test_progression.gd` rather than argued.

## The gate that matters

Reaching copper needs the warm radius to grow from 7 to 11 tiles, which is 182
heat.

| Draft | Energy value | Crystal per energy | Crystal needed | Days with 2 miners |
|---|---|---|---|---|
| First proposal | 1 | 5 | 910 | ~50 |
| After the 2:1 change | 1 | 2 | 364 | ~15 |
| **Shipped** | **5** | **2** | **73** | **3.0** |

`PROGRESSION: copper at 3.0 days with two miners (73 crystal)` is printed by the
test on every run.

## Ratios

- One exchanger consumes 0.4 crystal/s; one miner produces 0.1/s. **One
  exchanger absorbs exactly four miners**, so the bottleneck is miners -- which
  is to say cats -- and never the converter. Asserted.
- Hand mining and a staffed miner both produce 1 per 10 s. The first miner is
  therefore not a speed upgrade; it is parallelism. This was a deliberate choice
  over making machines faster, so automation reads as "I can only be in one
  place" rather than "numbers go up".
- Copper is half the crystal rate, so the later resource is scarcer per miner.

## Power

Capacity is a rate that never accumulates. One generator sustains 1.0 and burns
one energy crystal per 10 s; a belt draws 0.1. Under-supply slows every drawing
machine in proportion rather than switching some off, so a brown-out is
diagnosable.

## Open risk

With cats both hauling and staffing miners, four working miners want roughly
eight cats, which is 24 crates. Crate density may need raising once the mid-game
is played at length; it is not yet demonstrated either way.
