# Decisions — c2

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (7.3 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (14.4 s)
  > The counter went to 1 and the butterfly key turned a quarter. There's a faint thread running from the gear to one soldier (around 440,600). I'll wind it several more times.
  - ran `for i in $(seq 1 10); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0013.png` (24.1 s)
  - ran `node ./act.mjs click 420 605`
- **looked at** `seen/0014.png` (28.4 s)
  > Clicking the soldier did nothing. I'll try the glowing orb (a little face) next to the gear, then hover elsewhere.
  - ran `node ./act.mjs click 490 287`
- **looked at** `seen/0015.png` (31.8 s)
  > Nothing changed. The orb just bobs up and down. The soldier's ring looks like it's filling with my gear clicks, so I'll wind a lot more to see what happens when it's full.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0041.png` (55.2 s)
  > 36 spirals, and a tutorial hand just popped up pointing at the gear's center. It may want a hold instead of taps. I'll hold for 3 seconds.
  - ran `node ./act.mjs hold 640 380 3`
- **looked at** `seen/0042.png` (62.3 s)
  > Holding works too: +10 in 3 seconds, and the soldier's ring now looks about three-quarters full. I'll hold longer to finish it.
  - ran `node ./act.mjs hold 640 380 6`
- **looked at** `seen/0043.png` (72.2 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0044.png` (82.7 s)
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0045.png` (95.4 s)
  > 147 spirals. I don't see a shop yet. The small gear that appeared on top might be an upgrade, so I'll click it.
  - ran `node ./act.mjs click 660 265`
- **looked at** `seen/0046.png` (98.6 s)
  > Clicking the small gear counted as a wind (+1 per click) and didn't open anything. There's a sparkle button at the top left (92,40) that could be upgrades, so I'll try it.
  - ran `node ./act.mjs click 92 40`
- **looked at** `seen/0047.png` (102.4 s)
  - ran `node ./act.mjs click 92 40 >/dev/null; node ./act.mjs hold 640 380 8`
- **looked at** `seen/0049.png` (117.5 s)
  > Two awake dolls have walked over to wind the sleeper at the lower left. Now I'll see if the sewing machine does anything when clicked.
  - ran `node ./act.mjs click 410 380`
- **looked at** `seen/0050.png` (121.1 s)
  > The sewing machine doesn't seem to react to clicks, so it's probably decoration or a passive bonus. About 2 minutes in. I'll keep winding and watch the dolls.
  - ran `node ./act.mjs hold 640 380 10 >/dev/null; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0052.png` (145.5 s)
  - ran `node ./act.mjs hold 640 380 10 >/dev/null; node ./act.mjs hold 640 380 10 >/dev/null; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0055.png` (182.6 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes. **What I think the game is:** A cozy idle/incremental clicker set in a moonlit toymaker's workshop. You click or hold the big brass gear to wind it, and each turn earns a spiral, which is the game's currency. A thread links the gear to one sleeping toy soldier, and a ring around that soldier's key fills as you wind. When the ring is full, the soldier wakes up, then walks to the next sleeper and helps wind it. Each wake-up also adds something to the room: extra gears, a lamp, a red sewing machine, and a finished jacket on the mannequin. The clock hands move forward too. Awake dolls earn spirals on their own, so it becomes a chain reaction that wakes the whole workshop. **What I understood:** Clicking the gear gives +1 per click, and holding works as well. Once a doll woke up, spirals came in on their own. The sparkle button at the top left only toggles visual effects. **What confused me:** No text explains anything. The counter dropped once (156 → 24) with no visible purchase, so I think spirals get spent automatically on unlocks, but I'm not sure. Clicking the dolls, the glowing orb with a face, and the sewing machine did nothing I could see, and I never found a shop or any real choices to make. I also don't know what the clock or the orb are for. **Would I keep playing?** For a little while, yes. Watching the dolls wake up one by one and the workshop light up is charming, and progress shows on screen instead of in menus. But so far there are no decisions beyond "keep winding," so I'd only stick with it longer if choices or new mechanics show up once more dolls are awake.
