# Decisions — pilot0

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (7.9 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (13.6 s)
  - ran `for i in 1 2 3 4 5 6 7 8 9 10; do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0013.png` (26.3 s)
  > The counter is at 11. Next to the connected doll's wind-up key (420,605) a yellow ring has started filling, so the gear seems to charge that doll. I'll click the doll's key directly.
  - ran `node ./act.mjs click 422 605`
- **looked at** `seen/0014.png` (31.5 s)
  > Clicking the doll did nothing visible. Its ring is about a quarter full, so I'll keep winding the gear to fill it.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0045.png` (53.1 s)
  - ran `node ./act.mjs click 639 330`
- **looked at** `seen/0046.png` (58.9 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0062.png` (81.9 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0063.png` (94.3 s)
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0084.png` (125.5 s)
  > The counter is at 102. The second doll's ring is filling, but slowly. I still don't see any shop, so maybe the room objects are what you buy. I'll try clicking the grandfather clock.
  - ran `node ./act.mjs click 1155 300`
- **looked at** `seen/0085.png` (131.3 s)
  > Clicking the clock did nothing. There's a dark red circular shape peeking in at the bottom-right corner that might be a menu, so I'll try it.
  - ran `node ./act.mjs click 1255 695`
- **looked at** `seen/0086.png` (137.0 s)
  > That did nothing either. Purchases seem to happen automatically (the first one did), so the game may be pure winding plus watching. I'll keep winding to wake the second doll.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0117.png` (169.9 s)
  - ran `node ./act.mjs wait 8`
- **looked at** `seen/0118.png` (184.2 s)
  > Passive income is clearly running now: 84 went to 129 in about 8 seconds while the two awake dolls wind the next sleeper. I've passed three minutes, so I'm stopping here.
  - ran `node ./act.mjs end`
  > I played for about 3 minutes (188 seconds). **What the game is:** A cozy idle/clicker game set in a toymaker's workshop at night. You click a big brass gear to turn its wind-up key, and each click adds one spiral to the counter at the top. A thread links the gear to one sleeping wind-up doll on the floor, and winding fills a ring by that doll's key. When the ring is full, the doll wakes up and walks over to wind the next sleeper. After the first doll woke up, I started earning spirals without clicking. **What I understood:** - Clicking the gear charges the linked doll, and awake dolls go on to wake the others. - Progress seems to buy upgrades by itself. Each time a doll woke up, the counter dropped (41→6, later down to 84) and something new appeared in the room: a desk lamp, extra small gears, and a red sewing machine. The gear also glowed brighter as these were added. - Passive income grows as more dolls wake: roughly 84→129 in 8 seconds near the end, with two dolls awake. **What confused me:** - There's no visible shop or upgrade menu. I couldn't tell whether the upgrades were bought automatically or simply unlocked when a doll woke, or what each one does. - A big ring briefly appeared around the gear and then shrank. It might be a combo meter, but I'm not sure. - Clicking the floating glowing face, a sleeping doll, the grandfather clock, and the red shape in the bottom-right corner did nothing I could see. **Would I keep playing?** For a little while, yes. Watching the dolls wake one another and the workshop fill up is charming, and I'd want to see the room finished with all twelve dolls up. But I barely make any choices, so I expect it would lose its pull once the novelty wears off.
