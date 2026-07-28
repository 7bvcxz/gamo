# Upgrade plan

Ordered by player-visible value. Items are struck through as they land.

## Done

- ~~Project launches, no parser errors, headless exit code 0~~
- ~~Core loop proven end-to-end by headless simulation tests~~
- ~~Deterministic opening: guaranteed ore row and a clear belt lane home~~
- ~~Warm pool re-keyed to amber so the premise reads on frame one~~
- ~~Self-lit machines and copper ore so nothing depends on the ground for contrast~~
- ~~HUD layout: no collisions, nothing clipped, temperature docked and permanent~~
- ~~Three-state build preview and rejection text anchored to the target tile~~
- ~~Dropped-input bug in the event handler~~
- ~~Pause dims the world only~~
- ~~Performance: baked gradient texture, 86ms → 39ms per frame~~
- ~~Procedural royalty-free sound for every meaningful action~~

## Next

1. **Second critic pass fixes.** Whatever the independent review ranks highest.
2. **Onboarding beat.** The first 20 seconds should teach miner → belt → core without
   text. A ghost arrow from the starter ore to the core is likely enough.
3. **Furnace discoverability.** The alloy chain is the design's payoff but nothing tells
   the player that two ore types must meet. The furnace card should show its recipe.
4. **Result screen depth.** Show heat per minute and the best run's breakdown so a
   repeat attempt has a target.

## Deliberately not doing

- Save/load. A five-minute run does not need persistence, and a partial save system is
  worse than none.
- More machine types. The audit's finding was that the original was broad and shallow;
  three machines that interact are worth more than six that do not.
- Mobile touch controls. The control scheme was kept cursor-free so a port stays
  possible, but shipping one is out of scope for this slice.
