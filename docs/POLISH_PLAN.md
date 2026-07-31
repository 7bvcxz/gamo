# Polish Plan

Ranked by player impact, from the baseline audit. Items are closed only when a
runtime check confirms them.

| # | Weakness | Fix | Status |
|---|---|---|---|
| 1 | Progression has no decisions; heat is both build currency and progress meter | Split them: materials build, energy crystals become heat | **done** (0.6.0) |
| 2 | No player agency in the first two minutes | Hand mining from the first frame, output as a real object cats haul | **done** (0.6.0) |
| 3 | Desktop HUD body text near 7 device px | Base 0.5 -> 0.9, slider floor 0.6 -> 0.45 | **done** |
| 4 | No music or ambience | Two procedurally generated beds: wind, and cold that tracks exposure | **done** |
| 5 | Feedback has no hierarchy | One scale in Defs, ordered by event frequency | **done** |
| 6 | The doc site described an economy the game no longer has | Level Design, diagram and Releases rewritten | **done** |

## Deliberately not done

- **Multi-floor and splitters.** Out of scope for one pass and blocked on the
  tile coordinate decision already recorded in the Todo page.
- **A data-driven recipe layer.** Still the right next structural job, but the
  economy had to settle first; doing both at once would have made the numbers
  unverifiable.
