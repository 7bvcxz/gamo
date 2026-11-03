# Decisions — b2

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (8.9 s)
  - ran `node ./act.mjs click 489 274`
- **looked at** `seen/0002.png` (18.0 s)
  > The click did nothing I can see; the orb is just bobbing. My guess is the gear is a launcher and the arc is its aim, so I'll drag from the hub like pulling back a slingshot.
  - ran `node ./act.mjs drag 640 380 700 300 1`
- **looked at** `seen/0003.png` (25.6 s)
  - ran `node ./act.mjs click 640 380; node ./act.mjs click 640 380; node ./act.mjs click 640 380`
- **looked at** `seen/0006.png` (32.3 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0022.png` (48.3 s)
  > Up to 30. The gold ring on the shell at (420, 605) keeps filling, so it looks like a progress meter for whatever the gear is feeding. I'll keep clicking until it completes.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0048.png` (71.5 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0049.png` (82.8 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0080.png` (119.9 s)
  > I'm at 117 spirals and the ring on the doll's sheet is about 80% full. The cost seems higher this time, since I didn't get a reset at 40. I'll push it over.
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0096.png` (142.6 s)
  - ran `for i in $(seq 1 30); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0127.png` (176.5 s)
  > Both dolls are now crowded around the third sheet and pulling at it together, and the ring there is about two-thirds full. A few more clicks should finish it.
  - ran `for i in $(seq 1 12); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0140.png` (191.3 s)
  > I've played past the three-minute mark, and the third ring is almost full. I'll stop here.
  - ran `node ./act.mjs end`
  > I played for about 3 minutes and 14 seconds. **What I think the game is:** a cozy idle/clicker set in a moonlit tailor's workshop. Clicking the big brass gear earns spirals (+1 per click), and a curved line from the gear points at the current goal. The pale shapes on the floor are dust sheets over sleeping wind-up dolls. When enough spirals reach the targeted sheet, its ring fills, the spirals are spent, and a doll wakes up. Each unveiling also changes the room: a new small gear on the machine, a desk lamp, a sewing machine uncovered on the chair, the clock moving. Awake dolls earn spirals passively (roughly 1–2 per second) and walk over to help pull at the next sheet. **What happened:** I woke two dolls, one in a top hat and one in a blue beret. The third unveiling was almost done when I stopped, at 229 spirals. Each one seemed to cost more than the last: around 40 for the first, around 130 for the second. **What confused me:** - Clicking the glowing orb with a face near the shelves did nothing I could see. It might be a guide character or something that matters later. - My first move was a drag, and it gave a burst of 12 spirals instead of the usual 1, so maybe dragging or spinning the gear pays more. I didn't test it again. - I never found a shop or upgrade menu. The reset button (top right) and the sparkle button (top left) were left alone. **Would I keep playing?** For a while, yes. The art and atmosphere are charming, and it's satisfying when each unveiling makes the room a little brighter and fuller. With about 18 sheets left, I'd want to see whether new mechanics show up, such as upgrades or the orb doing something. If it stays at "click until the ring fills," the novelty would probably wear off quickly.
