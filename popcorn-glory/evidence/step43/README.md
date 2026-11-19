# Step 43 evidence — the factory's sound (grammar, soundscape, mixing)

Everything here was measured on the real game. The browser files come from the page's actual audio
output, read by an AudioWorklet meter, a stereo meter, Web Audio buffer counts and a MediaRecorder
(`tests/e2e/lib/audio_tap.mjs`) on the exported web build. The offline spectra come from the game's own
sound files. The score is `design/SOUND.md`; the decision is D-63.

**No human ear evaluated these sounds.** On the real S23 the page's output was measured, but the media volume was 0 and nobody listened (`device/`; real listening is Step 48). The figures and
pictures below are the whole basis.

| file | what |
|---|---|
| `spectra/grammar43_spectrum.png` · `grammar43_wave.png` · `hiss_table.md` | the 19 new sounds and the 13 old ones, from `tools/build_audio.py`. The factory kettle's heat loop has an 18.2 dB gap above 4 kHz; the old sizzle had 7.0 dB, so the new heat is not the old hiss. |
| `spectra/browser_factory44_hand_*.png` · `audio/factory44_hand_desktop.webm` | a recording of the page output: 44 machines, the hand popping. Over 100 ms windows, the median RMS is −37.8 dBFS (p5 −42.7, p95 −31.2, max −22) and the peak is −9.8 dBFS. No window is silent. The floor falls to about −46 dBFS after a Perfect Pop (the duck) and sits around −32 while the hand holds. |
| `browser/e2e43_sound.json` · `load_sound.txt` | `sound43` and `sound05` on p720, phone and desktop: 36/36 (before the beds were raised 6 dB) |
| `browser/e2e43_regression.json` · `load_regression.txt` | the focused regression on all three screens: stall09, burst14, factory17/18/19, craft35, customers36, news37, contests38, motion42, release12, play_stand and sound43. **70 passed, 11 skipped, 0 failed.** Load was 8.3 → 8.1 (other sessions were busy). The sound43 figures from this run follow the table. |
| `browser/e2e43_sound05_responsive07_after_off.json` · `load_sound05.txt` | after "off" became "play nothing": `sound05` and `responsive07` on three screens, 51/51 |
| `browser/e2e43_soak_paired.json` · `load_soak_paired.txt` · `audio/soak43_rows_off.json` · `audio/soak43_rows.json` · `audio/soak44_minute1_30s_desktop.webm` | **the final soak, 2/2**: ten real minutes at 44 machines with the sound off (the control), then ten with it on. The rows are below the table. |
| `browser/e2e43_soak_try2_failed.json` · `load_soak_try2.txt` · `audio/soak43_rows_try3_before_control.json` · `audio/soak43_rows_nocopy.json` | the earlier soaks, kept as they failed. See the history after the table. |
| `device/` | **the real S23** (Chrome 157, Android, held in landscape): the public 0.43.0 in the phone's own Chrome, with the page's output measured on the phone's audio thread (the same `AUDIO_TAP`, injected through DevTools over `adb forward`). Each kettle hold was a real finger, `adb shell input swipe`, at a point calibrated by one real tap. Run 1: four holds (3 Perfect, 1 early), peak 0.44–0.48, mean loudness 0.022–0.029, AudioContext `running`, no page errors. Run 2 (`?dev=1`): four Perfects, peak 0.45–0.47, then 12 machines: floor mean 0.0060, 1 bed playing, voices peak 3. Media volume was 0, as found, and **nobody listened**: this proves the page sends the sound on the device, not how it sounds. The context was already `running` before the first touch here (Chrome on Android, opened through DevTools), so the first-gesture unlock was measured only in the desktop browser (`sound43` test 1). The game's save was removed from the phone afterwards. `s23_sound.mjs` is the script. |
| `headless/full_try1_315_1.log` · `full_316_0.log` · `full_final_316_0.log` | the full headless suite. The first try failed on `test_assets` because `patter` was 0.02 s, under the 0.03 s floor; the sound was lengthened to 0.06 s. Then 316/0, and 316/0 again on the final source. |

## sound43 in the regression run (desktop; p720 and phone within a few %)

- The floor's mean loudness (`mean_rms`): one machine 0.0052, 44 machines 0.0122 (×2.4; the test asks for >1.5× and <0.08). The peak is 0.10 with one machine and 0.13 with 44.
- The hand over 44 machines: peak 0.475 (p720 0.499, phone 0.454). Full scale is 1.0.
- Panning: a sound at the left edge has energy L 19.3 / R 9.6; at the right edge L 10.4 / R 19.9.
- A hidden tab: RMS 0 and peak 0, sound paused, 0 beds. When the tab comes back the floor is heard again (RMS 0.050).
- Calm: 0 beds. The floor RMS drops from 0.037 to 0.023; the hand is still heard (RMS 0.083).
- Cash: 33 sold, 33 asked, 24 played. Each sale asks once; the 160 ms gap merges sales in the same moment.

## The final soak (rows every 30 s; renderer memory read after a forced GC)

| | sound off (control) | sound on |
|---|---|---|
| plays (buffer sources) | 0 | 3,538 |
| bytes the engine copied (one copy per play) | 0 | 1,147 MB |
| registered samples | — | 16 → 17, flat after the first minute |
| loudest moment | — | 0.492 (the first minute, the hand), 0.13–0.17 after |
| mean loudness | — | 0.0135–0.0189, never silent |
| voices at once (peak) | — | 6 (pool 16) |
| renderer memory, first row → median of the last third | 343 → 525 MB (+182) | 352 → 555 MB (+203) |

**What the sound itself adds is 21 MB over ten minutes.** Kept copies would have added hundreds of MB.
The rest of the growth happens with the sound off as well, so it belongs to the factory and the software
renderer. It is recorded as a finding for Step 46, the performance and long-run suite. It was not
changed here.

## The public 0.43.0 suite (`tests/results/step43/public/`)

`tools/test_all.sh --public` on https://7bvcxz.github.io/gamo/popcorn-glory/ once Pages served 0.43.0
(`version_tested.json`: `game-9bea9c452e14.pck`, 972,888 bytes, source 6cd69a6c, the same pack as the local run).

- headless: 316 passed, 0 failed (22,789 checks, 21 files).
- browser, three screens: 264 passed, 0 failed, 39 skipped. One test needed a retry: `craft35` on the
  desktop, `TypeError` reading the spoon's rect at `pop.hold` (the batch ended before the hold began).
  It passed on the retry and on p720 and phone. The same spoon race was seen in the Step 42 public run
  (`tests/results/step42/public/`), so it is not Step 43 code. Load at the start 1.11, at the end 11.27 (`load.txt`).
- The paired soak ran again on the public build (`audio/soak43_rows_off_public.json`, `audio/soak43_rows_public.json`):
  off 0 plays, renderer 332 → 536 MB (+204); on 3,686 plays, 1,195 MB copied, renderer 393 → 555 MB (+162),
  loudest 0.478, mean loudness 0.0137–0.0186, voices peak 7, samples 16 → 17. The sound's own share is again
  inside the noise (−42 MB here, +21 MB locally). The hand popped 3 times in each run: the bin was full.

## History of the soak

1. **First run.** Every assertion passed except "decoded buffers": 351 → 3,670. Splitting `createBuffer` calls by call stack showed these were Godot 4.7's per-play copies (`Sample.getAudioBuffer()` → `_duplicateAudioBuffer()`, shared engine code). The registered samples stayed flat at 16–17.
2. **Second run** (`e2e43_soak_try2_failed.json`). Renderer RSS rose from 524 to 780 MB, read without a GC, and the test failed.
3. **Third run** (`soak43_rows_try3_before_control.json`). With a forced GC first, RSS still rose from 351 to 671 MB. A first control made each copy one frame long (`soak43_rows_nocopy.json`). That made the engine restart its looping beds over and over: 31,866 plays instead of 3,736, and silence. A control that changes the number of plays is not a control.
4. **Final run.** "Off" now plays nothing at all (`app/audio.gd`: a muted page does no audio work), and the soak runs that as the control next to the loud run. It passed.

## Also found

- **With the soak's 44-machine plan (sign 8, packer 3), the hand can almost never pop.** The bin stays full, so the hand's glass waits to pour (`err.kettle_full`): 19–20 of the 20 tries in every 30 s window after the first. A player with such a factory would meet the same rule. This is the existing factory flow, not Step 43 code. It is reported in #156 for the usability and balance steps. The duck while holding is measured by `sound43` and `test_soundscape` instead.
- Each 100 ms window of the recording has sound. The quietest five percent sit at −42.7 dBFS.
