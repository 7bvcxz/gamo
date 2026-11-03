# Decisions — a3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (4.6 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (11.2 s)
  > Clicking the key turned it and gave 1 spiral — looks like an idle/clicker game. A thread seems to run from the key to one doll. Let me wind it a bunch of times.
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0018.png` (23.5 s)
  > 16 spirals now, one per click. There's no shop yet, but the doll at the center-left (~425,605) has a glowing ring around its key, like it's being charged. I'll click that doll.
  - ran `node ./act.mjs click 425 605`
- **looked at** `seen/0019.png` (27.8 s)
  - ran `node ./act.mjs click 490 278`
- **looked at** `seen/0020.png` (32.2 s)
  > A tutorial hand popped up pointing back at the key, so the game wants me to keep winding. I'll keep going and see whether the doll's ring fills up.
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0046.png` (54.4 s)
  - ran `node ./act.mjs hold 640 380 4`
- **looked at** `seen/0047.png` (63.7 s)
  - ran `node ./act.mjs wait 5`
- **looked at** `seen/0048.png` (74.1 s)
  - ran `for i in $(seq 1 25); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0074.png` (101.5 s)
  > 99 spirals, and the ring on the second target doll is about half full. Last time the doll woke during a hold, so I'll hold again to see if holding is what spends spirals to finish the wake-up.
  - ran `node ./act.mjs hold 640 380 4`
- **looked at** `seen/0075.png` (109.8 s)
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0076.png` (125.0 s)
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0078.png` (152.7 s)
  - ran `node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10; node ./act.mjs hold 640 380 10`
- **looked at** `seen/0081.png` (193.1 s)
  > A third doll woke and a fourth gear joined the machine. The three awake dolls have walked to the far right to wind the next sleeper together. I'm past three minutes, so I'll stop here.
  - ran `node ./act.mjs end`
  > I played for about 3¼ minutes and woke 3 of the roughly 15 dolls. **What I think the game is:** a calm, moody idle/clicker set in a toymaker's workshop at night. You turn a large brass wind-up key. Each turn gives you "spirals," the currency shown at the top. A thread links the key to one sleeping doll, and your winding slowly fills a ring around that doll's key. When the ring is full, the doll wakes up, a fixed amount of spirals is spent, and a new small gear attaches to the machine. Each doll that wakes adds passive income and then walks over to help wind the next sleeper, so progress speeds up the more dolls you wake. The workshop also changes as you go: a desk lamp lit up, and a covered shape became a glowing red sewing machine. **What I understood:** clicking or holding the key earns spirals. Holding seems to work as a steady stream of clicks. Dolls wake on their own once their ring fills, and the game picks which doll comes next. Spirals kept going up between wake-ups even when I wasn't touching anything. **What confused me:** - The tutorial hand stayed pointed at the key even while I was clicking it, and it never told me whether holding or spinning was better. - At first I couldn't tell how waking worked. My spirals dropped suddenly from 41 to 4, and only later did I figure out the doll had woken and the cost was taken automatically. - I couldn't work out what the glowing face-orb near the shelf is, what the restart/settings buttons do, or whether the moving grandfather clock is a timer, like night ending at dawn. - I didn't see a shop or any upgrade choices. Your only real choice seems to be how hard you wind. **Would I keep playing?** For a bit longer, yes. The art is charming, and seeing the room come to life and the dolls gather to help each other is satisfying. I'd want to know what happens when every doll is awake or when the clock runs out. But there are no decisions to make, so I'd likely lose interest unless more mechanics show up later.
