# Popcorn Stand pacing -- BEFORE Step 11 (0.10.1 prices; AUTOMATED, real rules, seed 7, 20 minutes)

Scripted behaviours; what the numbers do, not whether it is fun.

| player | Lv3 shake | Lv4 automation | Lv5 recipes | motor | helper | Lv @3 / 5 / 10 / 15 / 20 min | ladder @10 / 20 min | all bought | longest no-buy after 3:00 | helper share of 20 min | invariants |
|---|---|---|---|---|---|---|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 0:24 | 0:33 | 0:50 | 0:39 | 1:09 | 8 / 10 / 13 / 14 / 14 | 7 / 7 | 11:29 | 102s | 31% | ok |
| skilled, butter | 0:24 | 0:33 | 0:50 | 0:39 | 1:20 | 8 / 10 / 12 / 13 / 14 | 6 / 7 | 15:11 | 131s | 39% | ok |
| skilled, cheese | 0:24 | 0:33 | 0:50 | 0:39 | 1:19 | 8 / 9 / 11 / 13 / 14 | 6 / 7 | 15:37 | 133s | 40% | ok |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 0:43 | 0:57 | 1:36 | 1:21 | 2:35 | 6 / 8 / 10 / 11 / 13 | 4 / 6 | no | 195s | 50% | ok |
| casual, caramel | 0:43 | 0:57 | 1:36 | 1:21 | 2:27 | 7 / 8 / 10 / 12 / 13 | 5 / 7 | no | 144s | 45% | ok |
| casual, cheese | 0:43 | 0:57 | 1:36 | 1:21 | 2:29 | 6 / 8 / 10 / 11 / 13 | 5 / 7 | no | 150s | 45% | ok |
| novice (wild timing, never shakes, slow, butter) | 0:48 | 1:03 | 1:41 | 1:22 | 2:39 | 6 / 8 / 10 / 12 / 13 | 5 / 7 | no | 157s | 45% | ok |
| novice, caramel | 0:48 | 1:03 | 1:41 | 1:22 | 2:29 | 6 / 8 / 10 / 12 / 13 | 5 / 7 | no | 144s | 44% | ok |
| novice, cheese | 0:48 | 1:03 | 1:41 | 1:22 | 2:27 | 6 / 8 / 11 / 12 / 14 | 5 / 7 | 19:18 | 148s | 42% | ok |
| never shakes (casual, butter) | 0:43 | 0:57 | 1:36 | 1:13 | 2:35 | 6 / 8 / 10 / 11 / 13 | 4 / 6 | no | 195s | 50% | ok |
| low interaction (casual until the helper, then only buys) | 0:43 | 0:57 | 1:36 | 1:21 | 2:35 | 6 / 7 / 7 / 8 / 9 | 3 / 4 | no | 217s | 94% | ok |
| never automates (skilled, caramel) | 0:24 | 0:33 | 0:43 | – | – | 9 / 11 / 13 / 14 / 14 | 0 / 0 | no | 570s | 0% | ok |
| automation first (casual, buys the ladder before the machine) | 0:50 | 1:14 | 2:04 | 1:38 | 2:57 | 6 / 7 / 10 / 11 / 13 | 4 / 6 | no | 187s | 49% | ok |
| delayed automation (skilled, caramel, no automation before Lv8) | 0:24 | 0:33 | 0:43 | 1:38 | 1:40 | 9 / 11 / 13 / 14 / 14 | 7 / 7 | 11:18 | 101s | 31% | ok |
| diversified recipes (casual, changes recipe every 2 min) | 0:43 | 0:57 | 1:36 | 1:21 | 2:27 | 7 / 8 / 10 / 12 / 13 | 5 / 7 | no | 159s | 48% | ok |
| idle break (casual, butter, no input 5:00-8:00) | 0:43 | 0:57 | 1:36 | 1:21 | 2:35 | 6 / 8 / 9 / 11 / 12 | 4 / 6 | no | 199s | 48% | ok |
| slow novice (3-6 s between presses, wild timing, cheese) | 1:34 | 2:15 | 3:40 | 3:02 | 5:03 | 4 / 6 / 8 / 10 / 11 | 4 / 6 | no | 138s | 49% | ok |
| stops at 3:00 without the helper (casual) | 0:43 | 0:57 | 1:25 | – | – | 7 / 7 / 7 / 7 / 7 | 0 / 0 | no | 1020s | 0% | ok |

## Automation break-even (helper rungs, at the level the skilled player buys them)

| rung | cost | cycle | share | pays per batch then | break-even |
|---|---|---|---|---|---|
| 1 motor | 260 | – | – | every batch x1.3 | – |
| 2 helper | 1200 | 3.0s | 0.60 | 50 (Lv6) | 72s |
| 3 helper | 3600 | 2.7s | 0.70 | 93 (Lv7) | 104s |
| 4 helper | 12000 | 2.4s | 0.85 | 182 (Lv8) | 158s |
| 5 helper | 35000 | 2.1s | 1.00 | 550 (Lv10) | 133s |
| 6 helper | 110000 | 1.8s | 1.15 | 1011 (Lv11) | 195s |
| 7 helper | 320000 | 1.5s | 1.30 | 2912 (Lv13) | 164s |

## Assumptions (the player models -- not measurements)

- Every player is a script on the real rules (variants/stand/stand_rules.gd, data/economy.json), seed 7, 10 ms steps, 20 minutes of active time.
- skilled: releases at the gold's middle +- N(0, 70 ms); 300 ms between presses; buys the moment it can.
- casual: 45% at the middle +- 160 ms, 25% 100-500 ms early, 20% 80-400 ms late, 10% held on to the burn; 0.5-1.5 s between presses; waits 1.5-5 s before buying.
- novice: 75% at the middle +- 300 ms, 10% burnt, 15% far too early; otherwise as casual.
- shake: the share of heats with three swings (until the motor makes it automatic).
- buying: the cheaper of the two cards when affordable ('cheapest'/'slow'), the machine only ('main_only'), the ladder whenever affordable ('auto_first'), or no automation before a level ('auto_from').
- Not modelled: a human's attention, learning, fatigue, curiosity; reading the screen; tab switches.

## Throughput and the hand (outcomes)

| player | batches by the hand | hand heating share | earned at 5 / 10 / 20 min | helper share at 10 / 20 min |
|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 544 | 81% | 162k / 1.14M / 6.47M | 24% / 31% |
| skilled, butter | 545 | 81% | 76k / 477k / 3.77M | 29% / 39% |
| skilled, cheese | 393 | 58% | 71k / 437k / 3.53M | 29% / 40% |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 422 | 64% | 16k / 103k / 784k | 36% / 50% |
| casual, caramel | 429 | 63% | 25k / 168k / 1.48M | 32% / 45% |
| casual, cheese | 382 | 58% | 21k / 137k / 1.18M | 35% / 45% |
| novice (wild timing, never shakes, slow, butter) | 446 | 62% | 21k / 144k / 1.22M | 33% / 45% |
| novice, caramel | 450 | 62% | 24k / 177k / 1.57M | 31% / 44% |
| novice, cheese | 393 | 57% | 26k / 213k / 1.93M | 28% / 42% |
| never shakes (casual, butter) | 423 | 64% | 16k / 104k / 790k | 36% / 50% |
| low interaction (casual until the helper, then only buys) | 57 | 7% | 5k / 15k / 65k | 76% / 94% |
| never automates (skilled, caramel) | 545 | 81% | 189k / 1.06M / 4.79M | 0% / 0% |
| automation first (casual, buys the ladder before the machine) | 420 | 64% | 13k / 93k / 747k | 36% / 49% |
| delayed automation (skilled, caramel, no automation before Lv8) | 546 | 81% | 178k / 1.20M / 6.60M | 25% / 31% |
| diversified recipes (casual, changes recipe every 2 min) | 410 | 62% | 23k / 149k / 1.13M | 33% / 48% |
| idle break (casual, butter, no input 5:00-8:00) | 359 | 54% | 16k / 56k / 583k | 44% / 48% |
| slow novice (3-6 s between presses, wild timing, cheese) | 194 | 27% | 3k / 36k / 387k | 33% / 49% |
| stops at 3:00 without the helper (casual) | 63 | 9% | 4k / 4k / 4k | 0% / 0% |

## Seconds from each machine level to the next (dead zones over 120 s in bold)

| player | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9 | L10 | L11 | L12 | L13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 8 | 8 | 8 | 8 | 17 | 10 | 24 | 35 | 59 | 44 | 86 | **127** | 89 | **161** |
| skilled, butter | 8 | 8 | 8 | 8 | 17 | 17 | 35 | 51 | 81 | 60 | 118 | **169** | 118 | **208** |
| skilled, cheese | 8 | 8 | 8 | 8 | 17 | 17 | 36 | 50 | 86 | 63 | **121** | **175** | **122** | **214** |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 14 | 19 | 9 | 14 | 39 | 37 | 57 | 97 | **147** | 95 | **197** | **257** | **195** | – |
| casual, caramel | 14 | 19 | 9 | 14 | 39 | 35 | 41 | 82 | 106 | 91 | **166** | **220** | **144** | – |
| casual, cheese | 14 | 19 | 9 | 14 | 39 | 31 | 55 | 75 | **131** | 90 | **191** | **235** | **150** | – |
| novice (wild timing, never shakes, slow, butter) | 14 | 20 | 13 | 15 | 38 | 35 | 55 | 80 | 119 | 85 | **175** | **233** | **157** | – |
| novice, caramel | 14 | 20 | 13 | 15 | 38 | 29 | 50 | 74 | 115 | 75 | **157** | **222** | **144** | – |
| novice, cheese | 14 | 20 | 13 | 15 | 38 | 28 | 53 | 70 | 105 | 78 | **137** | **203** | **135** | **244** |
| never shakes (casual, butter) | 14 | 19 | 9 | 14 | 38 | 37 | 57 | 97 | **147** | 95 | **197** | **257** | **195** | – |
| low interaction (casual until the helper, then only buys) | 14 | 19 | 9 | 14 | 39 | 37 | **164** | **305** | **403** | – | – | – | – | – |
| never automates (skilled, caramel) | 8 | 8 | 8 | 8 | 10 | 10 | 17 | 24 | 37 | 53 | 72 | 96 | **121** | **151** |
| automation first (casual, buys the ladder before the machine) | 12 | 23 | 15 | 23 | 49 | 30 | 60 | 101 | **140** | 96 | **194** | **262** | **187** | – |
| delayed automation (skilled, caramel, no automation before Lv8) | 8 | 8 | 8 | 8 | 10 | 10 | 17 | 24 | 73 | 43 | 86 | **127** | 89 | **161** |
| diversified recipes (casual, changes recipe every 2 min) | 14 | 19 | 9 | 14 | 39 | 35 | 41 | 87 | **125** | 94 | **170** | **244** | **159** | – |
| idle break (casual, butter, no input 5:00-8:00) | 14 | 19 | 9 | 14 | 39 | 37 | 57 | 97 | **268** | 95 | **200** | **265** | – | – |
| slow novice (3-6 s between presses, wild timing, cheese) | 20 | 43 | 29 | 41 | 85 | 62 | 68 | **126** | **152** | **120** | **212** | – | – | – |
| stops at 3:00 without the helper (casual) | 14 | 19 | 9 | 14 | 27 | 37 | 54 | – | – | – | – | – | – | – |
