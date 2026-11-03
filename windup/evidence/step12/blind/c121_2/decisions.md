# Decisions — c121_2

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (3.8 s)
  > A night workshop: a big brass wind-up key/gear on a table, a row of sleeping wind-up dolls on the floor, and a spiral counter at 0. My guess is that clicking the gear winds things up. Let me try it.
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (8.4 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (19.0 s)
  - ran `node ./act.mjs click 490 280`
- **looked at** `seen/0019.png` (24.3 s)
  > The wisp just drifted away; it doesn't look clickable, or I missed it. Now I'll try the doll that the thread connects to.
  - ran `node ./act.mjs click 450 605`
- **looked at** `seen/0020.png` (28.4 s)
  > A tutorial hand popped up pointing at the key, so the game wants more winding. A small ring is also traveling along the thread toward the doll, like the energy is flowing to it. I'll keep winding.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0051.png` (44.0 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0082.png` (60.1 s)
  - ran `node ./act.mjs click 660 265`
- **looked at** `seen/0083.png` (66.8 s)
  > Clicking the small gear just wound the key again (106). There's no shop; progress seems automatic as the total grows. I'll keep winding in bigger batches.
  - ran `for i in $(seq 1 40); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0124.png` (84.7 s)
  - ran `for i in $(seq 1 50); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0175.png` (113.6 s)
  - ran `for i in 1 2 3 4 5; do node ./act.mjs click 165 610 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0181.png` (121.3 s)
  - ran `for i in $(seq 1 50); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0232.png` (145.7 s)
  - ran `for i in $(seq 1 50); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0283.png` (172.1 s)
  > Up to 393 spirals. The awake group is still working on the right-side sleeper. I'll do a short final batch to get past three minutes.
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0304.png` (185.2 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 10 seconds. **What I think the game is:** a calm idle/clicker game set in a toymaker's or tailor's workshop at night. You click a big brass wind-up key to earn spirals. Sleeping wind-up dolls lie on the floor. Once you've built up enough spirals, the game spends them by itself to wake the doll that the glowing thread points to. Awake dolls make spirals on their own and walk over to help wind the next sleeper. Every so often the workshop also upgrades: a desk lamp lit up, then a red sewing machine appeared, extra gears were added to the key mechanism (five by the end), and the half-made garment on the dress form became a finished jacket. **What I understood:** - Clicking the key gives spirals. - Waking dolls and unlocking objects costs spirals. I could tell because the counter dropped sharply each time (for example 220 → 174 and 393 → 104), even though I never pressed a buy button. - Awake dolls earn spirals while you're not clicking: the counter went up about 24 in 7 seconds while I wasn't winding. - The extra gears seem to increase how much each wind earns. **What confused me:** - There's no shop, prices or progress bar, so I couldn't tell how much the next unlock would cost or when it would happen. - The floating little face (a wisp or ghost) near the shelf moved when I clicked it but did nothing I could see. - I never worked out whether clicking a sleeping doll does anything, or what the top-left icons and the top-right reset arrow do. I didn't try the reset arrow, in case it erased my progress. **Would I keep playing?** For a while, yes. Watching the dark room fill with light, machines and dolls is satisfying, and it's clearly working toward waking all of them, maybe finishing the whole workshop. Since you don't make any real choices, I'd probably let it run in the background rather than click actively for long. A visible goal or the cost of the next unlock would give me more reason to stay engaged.
