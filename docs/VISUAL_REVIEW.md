# Visual Review

Screens compared before and after at 1100x760, same scene, same seed family.

| Aspect | Baseline | After |
|---|---|---|
| HUD body text | ~7 device px, unreadable | ~12 device px |
| Hotbar | 3 slots, cost in heat | 4 slots, material costs, locked slots name what opens them |
| Materials | two lifetime totals | three live stock counters with names |
| Core action | nothing on screen | filling arc on the worked seam |
| Loose items | did not exist | lit, bobbing, shadowed |
| Cats | identical whatever they were doing | visibly carrying their load |

## Fixed during the pass

- The first locked-slot design covered the machine name with the word "잠김",
  which removed the only reason to work toward it.
- Long machine names ran through the hotbar colour swatch; the row now uses
  short names and keeps the full name in the hint line.
- The mining arc was amber on amber.

## Known remaining

- The status panel is dense; at very small UI scales the three counters crowd.
- Generators and exchangers share a rectangular silhouette and are told apart by
  colour and glow rather than shape.
