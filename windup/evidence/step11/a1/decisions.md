# Decisions — a1

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (8.0 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (16.3 s)
  - ran `for i in $(seq 1 10); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0013.png` (26.0 s)
  - ran `node ./act.mjs click 420 605`
- **looked at** `seen/0014.png` (30.6 s)
  > Clicking the doll didn't do anything I could see. Next I'll try the glowing orb and the scissors on the table.
  - ran `node ./act.mjs click 490 278`
- **looked at** `seen/0015.png` (33.9 s)
  > The orb didn't respond either. My best guess is that the ring near that doll fills as I wind the gear, and the doll wakes once it's full. I'll click the gear 30 more times to test that.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0046.png` (58.2 s)
  - ran `node ./act.mjs hold 640 380 3`
- **looked at** `seen/0047.png` (66.1 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0048.png` (81.2 s)
  - ran `node ./act.mjs click 660 268`
- **looked at** `seen/0049.png` (86.7 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0050.png` (96.9 s)
  - ran `node ./act.mjs click 660 265`
- **looked at** `seen/0051.png` (102.0 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0052.png` (117.1 s)
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0054.png` (143.6 s)
  - ran `node ./act.mjs click 410 380`
- **looked at** `seen/0055.png` (148.2 s)
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0058.png` (184.8 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes and ended the session at 188 seconds. **What I think the game is:** A cozy incremental game set in a moonlit toymaker's workshop. You wind a big brass gear, by clicking or holding it, to earn "turns" (the spiral counter). A thread carries that energy from the gear to one sleeping wind-up doll at a time. When a doll's ring fills, it wakes up and some turns are spent; the counter dropped to 46 after the first wake and to 8 after the second. Each doll that wakes seems to: - add a helper gear to the main gear (I ended with three), - raise passive income, since the counter kept climbing while I did nothing, - light up or reveal part of the room: first a desk lamp on the workbench, then a red sewing machine uncovered on the side table, - get up and walk over to help with the next sleeping doll. The counter reached 330 by the end, and the room got visibly warmer and brighter as it woke up. **What I understood:** The main loop of wind → wake doll → more gears and income → wake the next one was clear within about a minute and a half, without any text. The tutorial hand appeared after I'd already been clicking, and holding the gear turned out to work as well. **What confused me:** - I couldn't tell whether waking a doll costs a set price or just drains whatever turns you have. - The glowing face by the shelf, the scissors, and the sewing machine didn't respond when I clicked them, and I couldn't work out what the orb is. - I didn't find any upgrade or shop screen. Clicking the small gears just counted as winding the main gear. - The thicker, layered ring around the gear looked like a speed or combo meter, but I'm not sure. **Would I keep playing?** Yes, for a while. It's charming, and the room changing as it wakes up is a nicer reward than a bigger number. Lots of objects were still asleep, like the grandfather clock, the dress form and the shelf jars, and I'd want to see them come alive. My worry is that it's only holding the gear. Without choices to make, such as upgrades or deciding which doll to wake, I expect the novelty would wear off within 10–15 minutes.
