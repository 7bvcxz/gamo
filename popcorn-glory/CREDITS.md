# Credits and rights inventory — Popcorn & Glory 0.48.0

Everything the game ships was written in this repository, or comes from the engine under the
engine's licence. No recorded sound, stock image, purchased asset, generated image or third-party
game art is in the build.

| What ships | Made from | How | Rights |
|---|---|---|---|
| Game code (`app/`, `core/`, `variants/`, `art/*.gd`, `data/`) | This repository | Hand-written GDScript and JSON | The repository owner's |
| Machines, floors, people, goods, signs, icons, effects | `art/*.gd`, `variants/factory/*.gd`, `app/ui/*.gd` | Drawn at run time with Godot's `draw_*` calls; some drawings are baked once into textures at run time (D-68) | The repository owner's |
| Sprite atlas (`assets/atlas/sprites.png`, `.json`) | `art_src/*.svg`: coin, kernel, popcorn pieces, smoke, sparkle, steam | SVG written by hand in this repository, rasterised by `tools/build_atlas.gd` (Godot's own SVG loader) | The repository owner's |
| Sound (`assets/audio/*.ogg`, 32 files) | `tools/build_audio.py` | Synthesized from formulas (sines, noise, bell partials, a fixed seed), then 16-bit WAV → Ogg Vorbis with ffmpeg. No recording or sample. Every shipped file is checked to come from the script | The repository owner's |
| Text font | Godot's built-in default font, Open Sans | Engine default (no font file in the project) | © 2020 The Open Sans Project Authors, SIL Open Font License 1.1 |
| Engine | Godot Engine 4.7 (`4.7.stable.official.5b4e0cb0f`), the shared web build `docs/engine/` | Official export template | MIT licence. The engine's third-party notices: https://godotengine.org/license |
| Web pages (`web/about.html`, `web/saves.html`) | This repository | Hand-written HTML | The repository owner's |

**Not in the build** (checked on each deploy: `tools/deploy.sh` fails if the pack contains
`res://design/`, `res://tests/`, `res://tools/` or `res://evidence/`; `strings` on the 0.47/0.48 packs
finds none of them, nor `art_src`):

- Design references (`design/mood/*.svg`), QA evidence, test fixtures and the blind players' screenshots.

**Tools used to make, but not shipped:** Godot (headless export and tests), Playwright Chromium
(browser tests, screenshots, recordings), ffmpeg (Ogg encoding, video re-encoding), Python 3 (the
sound script), Claude agents (the blind AI playtests, as players, not as authors of content).

**Paid or generative content tools:** none. `imagegen` and TopView were not used (`design/ART_AUDIO.md`).

Licences shown to players: `web/about.html` (Godot's MIT text and Open Sans's OFL notice).
