# Step 47 evidence — fresh-context blind AI players: novice, developing store, established factory

**The players are fresh-context AI agents (Claude, one new agent per run), not people.** Each one saw
only screenshots of a phone and had a finger: tap, hold, drag, path, wait. It also had a voice
(`note`). It got no URL, no code, no design, no docs, no expected milestones, no telemetry and no
test bridge. What they report is an AI reading screenshots. **It is not a fun rating, not a human
test and not proof that the game is fun.** The owner's rating is empty until the owner plays.

## How the runs were made

- **Harness:** `tools/blind/`, as in Steps 08–44, with the Step 47 additions in its README.
  - `session.mjs` opens the published build (`https://7bvcxz.github.io/gamo/popcorn-glory/#factory`)
    in a fresh browser profile: 400×860 touch, DPR 1.5, no test hooks, no dev mode, no time
    acceleration. The real clock starts at the player's first command.
  - The player's only tool is `play.mjs`, copied to a neutral folder (`scratchpad/phone/`) so the
    paths name neither the game nor the step.
- **Prompt:** the README's, word for word. The 20-minute runs say "twenty minutes" and add "6. What
  do you think the goal of the game is?". The prepared-save run adds one sentence: "This phone already
  has a game in progress that someone else built up over a while; you are picking it up from where
  they left it."
- **Separation:** the developer/evaluator (this session) started each session, launched the agent,
  did not coach it, and read the controller files only afterwards.
- **Blind condition: instruction plus a post-hoc audit, not a sandbox.** `audit.py` read every tool
  call in each agent's own transcript. **Flagged: 0 in all five runs** (`controller/audit.txt`;
  `controller/player_calls.jsonl` lists every call with its input).
  - The first audit of r2 flagged all 147 Bash calls. That player wrote
    `P=<phone folder>; node $P/play.mjs $P/p2 …`, and the audit did not expand a variable set in the
    same command.
  - The audit now does. Checked with a fake transcript: phone commands pass, while
    `cat $P/../../x.txt` and `ls $X` are still flagged.
- **The prepared save (r3):** `fixtures/factory44_0462.json` (`.about.json`). It was made by
  `tools/blind/prepare_factory.mjs` through the published 0.46.2's own dev bridge: a fresh factory,
  the 44-machine plan of perf46 (sign 8, packer 3), $3,000 left, then ten model minutes. The result was
  44 machines, $9,809, level 6, 918 sold. The session put it into the fresh profile before the page
  loaded (`start.json` → `prepared_save` with sha256 `0d23beba…`).
  - `smoke_save/` is the harness check (a 30 s run of mine, **not blind**): the save loads into a fresh
    profile with all 44 machines.

| run | build | scenario | length | agent | audit |
|---|---|---|---|---|---|
| `blind/r1_novice/` | 0.46.2 | a new game | 3 min | new | 36 Bash, 14 Read, flagged 0 |
| `blind/r2_store/` | 0.46.2 | a new game played on into a developing store | 20 min | new | 147 Bash, 145 Read, flagged 0 |
| `blind/r3_factory/` | 0.46.2 | the prepared 44-machine factory (disclosed) | 20 min | new | 251 Bash, 71 Read, flagged 0 |
| `blind/r4_novice_after/` | **0.47.0** | a new game | 3 min | **new** | 21 Bash, 14 Read, flagged 0 |
| `blind/r5_store_after/` | **0.47.0** | a new game played on into a developing store | 20 min | **new** | 258 Bash, 74 Read, flagged 0 |

Each run folder holds:

- `controller/`:
  - `player_report.md`: the agent's final report, unedited;
  - `actions.jsonl`: every command with its issue time, the time done, the screenshot and the held ms;
  - `state.jsonl.gz`: the game's state every 5 s, including the open panel (gzip);
  - `game_log.json`: the game's own timed log at the end, with every input, refusal, sale and purchase. Its snapshots during the run had no line it lacks, so they were not kept;
  - `start.json`, `summary.json`, `audit.txt`, `player_calls.jsonl`, `metrics47.json`;
  - `session_*.webm`: the screen recording, VP9 at 6 fps.
- `player/shots/`: every screenshot the player could see. They are WebP here to keep the repository
  small; the player saw PNGs of the same frames, so `actions.jsonl` still names them `.png`.

Each 20-minute agent spent about 20 real minutes playing. Its own thinking runs on the same clock, so
an AI's minute holds fewer actions than a person's.

## What the evaluator measured (`blind/metrics.md`, `tools/blind/evaluate47.mjs`)

Observations from the controller files; times are on the player's clock.

| metric | r1 novice 0.46.2 | r4 novice 0.47.0 | r2 store 0.46.2 | r5 store 0.47.0 | r3 factory 0.46.2 |
|---|---|---|---|---|---|
| first action | 17.2 s | 11.8 s | 14.6 s | 13.0 s | 17.6 s |
| first sale | 24.6 s | 19.2 s | 22.0 s | 20.3 s | 1.1 s (running factory) |
| first Perfect | 74.4 s | 44.3 s | 79.8 s | 84.9 s | 31.3 s |
| first purchase | 96.9 s | 53.6 s | 56.6 s | 96.5 s | 98.9 s |
| purchases | 2 | 2 | 12 | 11 | 7 (3 kettle, 4 machine upgrades) |
| first machine built | — | — | 18:11 | 11:25 | — (44 already) |
| paper opened / first contest entered | — / — | — / — | 1:41 / 3:27 | 4:47 / 5:27 | 2:07 / 2:47 |
| contests entered | 0 | 0 | 3 | 2 | 4 |
| recipe changed | never | never | never | never | never |
| hand presses / outcomes | 8: 5 perfect, 2 early, 1 near | 12: 6 perfect, 5 early, 1 burnt | 72: 40 perfect, 12 early, 1 near | 41: 33 perfect, 3 early, 1 near, 1 burnt | 34: 27 perfect, 3 early, 1 burnt |
| **refused presses (kettle full)** | 0 | 0 | **19** (+19 refused releases) | **3** (+4) | 3 (+4) |
| same spot tapped again | 0 | 2 | 7 | 1 | 0 |
| longest without a purchase | 97 s | 106 s | 215 s | 217 s | 408 s |
| seconds spent in `wait` | 2 | 2 | 143 | 44 | 31 |
| sold / revenue / running costs | 12 / 115 / 0 | 13 / 118 / 0 | 265 / 2,621 / 4 | 182 / 1,806 / 0 | 1,868 / 19,685 / 4,188 |
| bottleneck the model named (5-s samples) | production 19, demand 6 | production 19, demand 5 | demand 146, packaging 33 | demand 107, production 57, packaging 36 | demand 187, packaging 37 |
| page errors | 0 | 0 | 0 | 0 | 0 |

## The friction that mattered most, and the fix (0.47.0, D-70)

**Before (0.46.2): the player's main verb failed with no visible reason.**

- r2, 20 minutes: 19 of 72 presses were refused because the glass still held a lot (the bin was
  full), and every one of those also counted a refused release.
  - In its own words: "About half my holds were silently swallowed, with no message saying 'full'".
  - In the streak challenge "I spent most of the time waiting for the machine to empty, not timing".
- r3, the 44-machine factory: "Presses being ignored right after a batch, with nothing on screen to
  say the kettle wasn't ready".
- Why:
  - The ring looked ready.
  - Step 44's cue (amber arrows up the lift, the bin ringed) lasted 1.6 s from the press. A
    1.8 s hold looked at after the lift never showed it.
  - When the paper was open it covered the bin.
  - `blind/r2_store/player/shots/034` is that moment: a full-colour ring and no cue.

**The fix:**

- While a lot waits in the glass, or the kettle cools, the ring is dimmed. Only its own layer is
  tinted, so no polygon is redrawn (R-01).
- When the kettle can take a press again, the ring lights up with a white flash.
- A refused hold's cue stays while the finger is down and for 2 s after it lifts.
- Tests:
  - `tests/integration/test_ready47.gd`, which fails on the old timing and the undimmed ring;
  - `tests/e2e/specs/ready47.spec.mjs` on three screens. The ring's pixels along its circle drop
    from a saturation of 0.48 when ready to 0.38 while waiting, and the cue is in a still 0.4 s after
    a 1.8 s hold.
  - Stills are in `ready/`: `ready_*`, `waiting_*`, `refused_after_lift_*`.

**After (0.47.0), each run a new agent that never saw the game:**

- **r5, the same 20-minute store scenario:**
  - Presses refused for a full kettle went from 19 to **3**. All refusals went from 38 to 7, and
    repeated taps on the same spot from 7 to 1.
  - The player named the state at once: "The ring went grey and tapping the machine only flashed red
    arrows. When I closed the newspaper I could see the packing hopper was full…".
- **r4, the 3-minute novice:**
  - It never met a full kettle: no press was refused. Its one refusal was a release after a burnt batch.
  - The other novice milestones fall in the same range as r1.
- **What did not change:**
  - r5: "After about 10 minutes, much of the time went to waiting for coins while the machine sat
    grey and blocked. The cooking I enjoyed most kept getting switched off."
  - The fix shows *why* the hand is stopped. It does not stop the packing floor from blocking the
    hand in a developing store. That is a balance question, and Step 48 gets it.
  - The paper still covers the full rooms (r5).
- **Uncertainty:**
  - One agent per side and per scenario.
  - r5 pressed less often than r2 (41 against 72).
  - Agents differ from run to run: r4's earlier first Perfect is not evidence for the fix.

## The four Fun First dimensions — AI proxy judgement (1–5), not a human score

The rater is this session, reading the stills, notes, reports and logs. The owner's column stays
empty until the owner plays.

| run | 10 s: knows what to do | 30 s: a meaningful reward | 60 s: visible growth | 180 s: wants to know what's next | owner |
|---|---|---|---|---|---|
| r1 novice 0.46.2 | 4: guessed "tap the machine, the ring is a timing gauge" before touching (first touch 17 s: an AI thinks slowly) | 4: first coins at 24.6 s | 3: first upgrade at 97 s | 4: "yes, for a while"; the locked slots and kitchen promise more | — |
| r4 novice 0.47.0 | 4: the same guess | 4: first sale at 19 s | 4: upgrade at 54 s, the machine grew an awning | 4: "yes, for a while"; wanted more customers | — |
| r2 store 0.46.2 | 4 | 4: first sale at 22 s | 4: upgrade at 57 s, "fancier roof and confetti" | 4: contests, the red outline; "probably yes, for a while"; held back by swallowed presses | — |
| r5 store 0.47.0 | 4 | 4: first sale at 20 s | 3: first upgrade at 97 s | 4: "probably for a while longer"; the gold medal was "the high point"; held back by waiting while blocked | — |
| r3 factory 0.46.2 | 3: "tapping the cart did little"; it found the ring's colours only at 17:49 | 4: first Perfect at 31 s, sales everywhere | 4: two cart upgrades by 1:52 | 3: understood the bottleneck loop only at 18:33; "rewards tiny next to an income of ~1,000 a minute"; "drift off within a session or two" | — |

**What an AI cannot judge:** whether the sounds and the hold feel good in a hand (it hears nothing and
holds by a number of seconds), whether a person wants to come back tomorrow, and the haptics.

## Other frictions the players named (not fixed in this step; for Step 48)

| friction | runs |
|---|---|
| The developing store's packing floor often stops the hand: waiting with a grey ring | r5 (and r2 before the fix) |
| The paper covers the floors that are full | r2, r5 |
| Card numbers with unlabelled icons (★ 600 > 650, a looping arrow 350 > 350) | r1, r2, r3, r4 |
| The gadgets (fan, lever, mini machine) and their numbers | r2, r3, r5 |
| The star button means "maxed", found late | r3 |
| The red frame and red minus badges mean "bottleneck", understood late | r3 (18:33), r4 |
| The sparkle (motion) button: no visible change | r1, r2, r3, r5 |
| Challenges that win themselves (serving, packing), and prizes tiny next to a factory's income | r3 |
| The challenge list's rows shift, so the player starts the wrong one | r3 |
| The 8–9 gold dots reset with no visible payoff (the burst is not read as one) | r4 |
| Tap and hold both make popcorn, so the hold is found late | r1, r4 |
| No player changed a recipe in any run | all |

## Owner

The live build to play is **https://7bvcxz.github.io/gamo/popcorn-glory/#factory** (0.47.0). No owner
rating has been given. None is invented here.
