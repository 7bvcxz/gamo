# Audit — the existing Motorio, and what One Shot inherits

Date: 2026-07-28. Audited build: `motorio` v0.4.19 (3,439 lines of GDScript, 18 scenes,
17 automated tests). Baseline run: `godot --headless --path motorio --quit-after 240`
exits 0 with no `SCRIPT ERROR` and no leak warnings, so the original is technically sound.

## Existing core loop

Gather ore → carry or belt it to the central base → craft machines → upgrade the base →
the warm radius grows → previously unreachable ore rings become safe → repeat.

## Player fantasy

A lone engineer keeping a warm outpost alive on a frozen plateau, aided by cat workers.
The strongest emotional beat is the moment warmth expands and the white-out pulls back.

## Strongest existing elements

1. **The warmth-as-progression idea.** Tying the reachable world to a single growing radius
   is genuinely distinctive and gives spatial meaning to an economy number. This is the
   idea worth keeping and is the seed of One Shot.
2. **Visual identity.** Snow, teal-and-brass machinery, warm amber core, cat workers. The
   colour story (cold world / warm factory) is coherent and unusual.
3. **Fixed-world resource layout.** Resources exist from world generation and the base level
   only extends reach. Exploration means travel, not waiting for a spawn.
4. **Readable machine vocabulary.** Four block traits (Solid / Machine / TransportFloor /
   Fixed) is a small, teachable rule set.

## Weakest existing elements

1. **No terminal goal.** Base level 7 is the end of the ladder and nothing follows. There is
   no reason to optimise, no score, no failure state. Sessions end from boredom.
2. **The factory never visibly grows.** Six minutes of play leaves the screen looking exactly
   like minute zero. Cat miners tick at a fixed 3s regardless of layout, so more workers add
   output linearly and no arrangement is smarter than another.
3. **Production chain is one step deep.** Ore → box, plus a single smelter tier added late.
   There is no ratio, no bottleneck, nothing to solve.
4. **Session length fights the platform.** A 12-minute day with a forced sleep interrupts
   building, and the target platform is mobile web where sessions are short.
5. **Monolithic orchestration.** `Main.gd` is 1,670 lines with 128 functions owning world
   generation, inventory, menus, research, survival, quests and save/load. Adding one block
   type requires touching eleven separate places.

## Bugs and technical debt

- Every carried item is a `RigidBody2D`. A few hundred items would put the physics server on
  the critical path; this is the hard ceiling on factory size.
- Machines rebuilt their draw commands every frame regardless of camera position until the
  `WorldView` culling added on 2026-07-27.
- Save schema is a single version integer; a bump silently discards the player's run.
- Autosave only runs in web/release builds, so editor sessions never exercise persistence.

## Missing feedback

- Delivering a resource increments a corner number with no sound, no pop, no particle.
- Nothing marks the warm frontier except a colour change, so crossing it is discovered by
  taking damage rather than by seeing a line.
- Machines give no indication of being blocked, starved or slowed.

## Visual inconsistencies

- Snow is near-white while the UI is dark teal; the two never meet, so the HUD floats.
- The cold overlay used to reach 95% white, erasing the frame; softened on 2026-07-26 but the
  outer world is still an undifferentiated void.

## Usability problems

- Eleven of the fourteen recipes are locked behind base levels the player cannot see the
  requirements for until they open a paged menu.
- Rotation is a 0.7s hold on the same key as placement, which is guessable only from the
  tutorial text.

## Progression problems

- Four of six base upgrades ask for more of the same resource, so the mid-game is a grind
  rather than a sequence of new problems.

## Performance risks

- Per-item rigid bodies, per-frame `queue_redraw` on every machine, and a group scan in each
  cat's `_physics_process` are the three measured cost centres.

## Highest player-value-to-effort opportunities

| Opportunity | Value | Effort |
|---|---|---|
| Give the run a terminal goal and a score | Very high | Low |
| Make layout matter (a real two-input recipe) | High | Medium |
| Feedback on every delivery (sound, pop, shake) | High | Low |
| Replace physics items with data items | High | Medium |
| Compress the session to about five minutes | High | Low |

## Decision for One Shot

Keep the warmth-as-progression idea, the cold-world/warm-factory colour story and the cat
workers. Discard the open-ended base ladder, the 12-minute day, the physics-driven item
transport and the monolithic orchestrator. Rebuild as a five-minute scored run so that every
one of the five opportunities above is addressed by the shape of the game itself rather than
bolted on. Rationale and mechanics live in `GAME_DESIGN.md`.
