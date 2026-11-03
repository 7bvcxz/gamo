# Decisions — c3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (3.4 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (9.9 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (24.2 s)
  > The counter is at 16 and there's a small progress ring around the doll on the end of the thread (about 420,605). Maybe I can spend turns on that doll to wake it up. I'll click it.
  - ran `node ./act.mjs click 450 600`
- **looked at** `seen/0019.png` (29.3 s)
  > Clicking the doll did nothing. The ring sits right on its wind-up key at about 420,605, so I'll click the key itself.
  - ran `node ./act.mjs click 421 606`
- **looked at** `seen/0020.png` (33.9 s)
  > A hint hand has appeared over the gear. Since I've been idle, the game is telling me to keep winding it. The ring on the doll is probably filling as I wind, so I'll keep clicking.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0046.png` (50.8 s)
  > The counter is at 41 and the ring on the doll's key is nearly full, so winding the gear seems to charge that doll. I'll keep going until something happens.
  - ran `for i in $(seq 1 10); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0057.png` (60.9 s)
  > The ring now looks complete. I'll try clicking the doll's key again now that it's full.
  - ran `node ./act.mjs click 421 606`
- **looked at** `seen/0058.png` (65.2 s)
  > Nothing changed. The hint hand keeps pointing at the gear, so maybe it wants a press-and-hold instead of taps. I'll hold it for 3 seconds.
  - ran `node ./act.mjs hold 640 380 3`
- **looked at** `seen/0059.png` (73.6 s)
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0080.png` (96.5 s)
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0101.png` (121.7 s)
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0127.png` (149.5 s)
  - ran `node ./act.mjs click 490 280`
- **looked at** `seen/0128.png` (155.3 s)
  > Clicking the face did nothing I could see. Meanwhile the counter rose to 240 on its own, about 4 per second of passive income. I'll do one more stretch of winding to pass the three-minute mark.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0154.png` (178.5 s)
  - ran `node ./act.mjs wait 6 && node ./act.mjs end`
  > I played for about 3 minutes 10 seconds and then ended the session. **What I think the game is:** a calm incremental clicker set in a toymaker's workshop at night. You click a big brass gear to turn its wind-up key, and each turn adds one to the spiral counter at the top. The floor is covered in sleeping clockwork dolls. A thread runs from the gear to one doll and a ring around its key fills as you wind. When the ring is full the doll wakes up, joins the others, and they walk together to wind the next sleeper. **What I understood:** - Clicking the gear gives one point per turn. - Awake dolls produce points on their own. By the end the counter was rising about 4 per second without me. - Upgrades seem to buy themselves when you can afford them. The counter dropped (51→37, 113→69, 240→148) at the same moments new things appeared: a desk lamp, a red sewing machine, and three extra small gears. - The workshop gets brighter and warmer as more dolls wake up, which is a nice visual sign of progress. **What confused me:** - I never chose any purchase. Spending seemed to happen automatically, and I couldn't tell what each upgrade cost or did. - Clicking dolls, their keys, or the glowing face near the window did nothing I could see. I still don't know what that face is for. - My hold on the gear happened right before the first doll woke. I can't tell whether holding mattered or the ring had simply filled. The hint hand kept pointing at the gear long after I understood that part. **Would I keep playing?** For a little while, yes. The art and atmosphere are charming, and watching the group of dolls grow and travel across the room is satisfying. But I had very little to decide: clicking is the only real input, and upgrades happen without me. Unless later stages add choices, such as picking upgrades or a reason to use the clock, the dress form, or the glowing face, I'd probably stop once every doll on the floor is awake.
