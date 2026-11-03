# Decisions — session3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (8.1 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (15.3 s)
  > Clicking the gear turned the butterfly key and gave 1 spiral. I'll wind it several more times.
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (38.8 s)
  - ran `node ./act.mjs click 445 605`
- **looked at** `seen/0019.png` (44.5 s)
  > Clicking the doll didn't spend anything. What did change is a thin gold arc growing around the gear, like a progress ring. I'll wait to see if it fills up by itself.
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0020.png` (54.4 s)
  > The ring around the gear filled all the way to a full circle. It might be a charged bonus, so I'll click the gear now.
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0021.png` (57.9 s)
  > It only gave +1, and the ring dropped back to about half. So far the ring has grown while I waited and shrunk when I clicked. Next I'll try clicking the glowing wisp.
  - ran `node ./act.mjs click 640 328`
- **looked at** `seen/0022.png` (63.4 s)
  - ran `node ./act.mjs hold 640 400 3`
- **looked at** `seen/0023.png` (71.9 s)
  - ran `node ./act.mjs hold 640 400 8`
- **looked at** `seen/0024.png` (85.3 s)
  - ran `node ./act.mjs hold 640 400 10`
- **looked at** `seen/0025.png` (101.1 s)
  - ran `node ./act.mjs hold 640 400 10`
- **looked at** `seen/0026.png` (116.2 s)
  > 139 spirals. A spark is travelling down the thread to the next doll, and that doll's ring is almost full. I'll keep holding.
  - ran `node ./act.mjs hold 640 400 10`
- **looked at** `seen/0027.png` (130.5 s)
  - ran `node ./act.mjs hold 640 400 10`
- **looked at** `seen/0028.png` (145.4 s)
  > Up to 173, about 10 spirals per second. The sewing machine looks interactive (it has a wheel), so I'll click it to see whether it's an upgrade or a second source.
  - ran `node ./act.mjs click 410 385`
- **looked at** `seen/0029.png` (149.4 s)
  - ran `node ./act.mjs hold 640 400 10; node ./act.mjs hold 640 400 10; node ./act.mjs hold 640 400 10`
- **looked at** `seen/0032.png` (187.2 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes and 11 seconds. **What I think the game is:** A cozy idle/clicker game set in a toymaker's workshop at night. You wind a big brass gear with a butterfly key to earn "spirals." The spirals go to waking up a row of sleeping clockwork dolls. Each doll that wakes adds a small gear to the machine, lights up more of the room (a desk lamp, then a red sewing machine) and joins in winding the next sleeping doll. Each doll speeds things up. **What I understood:** - A single click gives +1 spiral. Holding the gear down winds it continuously and is much faster. - A thread runs from the gear to the doll currently being woken, with a small ring on that doll that fills up. When it's full, the spirals are spent (the counter dropped from about 29 to 0 the first time) and the doll stands up. - Awake dolls create passive income and help wind the others. By the end I had 3 dolls awake, 4 gears, and the counter was rising on its own. **What confused me:** - The large ring around the gear filled up while I waited and shrank when I clicked. It might be a charge or tension meter, but clicking it when full gave no visible bonus. - I couldn't tell when spirals were spent. The counter rose and dropped in ways I couldn't fully track. - The sewing machine, the floating wisp and the moving grandfather clock all seemed meaningful, but clicking them did nothing I could see. The clock might be counting down to dawn. **Would I keep playing?** Yes, for a while. The art is charming, and the room visibly coming to life as each doll wakes is a satisfying reward. I'd want to see whether waking every doll leads to an ending at dawn. The main risk is that it comes down to just holding one spot, unless the unclear elements turn out to be upgrades or choices.
