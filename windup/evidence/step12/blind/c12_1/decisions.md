# Decisions — c12_1

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (4.2 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (10.5 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (22.6 s)
  - ran `node ./act.mjs click 425 605`
- **looked at** `seen/0019.png` (28.5 s)
  > Clicking the doll did nothing visible. The ring is still only partly filled. I'll try holding the mouse on the gear to wind it continuously.
  - ran `node ./act.mjs hold 640 380 4`
- **looked at** `seen/0020.png` (37.6 s)
  > Holding works, at roughly 5 spirals per second (now 35). The ring at the doll's key is almost full. I'll keep winding to see what happens when it completes.
  - ran `node ./act.mjs hold 640 380 5`
- **looked at** `seen/0021.png` (47.4 s)
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0022.png` (62.0 s)
  - ran `node ./act.mjs hold 640 380 9`
- **looked at** `seen/0023.png` (77.7 s)
  - ran `node ./act.mjs click 410 385`
- **looked at** `seen/0024.png` (85.2 s)
  - ran `node ./act.mjs wait 10`
- **looked at** `seen/0025.png` (101.5 s)
  - ran `node ./act.mjs click 549 340`
- **looked at** `seen/0026.png` (108.6 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0027.png` (125.0 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0028.png` (141.7 s)
  > The three awake dolls marched over to the right side and are winding the next sleeper together, like a little bucket brigade. I'm at 174. I'll keep the gear going.
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0029.png` (157.3 s)
  > Up to 322, about 15 per second while holding. The ring on the right sleeper is filling more slowly, so the wake cost seems to rise with each doll. I'll keep holding.
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0030.png` (172.8 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0031.png` (189.8 s)
  > Three dolls are winding the middle sleeper while the fourth stands guard on the right. I'm at 301 spirals and past the three-minute mark, so I'll stop here.
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 14 seconds. **What the game is:** A cozy clockwork idle/clicker game set in a tailor's workshop at night. You click or hold the big brass gear to spin a golden bobbin and earn spirals. A glowing thread links the bobbin to one sleeping wind-up doll at a time, and a ring by its key fills as you earn. When the ring completes, some spirals are spent, the doll wakes up, and it joins the crew winding the next sleeper. Each wake also raises income and adds something to the room: - After 1 doll: a small gear and a desk lamp. - After 2: the sewing machine was uncovered. - After 3 and 4: more gears, and the half-sewn dress form became a finished jacket. **What I understood:** - Holding the gear works much better than single clicks, at about 5 spirals per second early on and about 15 later. - Awake dolls produce passive income (about 3 per second with two awake). - Each wake costs more than the last. - The workshop gradually "comes to life" as a visual progress meter. By the end I had 4 of roughly 15 dolls awake and 301 spirals. **What confused me:** - The counter dropped suddenly at each wake (121→69, ~170→26, ~320→87), with nothing on screen saying what it cost or that it was spent automatically. - Clicking the sewing machine and the floating button-faced sprite did nothing I could see. I couldn't tell if they're interactive or just decoration. - There's no shop or upgrade menu that I found. I didn't try the two top-left icons (sound and probably settings) or the reset button at the top right. **Would I keep playing?** For a while, yes. The art is charming, and watching the doll crew march around reviving their friends while the room fills with gears and finished clothes is satisfying. But there's very little to decide so far: you just hold the gear. Unless upgrades or the sewing machine and clock open up later, I'd probably lose interest once all the dolls are awake.
