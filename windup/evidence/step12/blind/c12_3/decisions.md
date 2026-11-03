# Decisions — c12_3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (3.8 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (9.4 s)
  > The key turned a quarter and the counter went to 1. Winding gives "spirals." Let me click a bunch more to see how it scales.
  - ran `for i in $(seq 1 10); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0013.png` (16.8 s)
  - ran `node ./act.mjs click 450 600`
- **looked at** `seen/0014.png` (21.8 s)
  > Nothing happened. The ring by that doll is probably a progress meter on its wind-up key, and clicking the main key may fill it. Next I'll try clicking the doll's own key.
  - ran `node ./act.mjs click 422 605`
- **looked at** `seen/0015.png` (25.9 s)
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0041.png` (39.5 s)
  > I'm at 36 spirals, and a tutorial hand just popped up pointing at the key. The doll's ring now looks nearly full. The hand might be asking me to hold, so I'll try a long press.
  - ran `node ./act.mjs hold 640 380 3`
- **looked at** `seen/0042.png` (46.0 s)
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0043.png` (59.5 s)
  - ran `node ./act.mjs wait 6`
- **looked at** `seen/0044.png` (70.3 s)
  > Spirals are coming in passively at about 2 per second, so the awake doll is a generator. The target doll's ring isn't moving much, though. I'll hold the key again to push more winding into it.
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0045.png` (84.6 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0046.png` (99.5 s)
  > Both awake dolls are gathered around the target doll, winding it, and I'm at 192 spirals. I haven't found a way to spend spirals yet. The new sewing machine might be interactive, so I'll click it.
  - ran `node ./act.mjs click 410 380`
- **looked at** `seen/0047.png` (103.4 s)
  > Clicking the sewing machine did nothing visible. Next I'll try the little glowing wisp near the shelf.
  - ran `node ./act.mjs click 490 290`
- **looked at** `seen/0048.png` (107.0 s)
  > The wisp drifted over to the gear. It's a small creature with a face that wanders around and doesn't react to clicks. Holding the key still looks like the main action, so I'll hold it again.
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0049.png` (121.1 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0050.png` (136.3 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0051.png` (149.2 s)
  > Spirals are piling up at 390, but the fourth doll hasn't woken yet, so each wake probably costs more than the last. I'll do one more long wind to try to wake it before stopping.
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0053.png` (174.3 s)
  - ran `node ./act.mjs wait 8`
- **looked at** `seen/0054.png` (186.8 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 9 seconds, woke 4 of the 15 dolls, and ended with 435 spirals. **What I think the game is:** a calm incremental/idle game set in a moonlit tailor's workshop. You turn a big brass wind-up key to earn "spirals." A glowing thread links the key to one sleeping wind-up doll at a time. Once enough winding goes down the thread, that doll wakes up. Woken dolls earn spirals passively and walk over to help wind the next doll. Each wake also restores part of the room: a desk lamp, a red sewing machine, more gears around the key, and finally a finished tailcoat on the mannequin. **What I understood:** - Each click earns 1 spiral. Holding the key winds continuously and is much faster. - The spiral count drops when a doll wakes (36 → 33, 124 → 70, 215 → 83), so waking a doll seems to cost spirals automatically. - Income grows with each doll you wake, and each wake appears to cost more than the last. **What confused me:** - I never found a way to choose what to spend spirals on. Spending seemed automatic, so I'm not sure whether spirals have any other use. - Clicking the sleeping dolls, their keys, the sewing machine and the floating wisp did nothing I could see. - The grandfather clock moves forward as you progress, which may be a timer or a night-long goal, but I couldn't tell. - The hand pointing at the key appeared late (about 40 seconds in), after I'd already been clicking. **Would I keep playing?** For a while, yes. It's charming: watching the dolls wake up one by one and the workshop come back to life is a satisfying reward, and the art is lovely. But the only real input I found was "hold the key." Unless more choices open up later, such as upgrades or a reason to pick which doll to wake, I'd probably let it run in the background rather than play it actively.
