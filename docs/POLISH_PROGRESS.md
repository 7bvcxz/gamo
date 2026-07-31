# Polish Progress

Each cycle ended with a runtime check and a commit.

## Cycle 1 — economy rebuild (`edac466`)
Split heat from materials, added hand mining, ground items, cat hauling, the
exchanger, generators and power, and machine unlocks. 12/12 tests green.
Found by the new test, not by review: `MINER_PERIOD` was still 5.75 s, which
broke the exchanger ratio, and power capacity was read from the previous
frame's flag. Also fixed a test-isolation bug where `test_build` inherited
`test_save`'s factory through the save file.

## Cycle 2 — HUD legibility (`191913f`)
Desktop base 0.5 -> 0.9 after measuring ~7 device px body text. Locked hotbar
cards now name their machine and what opens it instead of being covered by the
word "잠김". Material counters got names; the legend got the mine key.

## Cycle 3 — feel and audio (`55c01f5`)
Hand-mining progress arc on the worked seam, a single declared feedback scale
ordered by event frequency, and two generated ambient loops. The arc was drawn
amber-on-amber first and had to be rebuilt with a dark track.

## Cycle 4 — documentation truth
`/doc` still described the old frost/iron/furnace economy, which is now false.
Level Design, the summary diagram and Releases rewritten; 0.6.0 entry added.

## Verification run each cycle

```
godot --headless --path motorio-oneshot --script res://tests/test_*.gd   # 12/12
godot --headless --path motorio-oneshot --editor --quit                 # 0 errors
./deploy-web.sh motorio-oneshot
node final.js <build>       # desktop + phone, real input, FPS, console
```
