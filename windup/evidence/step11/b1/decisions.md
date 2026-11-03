# Decisions — b1

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (4.0 s)
  - ran `node ./act.mjs click 578 670`
- **looked at** `seen/0002.png` (10.7 s)
  > Nothing happened. The floating glowing orb with a face near (490,290) looks like a character, or maybe a hint. I'll click the gear's center instead to see if the device does something.
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0003.png` (15.8 s)
  - ran `for i in 1 2 3 4 5; do node ./act.mjs click 640 380; done`
- **looked at** `seen/0008.png` (22.6 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0024.png` (35.8 s)
  > The counter is at 21, one per click, and the ring on the shell is about half full. The shell might be growing into something. I'll click directly on the ring to see if it responds.
  - ran `node ./act.mjs click 422 605`
- **looked at** `seen/0025.png` (39.5 s)
  > Clicking the ring did nothing, and a tutorial hand appeared pointing back at the gear. The game wants me to keep cranking it, so I'll do another long run of clicks.
  - ran `for i in $(seq 1 20); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0046.png` (53.9 s)
  > The ring is now a full circle at 41 spirals. One more click on the gear should show whether something triggers.
  - ran `node ./act.mjs click 640 380; node ./act.mjs wait 1`
- **looked at** `seen/0048.png` (58.9 s)
  - ran `node ./act.mjs click 430 630`
- **looked at** `seen/0049.png` (63.5 s)
  - ran `node ./act.mjs click 92 40`
- **looked at** `seen/0050.png` (68.0 s)
  > That was just a toggle, probably for particles or effects, since it's now crossed out. I'll switch it back on, then click the floating face-orb.
  - ran `node ./act.mjs click 92 40 >/dev/null; node ./act.mjs click 489 280`
- **looked at** `seen/0052.png` (71.9 s)
  > The orb didn't respond, and the ring seems to be cycling rather than staying full. The brass lever sticking off the gear might be a crank, so I'll try dragging it.
  - ran `node ./act.mjs drag 712 298 760 420 0.6`
- **looked at** `seen/0053.png` (78.7 s)
  > Dragging the crank jumped the counter from 42 to 51, nine spirals in one motion, and the tutorial hand disappeared. Cranking clearly beats tapping. I'll do several longer drags around the gear.
  - ran `for i in 1 2 3 4; do node ./act.mjs drag 712 298 520 470 0.8 >/dev/null; node ./act.mjs drag 520 470 760 300 0.8 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0062.png` (109.4 s)
  - ran `for i in 1 2 3 4; do node ./act.mjs drag 712 298 520 470 0.8 >/dev/null; node ./act.mjs drag 520 470 760 300 0.8 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0071.png` (143.8 s)
  - ran `for i in 1 2 3 4 5; do node ./act.mjs drag 712 298 520 470 0.8 >/dev/null; node ./act.mjs drag 520 470 760 300 0.8 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0082.png` (174.0 s)
  - ran `node ./act.mjs wait 8`
- **looked at** `seen/0083.png` (186.6 s)
  - ran `node ./act.mjs end`
  > I played for about 3 minutes 10 seconds. It's a calm clicker/idle game set in a moonlit tailor's workshop. **What I understood:** - **Earning:** Turning the big brass gear in the center earns gold spirals, the counter at the top. A single click gives 1 spiral. Dragging across it like a crank earns much more; my first drag gave 9 in one motion. Later, income sped up a lot (from 77 to 239 over five cranking drags), which suggests the new parts add to production or earn on their own. I never confirmed passive income, though, because spending happened during my one wait. - **Spending:** I never bought anything myself. Spirals flow along a glowing arc to the next target, and unlocks happen automatically when enough has built up. That arc is what I first mistook for an aiming line. - **Unlocks:** In order, I saw two extra small gears, a desk lamp, a red sewing machine, and three wind-up dolls in costume: one in a top hat, one in a blue cap, and a girl with a flower. - **The shells:** The grey shapes on the floor seem to be dust sheets over sleeping dolls. The goal looks like waking every doll and bringing the whole workshop back to life. The camera even zoomed in a little as things grew. **What confused me:** - **Hard to start:** I couldn't tell what to do at first. My first click was on a floor shell and nothing happened, and the progress ring on a shell looked like something to click. - **Some controls unclear:** The glowing face-orb did nothing when clicked. The top-left icon only toggled effects. - **Spending is invisible:** The counter suddenly dropped (91 → 77, then 239 → 0) with no prices or explanation shown. I worked out the cost of each unlock only from the drops. **Would I keep playing?** Probably yes, for a while. The art and mood are lovely. Watching the dark room light up and the dolls climb out from under their sheets is a satisfying reward, and I want to know what the clock, the mannequin and the rest of the dolls do. The downside is that there are almost no decisions: so far it's just cranking and watching. Unless upgrades or choices show up later, I'd expect the novelty to fade within about 10–15 minutes.
