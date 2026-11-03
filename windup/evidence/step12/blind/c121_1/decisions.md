# Decisions — c121_1

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (4.4 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (9.6 s)
  - ran `for i in 1 2 3 4 5 6 7 8; do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0011.png` (19.2 s)
  > 9 spirals now. The ring around the doll at (420,605) seems to be filling up like a progress bar, so I think winding the key will eventually wake that doll. Clicking more.
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0032.png` (30.9 s)
  > 29 spirals, and the ring is about two-thirds full. I'll try clicking that doll directly to see if I can wind it by hand.
  - ran `node ./act.mjs click 450 610`
- **looked at** `seen/0033.png` (35.6 s)
  > Clicking the doll did nothing. There's a red curved shape peeking in from the bottom-right corner that might be a menu or shop, so I'll check it.
  - ran `node ./act.mjs click 1260 700`
- **looked at** `seen/0034.png` (40.1 s)
  > A pointing-hand hint appeared over the key, so the game wants me to keep winding. Back to clicking.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0060.png` (52.6 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0091.png` (70.2 s)
  > The counter jumped to 111, well beyond my number of clicks. Either the awake doll produces spirals on its own or each click now pays more. The doll is walking around the floor. Winding the next doll.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0122.png` (86.3 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0153.png` (104.7 s)
  > Up to 141. The two awake dolls walked over to the sleeping doll on the left and seem to be turning its key, so awake dolls help wind the next one. It's a nice chain-reaction idea. More winding.
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0184.png` (120.6 s)
  > Two minutes in, with 237 spirals, but this third doll's ring is filling slowly. Maybe the sewing machine is something I can use or upgrade, so I'll click it.
  - ran `node ./act.mjs click 410 385`
- **looked at** `seen/0185.png` (130.3 s)
  > Clicking the sewing machine did nothing visible. Spirals are building up passively at roughly 3 per second. I'll try holding the mouse on the key to see if it winds continuously.
  - ran `node ./act.mjs hold 640 380 4`
- **looked at** `seen/0186.png` (139.0 s)
  - ran `node ./act.mjs hold 640 380 8; node ./act.mjs hold 640 380 8; node ./act.mjs look`
- **looked at** `seen/0189.png` (161.8 s)
  > 324 spirals. The three awake dolls have gathered around the fourth target on the right and are winding it. I'll do a final stretch of winding to pass three minutes.
  - ran `node ./act.mjs hold 640 380 9; node ./act.mjs hold 640 380 9; node ./act.mjs look`
- **looked at** `seen/0192.png` (185.9 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 10 seconds. **What I think the game is:** A cozy idle/clicker game set in a moonlit tailor's workshop. You wind a big brass key, which earns spirals (the currency) and gradually winds up sleeping clockwork dolls on the floor. When a doll's ring fills, it wakes up and some spirals are spent. Awake dolls walk to the next sleeping doll and help wind it, and they also seem to bring in spirals on their own. Each awakening adds something to the room: a desk lamp, the sewing machine, more gears on the main mechanism, and the jacket on the dress form getting finished. I woke four dolls in total. **What I understood:** - Clicking or holding the key earns spirals. Holding worked better than single clicks. - Waking a doll costs spirals. The counter dropped twice, from 111 to 37 and from 268 to 74. - Awake dolls work like automation and speed up the next wake-up. - The room fills with light and objects as you go, which is nice to watch. **What confused me:** - I never found anywhere to spend spirals myself. Clicking dolls, the sewing machine and the corner object did nothing, so the spending seems to happen automatically. - The idle hint showed up but never explained the rules. - I'm not sure what the clock means. It moved from about 11:40 to 11:55, so maybe the game ends or changes at midnight. - I don't know what the glowing face orb near the shelf or the red shape in the corner do. **Would I keep playing?** For a while, yes. Watching dolls wake up in a chain and the workshop come to life is charming, and I'd like to see what happens at midnight. It doesn't give me much to decide, though, so unless choices or upgrades show up later, I'd probably play it as a short ambient toy and not for long sessions.
