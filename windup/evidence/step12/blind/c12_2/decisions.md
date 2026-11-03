# Decisions — c12_2

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (3.8 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (9.6 s)
  > That click added 1 spiral and turned the key a quarter turn, so this is a clicker. A faint thread runs from the gear down to one doll, which might be what gets wound. I'll click a batch of times.
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0023.png` (23.5 s)
  - ran `node ./act.mjs click 450 600`
- **looked at** `seen/0024.png` (28.0 s)
  > Clicking the doll did nothing visible, and the spirals stayed at 21. Next I'll try the glowing button spirit.
  - ran `node ./act.mjs click 490 284`
- **looked at** `seen/0025.png` (30.8 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0056.png` (48.2 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0057.png` (58.3 s)
  - ran `for i in $(seq 1 40); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0098.png` (86.2 s)
  > Up to 159 spirals. The ring at about (875,610) now looks full, but nothing new has woken. Maybe the full ring needs a click to finish the wake-up, so I'll try clicking it.
  - ran `node ./act.mjs click 875 610`
- **looked at** `seen/0099.png` (89.8 s)
  - ran `for i in $(seq 1 40); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0140.png` (113.6 s)
  > Back to 159. The two awake dolls walked over to the left doll and seem to be helping wind its key, since its ring is partly filled. I'll wait for it to fill and then click it.
  - ran `node ./act.mjs wait 8`
- **looked at** `seen/0141.png` (125.2 s)
  > Spirals rose to 196 by themselves, but the ring at (255,650) still isn't full. I suspect it tracks how close I am to the next cost rather than physical winding. I'll click it to test.
  - ran `node ./act.mjs click 255 650`
- **looked at** `seen/0142.png` (129.8 s)
  > Nothing happened; it isn't ready yet, and the next wake-up probably costs more. I'll keep cranking.
  - ran `for i in $(seq 1 40); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0183.png` (155.3 s)
  - ran `for i in $(seq 1 40); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0224.png` (182.2 s)
  > I'm at 182 seconds with 321 spirals. Before stopping, I'll click the current target ring at (1020,648) to see if it's ready.
  - ran `node ./act.mjs click 1020 648`
- **looked at** `seen/0225.png` (185.6 s)
  > No purchase this time; the awake dolls are still winding. I've played past three minutes, so I'm stopping.
  - ran `node ./act.mjs end`
  > I played for about 3 minutes and finished with 338 spirals, 3 awake dolls, 4 extra gears, a lamp and a sewing machine. **What I think the game is:** a calm incremental (clicker) game set in a moonlit toymaker's workshop. You click the big brass gear to turn its key, and each click earns 1 spiral. A golden thread runs from the gear to one sleeping wind-up doll, and a ring around that doll's key fills up. Each time a doll wakes, the workshop grows: a desk lamp lights up, a sewing machine appears, and more small gears join the big one. Spirals also start coming in on their own; early on I got about 18 in 10 seconds without clicking. The awake dolls walk over to the next sleeping doll and help wind it. **What I understood:** - The basic loop: crank, earn spirals, spend them to wake dolls and add gears, which earns more spirals on their own, then repeat. - The workshop gets visibly warmer and busier as you progress. - The wall clock moves forward as you progress, which suggests the night is passing toward a goal, maybe waking every doll before morning. **What confused me:** - Spending wasn't clear. The first wake-up happened when I clicked a full ring (159 → 23 spirals). The second seemed to happen by itself between my screenshots. Clicking rings that weren't full did nothing. - I couldn't tell whether a ring shows spiral cost, physical winding progress, or both. Nothing shows a price. - The glowing button-face spirit didn't seem to do anything when clicked. It may just be a guide, since a tutorial hand appeared over the gear right after. - I never checked what the two top-left buttons do. **Would I keep playing?** Probably for a while. The art and the slow brightening of the workshop are charming, and I'd like to know what happens when all the dolls are awake or the clock reaches morning. The click-to-earn part is thin on its own, though. Clearer feedback on prices and on what each purchase gives would make the decisions feel like they matter.
