# Motorio: One Shot — Polish Audit (baseline)

Captured at commit `24d99b6`, game version **0.5.5**, before the second polish pass.

## How this baseline was taken

| Check | Command | Result |
|---|---|---|
| Editor load | `godot --headless --path motorio-oneshot --editor --quit` | 0 parse/script errors |
| Test suite | `godot --headless --path motorio-oneshot --script res://tests/test_*.gd` | 11/11 PASS |
| Browser run | Playwright + Chromium (SwiftShader), 1100x760 | canvas ready 2.29 s, **0 console errors, 0 warnings** |
| Screens | `bl_1_title`, `bl_2_play`, `bl_3_belt_selected`, `bl_4_pause` | captured |

The repository working tree was clean; no uncommitted manual work needed preserving.

## Baseline scores (1-10) with evidence

| Area | Score | Evidence |
|---|---|---|
| First impression | 6 | Title is a clean hero shot, but nothing moves and no music plays. |
| Controls | 7 | 8-way movement is responsive; Z/X/R are consistent. Verified by driving all four directions in-browser. |
| Responsiveness | 7 | Input goes through `event.is_action_pressed`, so presses are not dropped. |
| Game feel | 4 | Building emits a ring + shake, but mining, delivery and pickup have almost no impact. No hit-stop, no scaling of feedback by importance. |
| Visual cohesion | 7 | One palette, consistent amber-on-navy language. Fog and pool now read as one system. |
| Core interaction | 4 | The player cannot produce anything by hand; every resource needs a cat first. |
| Obstacle readability | 6 | Ore is readable; the warm frontier is clear. Structures give no "you cannot pass" feedback. |
| Pacing | 3 | The first two minutes are walking and crate-collecting with no production. |
| Difficulty | 5 | Cold is a real pressure, but there is only one pressure. |
| Progression | 3 | One currency (heat) does everything: builds machines and expands radius. No decisions. |
| UI/UX | 3 | **Desktop HUD renders at roughly 7 device px** (0.5 scale on a 960-logical viewport). Unreadable on a laptop. |
| Onboarding | 5 | A single objective line does a lot of work, but hand actions are never taught. |
| Atmosphere | 4 | Snow and fog exist; **no music, no ambience**, 9 one-shot SFX only. |
| Sound | 3 | No bed, no danger stinger, no day/night transition audio. |
| Content density | 3 | Three machines, three items, one chain (frost+copper -> iron). |
| Replay motivation | 3 | No score, no goal past "keep going". |
| Stability | 9 | 11/11 tests, 0 console errors across the exercised path. |
| Performance | 8 | Fog bake landed in 0.5.5: 3.2 -> 7.7 FPS at 1920x1080 under software GL. |
| Overall | 4.5 | Systems work; the game underneath them is thin. |

## Five highest-impact weaknesses

1. **Progression has no decisions.** Heat is simultaneously the build currency and the progress meter, so there is never a trade-off. (Addressed by the Lv1-3 redesign.)
2. **The player has no agency in the first two minutes.** No hand mining; production is gated behind finding three crates. (Addressed by the redesign.)
3. **Desktop HUD is unreadable.** 0.5 base scale on a 960-logical viewport puts body text near 7 device px.
4. **No music or ambience.** The cold world is silent between one-shot effects.
5. **Feedback has no hierarchy.** Placing a belt and delivering to the core feel about the same.
