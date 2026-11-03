# Decisions — c121_3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (4.2 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (10.0 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (19.7 s)
  > The counter is at 16. A progress ring seems to be filling around the key of the doll at about (420, 605), the one the thread connects to. I'll click that doll to see what it does.
  - ran `node ./act.mjs click 450 600`
- **looked at** `seen/0019.png` (24.1 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0050.png` (42.4 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0081.png` (61.3 s)
  - ran `node ./act.mjs click 660 265`
- **looked at** `seen/0082.png` (66.7 s)
  > Clicking the small gear didn't open anything obvious, and the counter keeps rising passively (112). Next I'll try the glowing wisp near the shelves.
  - ran `node ./act.mjs click 490 281`
- **looked at** `seen/0083.png` (71.1 s)
  > The wisp just drifted away. There's a dark red disc partly visible in the bottom-right corner that might be a shop or menu, so I'll try that.
  - ran `node ./act.mjs click 1255 690`
- **looked at** `seen/0084.png` (75.4 s)
  > That didn't open anything either. It looks like winding is the only control, so I'll test whether holding on the gear winds it continuously.
  - ran `node ./act.mjs hold 640 380 5`
- **looked at** `seen/0085.png` (85.5 s)
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0086.png` (99.4 s)
  > Both awake dolls have walked over to wind the left-side doll together, so awake dolls seem to help wake the next one. I'll check whether the uncovered sewing machine does anything when clicked.
  - ran `node ./act.mjs click 410 385`
- **looked at** `seen/0087.png` (104.8 s)
  > No visible response from the sewing machine. It's probably decoration that unlocks with progress. Back to winding.
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0089.png` (129.9 s)
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0091.png` (156.8 s)
  > The counter has grown to 428 and the clock reads about 11:57. The three awake dolls are working on the doll near (1015, 650). I'll keep going to see what happens at midnight.
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0094.png` (192.9 s)
  > Four dolls are awake now, a fifth gear has appeared, and the dress form now wears a finished jacket. More than three minutes have passed, so I'll stop here.
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 15 seconds. **What I think the game is:** a small, cosy idle/clicker game set in a toymaker's or tailor's workshop at night. You turn a big brass wind-up key (by clicking or holding) to earn spirals. A thread links the key to one sleeping wind-up doll, and winding fills a ring around that doll's key. When the ring fills, the doll wakes up. It then walks over and helps wind the next sleeping doll, and also produces spirals on its own, so progress speeds up. **What I understood:** - Clicking or holding the big key gives spirals, and awake dolls add passive income. The count went 0 → 16 → 101 → 428 → 575. - Each doll that wakes seems to cost spirals: the count dropped from 127 to 66 when the second doll woke. - Each wake-up also changes the room. A desk lamp turned on, the cloth came off a red sewing machine, extra small gears attached to the big one, and the dress form went from an empty half-cloth to a finished jacket. By the end, 4 of about 16 dolls were awake and 5 gears were showing. **What confused me:** - Nothing besides the key responded to clicks: not the small gears, the glowing wisp, the sewing machine or the corner disc. I never found a shop or upgrade menu, so I couldn't tell whether there are real choices or it's fully automatic. - The grandfather clock moved from about 11:35 to 11:58 while I played. I couldn't tell whether midnight is a deadline, a reward or just atmosphere, and I stopped before reaching it. - The thread seems to pick the next doll on its own, and I'm not sure whether I can choose which one. **Would I keep playing?** Briefly, yes. The art is charming, and watching the workshop fill with life is satisfying. I'd especially want to see what happens at midnight and once every doll is awake. But I didn't find any decisions to make beyond holding the mouse button, so unless choices or upgrades open up later, I'd expect it to feel more like a short ambient toy than something I'd play for long.
