# Popcorn Stand pacing (AUTOMATED, real rules, seed 7, 20 minutes)

Scripted behaviours; what the numbers do, not whether it is fun.

| player | Lv3 shake | Lv4 automation | Lv5 recipes | motor | helper | Lv @3 / 5 / 10 / 15 / 20 min | ladder @10 / 20 min | all bought | longest no-buy after 3:00 | helper share of 20 min | invariants |
|---|---|---|---|---|---|---|---|---|---|---|---|
| skilled (gold's middle, shakes, buys at once, caramel) | 0:24 | 0:33 | 0:50 | 0:39 | 1:09 | 8 / 10 / 13 / 14 / 14 | 7 / 7 | 11:32 | 103s | 31% | ok |
| skilled, butter | 0:24 | 0:33 | 0:50 | 0:39 | 1:20 | 8 / 10 / 12 / 13 / 14 | 6 / 7 | 15:11 | 131s | 39% | ok |
| skilled, cheese | 0:24 | 0:33 | 0:50 | 0:39 | 1:19 | 8 / 9 / 11 / 13 / 14 | 6 / 7 | 15:37 | 133s | 40% | ok |
| casual (mixed timing, shakes half the time, slow to buy, butter) | 0:43 | 0:57 | 1:36 | 1:21 | 2:35 | 6 / 8 / 10 / 11 / 13 | 4 / 6 | no | 191s | 49% | ok |
| casual, caramel | 0:43 | 0:57 | 1:36 | 1:21 | 2:27 | 7 / 8 / 10 / 12 / 13 | 5 / 7 | no | 139s | 46% | ok |
| casual, cheese | 0:43 | 0:57 | 1:36 | 1:21 | 2:29 | 6 / 8 / 10 / 11 / 13 | 5 / 7 | no | 149s | 45% | ok |
| novice (wild timing, never shakes, slow, butter) | 0:49 | 1:05 | 1:40 | 1:22 | 2:35 | 6 / 8 / 10 / 11 / 13 | 5 / 7 | no | 157s | 45% | ok |
| novice, caramel | 0:49 | 1:05 | 1:40 | 1:22 | 2:24 | 6 / 8 / 10 / 12 / 13 | 5 / 7 | no | 155s | 44% | ok |
| novice, cheese | 0:49 | 1:05 | 1:40 | 1:22 | 2:19 | 7 / 8 / 11 / 13 / 14 | 5 / 7 | 19:00 | 150s | 43% | ok |
| never shakes (casual, butter) | 0:43 | 0:57 | 1:36 | 1:13 | 2:35 | 6 / 8 / 10 / 11 / 13 | 4 / 6 | no | 191s | 49% | ok |
| low interaction (casual until the helper, then only buys) | 0:43 | 0:57 | 1:36 | 1:21 | 2:35 | 6 / 7 / 7 / 8 / 9 | 3 / 4 | no | 217s | 94% | ok |
| never automates (skilled, caramel) | 0:24 | 0:33 | 0:43 | – | – | 9 / 11 / 13 / 14 / 14 | 0 / 0 | no | 565s | 0% | ok |
| automation first (casual, buys the ladder before the machine) | 0:50 | 1:14 | 2:04 | 1:38 | 2:57 | 6 / 7 / 10 / 11 / 13 | 4 / 6 | no | 187s | 49% | ok |

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
