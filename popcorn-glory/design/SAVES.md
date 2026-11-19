# Saves (Step 45)

What this game keeps, where, and what happens when a save is old, broken or refused.
The code is `app/save_store.gd` (where), `app/save_doc.gd` (the envelope), `app/main.gd`
(when, and the fallbacks) and each rules' `to_save` / `from_save` (what). The recovery page
is `web/saves.html`. The decision is D-67.

## Which save is whose

| key (localStorage; natively `user://popcorn_glory_<key>.json`) | who | since |
|---|---|---|
| `popcorn-glory.stand.v1` | the Popcorn Stand (`#stand`) | 0.12.0 |
| `popcorn-glory.factory.v1` | the three-floor factory (`#factory`) | 0.22.0 |
| `<key>.bak` | the last good save (see below) | 0.45.0 |
| `<key>.rejected` | a save this build refused, set aside | 0.45.0 |
| `popcorn-glory.sound`, `.motion` | settings | 0.43 / 0.44 |
| `popcorn-glory.scorecard.v1` | the owner's scorecard page | 0.09 |

- **The factory is a separate named save.** It does not migrate the stand's progress and
  offers no import from it. The two economies share no unit (a stand level is not a factory
  machine). The stand stays playable with its own save, and the factory never reads or
  writes `stand.v1` (`integration/test_save45`, `e2e/save45`).
- **A, B and C (`#click`, `#perfect`, `#explosion`) are disposable sessions.** They save
  nothing. Neither does a seeded run (`?seed=`), a scene, or a 3-minute trial (`?trial=1`).

## The envelope

One JSON object whose **last** key is `rules`:

```
{"active_ms":…,"exp":"factory","game":"popcorn-glory","saved_unix":…,"schema":1,"sum":"<sha256>","version":"0.45.0","rules":{…}}
```

- `sum` is the sha256 of the exact characters after `,"rules":`. A truncated or edited save
  is caught before anything is applied (`checksum`, `not_json`).
- `saved_unix` is the wall clock of the last active play. It is shown on the saves page and
  never used to advance the game.
- **The schema stays 1 and every new key is additive.** A 0.12–0.44 build reads a 0.45 save:
  checked by running the old builds' own load path in detached worktrees
  (`evidence/step45/fixtures/old_builds_read_045.log`). This matters because the Pages CDN
  can hand a returning player an older build for ten minutes after a deploy, and every build
  before 0.45 starts a fresh run over a save it refuses.
- A save without `sum` (every build before 0.45) is read as before.

## Writing

- The game saves every 5 s of active play, after a purchase or a recipe, when the tab
  hides, and when the player leaves.
- On the web, `localStorage.setItem` is all-or-nothing per key. Natively, the text goes to
  `<key>.tmp`, is read back, then renamed over the save.
- **A write is read back.** If it does not read back whole (a full quota, a blocked
  storage), the previous save stays, `save_failed` is logged, and the next tick tries again.
- **`.bak`**:
  - On load, the save the player came back to is copied to `.bak`.
  - Then, once a minute of play, the save from a minute ago is copied to `.bak`.
  - On a restart (two taps), the old run goes to `.bak` and stays there for the new run's
    first 10 minutes of play, so the saves page can undo a restart.

## Loading

1. Read `<key>`. Empty: a fresh run (`from: none`).
2. Decode (`PopSaveDoc.decode`: game, experiment, schema, checksum, clock), then the rules'
   `from_save`. That checks every field, that every portion made is somewhere
   (conservation), and, for the factory, the finite limits:
   - ints ≤ 2^53;
   - every goods list under a cap;
   - machines ≤ the places that exist;
   - each machine a known type on its own floor, in a place that exists;
   - no two machines in one place, no id twice, tier 0–9.
   A refusal applies nothing.
3. Refused: the text is **set aside** in `<key>.rejected` (never written over), the reason is
   logged (`save_rejected`), and `<key>.bak` is tried the same way (`from: backup`).
4. Both refused: a fresh run (`from: fresh`). The set-aside save is still there, and the frame
   shows the **set-aside icon** (a box pushed off its dashed place, an arrow back) that opens
   `saves.html`. A fresh start after a refusal is never silent.

## Away, hidden, closed

**The factory pauses; there is no offline progress.** Game time is active play time:

- the clock stops while the tab is hidden (Step 22);
- a reload continues from the saved `active_ms`, not from the wall clock;
- upkeep, sales, arrivals, news and contests all run on that clock.

So there is no passive money while away, no time-warped upkeep for forty machines, and no
contest that ends while the player is gone. `e2e/factory33` (a hidden tab adds < 1.5 s) and
`e2e/save45` (a reload keeps the clock and the money) check it.

A killed browser (every process SIGKILLed: no unload, no last save) loses the play since the
last save that reached the disk. Measured: 7.2 s, from clock 38,778 at the kill to 31,574 in
the surviving save, while the game saves every 5 s. Chromium commits localStorage to disk a
little after `setItem`, so the 36.5 s save was still in memory and was lost. Nothing is sold
twice, because the save is a whole snapshot taken at one moment (sold 14 at the kill, 12 in
the save and in the restored game). The test is `e2e/save45`: a throwaway persistent
Chromium, killed, then relaunched on the same profile. CDP `Page.crash` was tried first; it
takes the whole Playwright context with it, so it measured the harness.

## Recovery: web/saves.html

A plain page beside the game (text is allowed here: it is the fallback, not the game). It
reads and writes only `popcorn-glory.*`.

- For each of the stand and the factory: the save, the backup and the set-aside save, with
  "intact" or the reason, size, version, date, minutes played, machines, level and money.
  The checksum is verified in the page.
- **Restore from this** (two presses): the chosen save becomes the save, and the one it
  replaces becomes the backup.
- **Erase** (two presses within 3 s): the save, the backup and the set-aside save of that
  one, and it cannot be undone.
- **Download all / import from a file.** Import checks the envelope and the checksum, keeps
  the current save as the backup, and refuses anything else.
- The game writes every 5 s. If the page sees a `storage` event, it warns that the game is
  open in another tab.

## Migration fixtures

`tests/fixtures/saves/` (with a `.gdignore`; pinned by `SHA256SUMS`) holds saves written by
the old builds themselves. `fixture_gen.gd.txt` was run in detached worktrees of 0.12.2,
0.22.0 and 0.43.0:

- `stand_0.12.2.json`: level 9, 6 minutes;
- `stand_0.43.0.json`;
- `factory_0.22.0.json`: the first factory save;
- `factory_0.43.0_forty.json`: 44 machines, 10 minutes.

`unit/test_save45` restores each, keeps its numbers and plays on with every portion
conserved. `e2e/save45` opens the 0.12.2 stand and the 0.43.0 factory in the browser.
