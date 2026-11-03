# Decisions — b3

In order. "looked at" = an image the player opened (in `seen/`); its time is when that screenshot was taken (seconds since the game started, the only clock the player had).

  - ran `node ./act.mjs look`
- **looked at** `seen/0001.png` (3.9 s)
  - ran `node ./act.mjs click 640 380`
- **looked at** `seen/0002.png` (11.6 s)
  > The score went up to 1, and a small button is flying along the aim arc. It looks like the gear shoots buttons. Next I'll click on one of the bottom shapes to see whether the aim follows my click.
  - ran `node ./act.mjs click 870 620; sleep 1; node ./act.mjs look`
- **looked at** `seen/0004.png` (18.5 s)
  - ran `for i in 1 2 3 4 5; do node ./act.mjs click 640 380; done`
- **looked at** `seen/0009.png` (28.1 s)
  - ran `for i in $(seq 1 15); do node ./act.mjs click 640 380 >/dev/null; done; node ./act.mjs look`
- **looked at** `seen/0025.png` (52.9 s)
  > I'm at 21, and a tutorial hand has appeared pointing at the gear. It may be hinting that I should hold rather than tap. The ring is about half full. I'll try holding the gear down.
  - ran `node ./act.mjs hold 640 380 4`
- **looked at** `seen/0026.png` (62.6 s)
  > Holding works: it added 12 in 4 seconds, which is faster than tapping. The ring is about three-quarters full. Now I'll try clicking the glowing face-button, which might be a bonus pickup.
  - ran `node ./act.mjs click 489 278`
- **looked at** `seen/0027.png` (67.4 s)
  > Clicking the face-button did nothing. I'll go back to holding the gear to fill the ring and see what unlocks.
  - ran `node ./act.mjs hold 640 380 6`
- **looked at** `seen/0028.png` (77.6 s)
  - ran `node ./act.mjs click 425 590`
- **looked at** `seen/0029.png` (83.2 s)
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0030.png` (96.1 s)
  > The counter jumped to 77, so income is much faster now. The doll has reached the right-hand ring, which is nearly full. I'll keep holding.
  - ran `node ./act.mjs hold 640 380 6`
- **looked at** `seen/0031.png` (105.8 s)
  > The counter is at 129 and the ring looks full, but nothing has unlocked yet. Maybe the ring itself needs a click.
  - ran `node ./act.mjs click 875 610`
- **looked at** `seen/0032.png` (109.5 s)
  > Still nothing. Looking closer, the ring has a small gap at the top, so it isn't quite full. The next unlock probably just costs more. I'll keep holding.
  - ran `node ./act.mjs hold 640 380 8`
- **looked at** `seen/0033.png` (121.8 s)
  - ran `node ./act.mjs hold 640 380 9`
- **looked at** `seen/0034.png` (136.3 s)
  > Both dolls have gathered at the left-hand ring, presumably helping wind the doll under that sheet. The counter is at 156 and the ring is close to full. I'll keep going.
  - ran `node ./act.mjs hold 640 380 9`
- **looked at** `seen/0035.png` (149.4 s)
  > Now at 263, with the ring essentially closed. I'll hold a bit longer to see the third doll wake.
  - ran `node ./act.mjs hold 640 380 9`
- **looked at** `seen/0036.png` (162.2 s)
  > A third doll with a flower in her hair is awake, and a fourth gear has appeared. All three dolls are heading to the next sheet on the right. One more winding pass to get past three minutes.
  - ran `node ./act.mjs hold 640 380 10`
- **looked at** `seen/0037.png` (177.4 s)
  > About three minutes have passed. The three dolls are working on the fourth sheet and its ring is about half full. Ending here.
  - ran `node ./act.mjs end`
  > I played for about three minutes. I'd keep playing for a while longer, though I doubt it would hold me for very long. **What I think the game is:** a cozy idle/incremental game set in a moonlit tailor's workshop. You turn a big brass gear by clicking it, or faster by holding it down, to earn "spirals" of winding energy. The pale shapes on the floor are sheets with sleeping clockwork dolls under them. A thread runs from the gear to a ring over one of the sheets, and when the ring fills, the spirals are spent, that doll wakes up and the workshop gets a new item. **What I understood:** - Clicking adds 1 spiral; holding adds about 3 per second at first. - My first doll (top hat) woke at about 33 spirals, and a desk lamp came on. After that, spirals also came in on their own. - Each new doll added a gear to the big one and went off to help wind the next sleeping doll. A red sewing machine appeared along the way, so income kept speeding up. - By the end I had 3 dolls awake, 4 small gears, a lamp and the sewing machine, and the three dolls were working on a fourth sheet, its ring about half full. **What confused me:** - A tutorial hand appeared after I'd already worked out the clicking. Seeing it, I wondered whether there was a hidden action I was missing. - Clicking the glowing face-button near the shelf, the floor sheets or a full-looking ring did nothing. I couldn't tell whether the button has a purpose. - The rings don't show how much they cost. I thought the second ring was full and clicked it, but it still had a small gap. - I never tried the two icons at the top left or the restart button at the top right. **Would I keep playing?** For a little while. Waking each doll and watching the room fill up and glow brighter is charming, and it shows progress well. But the only real input is holding down one gear, and I didn't see any choices to make. I'd keep going to see what the mannequin, the grandfather clock and the floating button do, but unless real decisions show up, I'd expect to lose interest once those are revealed.
