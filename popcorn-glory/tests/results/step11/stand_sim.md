# Popcorn Stand pacing (AUTOMATED, real rules, seed 7, 20 minutes)

Scripted behaviours; what the numbers do, not whether it is fun.

| player | Lv3 shake | Lv4 automation | Lv5 recipes | motor | helper | Lv @3 / 5 / 10 / 15 / 20 min | ladder @10 / 20 min | all bought | longest no-buy after 3:00 | helper share of 20 min | invariants |
|---|---|---|---|---|---|---|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 0:24 | 0:33 | 0:47 | 0:39 | 1:05 | 9 / 11 / 14 / 14 / 14 | 7 / 7 | 8:19 | 61s | 29% | ok |
| skilled, butter | 0:24 | 0:33 | 0:47 | 0:39 | 1:14 | 8 / 10 / 13 / 14 / 14 | 7 / 7 | 11:02 | 77s | 37% | ok |
| skilled, cheese | 0:24 | 0:33 | 0:47 | 0:39 | 1:14 | 8 / 10 / 13 / 14 / 14 | 6 / 7 | 11:23 | 81s | 38% | ok |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 0:43 | 0:57 | 1:40 | 1:21 | 2:48 | 6 / 8 / 10 / 12 / 14 | 5 / 7 | 19:32 | 125s | 53% | ok |
| casual, caramel | 0:43 | 0:57 | 1:40 | 1:21 | 2:30 | 7 / 8 / 11 / 13 / 14 | 5 / 7 | 16:37 | 103s | 47% | ok |
| casual, cheese | 0:43 | 0:57 | 1:40 | 1:21 | 2:34 | 6 / 8 / 11 / 13 / 14 | 5 / 7 | 17:30 | 107s | 49% | ok |
| novice (wild timing, never shakes, slow, butter) | 0:48 | 1:03 | 1:49 | 1:22 | 2:47 | 6 / 8 / 10 / 12 / 14 | 5 / 7 | 19:15 | 117s | 51% | ok |
| novice, caramel | 0:48 | 1:03 | 1:49 | 1:22 | 2:36 | 6 / 8 / 10 / 12 / 14 | 5 / 7 | 18:19 | 112s | 49% | ok |
| novice, cheese | 0:48 | 1:03 | 1:49 | 1:22 | 2:36 | 6 / 8 / 11 / 13 / 14 | 5 / 7 | 17:24 | 107s | 49% | ok |
| never shakes (casual, butter) | 0:43 | 0:57 | 1:46 | 1:13 | 3:04 | 6 / 7 / 10 / 11 / 13 | 5 / 7 | no | 126s | 52% | ok |
| low interaction (casual until the helper, then only buys) | 0:43 | 0:57 | 1:40 | 1:21 | 2:48 | 6 / 6 / 7 / 8 / 9 | 3 / 4 | no | 200s | 94% | ok |
| never automates (skilled, caramel) | 0:24 | 0:33 | 0:43 | – | – | 10 / 12 / 14 / 14 / 14 | 0 / 0 | no | 719s | 0% | ok |
| automation first (casual, buys the ladder before the machine) | 0:50 | 1:14 | 1:54 | 1:38 | 3:02 | 6 / 7 / 10 / 12 / 14 | 5 / 7 | 19:41 | 123s | 52% | ok |
| delayed automation (skilled, caramel, no automation before Lv8) | 0:24 | 0:33 | 0:43 | 1:38 | 1:40 | 9 / 11 / 14 / 14 / 14 | 7 / 7 | 8:15 | 60s | 29% | ok |
| diversified recipes (casual, changes recipe every 2 min) | 0:43 | 0:57 | 1:40 | 1:21 | 2:32 | 7 / 8 / 11 / 13 / 14 | 5 / 7 | 17:39 | 124s | 52% | ok |
| idle break (casual, butter, no input 5:00-8:00) | 0:43 | 0:57 | 1:40 | 1:21 | 2:48 | 6 / 8 / 9 / 11 / 13 | 4 / 7 | no | 170s | 50% | ok |
| slow novice (3-6 s between presses, wild timing, cheese) | 1:34 | 2:15 | 4:15 | 3:02 | 5:54 | 4 / 5 / 8 / 10 / 11 | 4 / 6 | no | 119s | 52% | ok |
| stops at 3:00 without the helper (casual) | 0:43 | 0:57 | 1:25 | – | – | 7 / 7 / 7 / 7 / 7 | 0 / 0 | no | 1020s | 0% | ok |

## Automation break-even (helper rungs, at the level the skilled player buys them)

| rung | cost | cycle | share | pays per batch then | break-even |
|---|---|---|---|---|---|
| 1 motor | 260 | – | – | every batch x1.3 | – |
| 2 helper | 1200 | 3.0s | 0.60 | 50 (Lv6) | 72s |
| 3 helper | 3600 | 2.7s | 0.70 | 93 (Lv7) | 104s |
| 4 helper | 11000 | 2.4s | 0.85 | 182 (Lv8) | 145s |
| 5 helper | 32000 | 2.1s | 1.00 | 550 (Lv10) | 122s |
| 6 helper | 90000 | 1.8s | 1.15 | 1011 (Lv11) | 160s |
| 7 helper | 250000 | 1.5s | 1.30 | 2912 (Lv13) | 128s |

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
| skilled (gold's middle, shakes, buys at once, caramel) | 545 | 81% | 245k / 2.24M / 8.47M | 26% / 29% |
| skilled, butter | 546 | 81% | 110k / 872k / 5.48M | 30% / 37% |
| skilled, cheese | 394 | 58% | 101k / 790k / 5.21M | 30% / 38% |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 416 | 64% | 17k / 123k / 1.34M | 34% / 53% |
| casual, caramel | 426 | 63% | 26k / 219k / 2.47M | 30% / 47% |
| casual, cheese | 381 | 58% | 23k / 172k / 2.07M | 32% / 49% |
| novice (wild timing, never shakes, slow, butter) | 440 | 62% | 18k / 129k / 1.43M | 34% / 51% |
| novice, caramel | 442 | 61% | 21k / 153k / 1.82M | 33% / 49% |
| novice, cheese | 394 | 57% | 23k / 169k / 2.06M | 33% / 49% |
| never shakes (casual, butter) | 419 | 64% | 14k / 101k / 1.05M | 35% / 52% |
| low interaction (casual until the helper, then only buys) | 57 | 9% | 5k / 14k / 64k | 75% / 94% |
| never automates (skilled, caramel) | 545 | 81% | 207k / 1.56M / 5.36M | 0% / 0% |
| automation first (casual, buys the ladder before the machine) | 412 | 64% | 14k / 112k / 1.28M | 33% / 52% |
| delayed automation (skilled, caramel, no automation before Lv8) | 545 | 81% | 252k / 2.26M / 8.50M | 26% / 29% |
| diversified recipes (casual, changes recipe every 2 min) | 407 | 62% | 24k / 183k / 1.92M | 31% / 52% |
| idle break (casual, butter, no input 5:00-8:00) | 356 | 54% | 17k / 58k / 854k | 43% / 50% |
| slow novice (3-6 s between presses, wild timing, cheese) | 189 | 26% | 2k / 27k / 327k | 31% / 52% |
| stops at 3:00 without the helper (casual) | 63 | 9% | 4k / 4k / 4k | 0% / 0% |

## Seconds from each machine level to the next (dead zones over 120 s in bold)

| player | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9 | L10 | L11 | L12 | L13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 8 | 8 | 8 | 8 | 14 | 10 | 19 | 33 | 50 | 31 | 63 | 85 | 52 | 103 |
| skilled, butter | 8 | 8 | 8 | 8 | 14 | 15 | 30 | 44 | 71 | 45 | 86 | 115 | 71 | **133** |
| skilled, cheese | 8 | 8 | 8 | 8 | 14 | 14 | 33 | 44 | 74 | 46 | 89 | 118 | 73 | **140** |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 14 | 19 | 9 | 14 | 42 | 42 | 61 | 85 | **133** | 85 | **140** | **196** | 107 | **218** |
| casual, caramel | 14 | 19 | 9 | 14 | 42 | 31 | 42 | 72 | 116 | 63 | **126** | **153** | 103 | **186** |
| casual, cheese | 14 | 19 | 9 | 14 | 42 | 37 | 48 | 78 | 112 | 71 | **133** | **172** | 106 | **188** |
| novice (wild timing, never shakes, slow, butter) | 14 | 20 | 13 | 15 | 45 | 37 | 55 | 82 | **131** | 74 | **150** | **195** | 112 | **205** |
| novice, caramel | 14 | 20 | 13 | 15 | 45 | 32 | 45 | 80 | **125** | 70 | **138** | **188** | 108 | **198** |
| novice, cheese | 14 | 20 | 13 | 15 | 45 | 29 | 51 | 76 | 107 | 75 | **136** | **166** | 107 | **184** |
| never shakes (casual, butter) | 14 | 19 | 9 | 14 | 49 | 53 | 65 | 88 | **128** | 88 | **168** | **207** | **126** | – |
| low interaction (casual until the helper, then only buys) | 14 | 19 | 9 | 14 | 42 | 42 | **161** | **307** | **386** | – | – | – | – | – |
| never automates (skilled, caramel) | 8 | 8 | 8 | 8 | 10 | 10 | 17 | 24 | 37 | 44 | 55 | 65 | 80 | 99 |
| automation first (casual, buys the ladder before the machine) | 12 | 23 | 15 | 23 | 40 | 35 | 70 | 92 | **129** | 85 | **133** | **192** | 113 | **215** |
| delayed automation (skilled, caramel, no automation before Lv8) | 8 | 8 | 8 | 8 | 10 | 10 | 17 | 24 | 62 | 33 | 63 | 83 | 54 | 102 |
| diversified recipes (casual, changes recipe every 2 min) | 14 | 19 | 9 | 14 | 42 | 33 | 42 | 72 | **124** | 84 | **121** | **161** | **124** | **193** |
| idle break (casual, butter, no input 5:00-8:00) | 14 | 19 | 9 | 14 | 42 | 42 | 61 | 85 | **256** | 82 | **141** | **199** | **123** | – |
| slow novice (3-6 s between presses, wild timing, cheese) | 20 | 43 | 29 | 41 | **120** | 64 | 92 | 113 | **164** | 104 | **204** | – | – | – |
| stops at 3:00 without the helper (casual) | 14 | 19 | 9 | 14 | 27 | 37 | 54 | – | – | – | – | – | – | – |
