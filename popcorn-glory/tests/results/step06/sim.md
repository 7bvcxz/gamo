# Pacing simulation (AUTOMATED, real rules, seed 7)

Scripted behaviours on the game's own rules for 180 s of active time. Measures what the numbers do -- not tactile pleasure, discoverability or delight.

| behaviour | Lv @3:00 | first $ | 1st affordable | 1st bought | new looks (Lv3/6/9) | C cluster/fountain | buys | longest no-upgrade stretch | waits >=5 s | next upgrade @3:00 | inputs | invariants |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A active (4 taps/s, buys at once) | 11 | 2.0 | 7.6 | 7.9 | 19.0/45.9/96.2 | – | 11 | 34 s | 0.0 s | 19.9 s | 715 | ok |
| A steady (2.5 taps/s) | 9 | 2.0 | 11.1 | 12.6 | 30.8/74.6/155.6 | – | 9 | 33 s | 0.0 s | 17.7 s | 447 | ok |
| A newcomer (first tap 8 s, 1.2/s, pauses) | 6 | 8.0 | 27.1 | 30.1 | 68.3/158.7/– | – | 6 | 37 s | 0.0 s | 21.6 s | 208 | ok |
| A late buyer (saves 2x the price) | 8 | 2.0 | 11.1 | 22.0 | 47.7/108.4/– | – | 8 | 38 s | 0.0 s | 10.6 s | 447 | ok |
| A idle 30 s (60-90 s) | 8 | 2.0 | 11.1 | 12.6 | 30.8/104.6/– | – | 8 | 48 s | 30.4 s | 4.4 s | 372 | ok |
| A ignores the upgrade | 0 | 2.0 | 11.1 | – | –/–/– | – | 0 | 180 s | 0.0 s | affordable now | 447 | ok |
| B skilled (gold's middle) | 12 | 3.6 | 7.7 | 9.2 | 25.6/57.3/103.2 | – | 12 | 24 s | 0.0 s | 20.0 s | 83 | ok |
| B novice (mixed) | 7 | 6.6 | 25.0 | 28.0 | 54.5/116.7/– | – | 7 | 36 s | 0.0 s | affordable now | 80 | ok |
| B early reactions (100-300 ms before gold) | 7 | 3.2 | 16.0 | 17.5 | 51.1/122.5/– | – | 7 | 31 s | 0.0 s | 0.2 s | 112 | ok |
| B late reactions (100-300 ms after gold) | 6 | 4.1 | 21.2 | 22.7 | 68.0/171.8/– | – | 6 | 38 s | 0.0 s | 44.5 s | 69 | ok |
| B tapper (never holds) | 3 | 2.1 | 18.1 | 19.6 | 102.7/–/– | – | 3 | 77 s | 0.0 s | 17.5 s | 324 | ok |
| B late buyer (saves 2x) | 10 | 3.6 | 7.7 | 15.2 | 37.9/82.2/147.9 | – | 10 | 29 s | 0.0 s | 6.2 s | 84 | ok |
| B idle 30 s (60-90 s) | 11 | 3.6 | 7.7 | 9.2 | 25.6/57.3/132.7 | – | 11 | 42 s | 31.7 s | 23.4 s | 70 | ok |
| B ignores the upgrade | 0 | 3.6 | 7.7 | – | –/–/– | – | 0 | 180 s | 0.0 s | affordable now | 89 | ok |
| C active (4 taps/s, buys at once) | 10 | 3.8 | 7.6 | 7.9 | 21.7/55.0/120.7 | 21.7/55.0 | 10 | 30 s | 0.0 s | 5.3 s | 715 | ok |
| C steady (2.5 taps/s) | 9 | 4.8 | 11.1 | 12.6 | 34.7/79.9/149.6 | 34.7/79.9 | 9 | 30 s | 0.0 s | 1.4 s | 447 | ok |
| C newcomer (first tap 8 s, 1.2/s, pauses) | 6 | 13.8 | 27.1 | 30.1 | 76.7/169.5/– | 76.7/169.5 | 6 | 33 s | 166.0 s | 35.9 s | 208 | ok |
| C burst-heavy (6/s for 4 s, rest 2 s) | 10 | 3.2 | 5.8 | 7.3 | 23.5/60.7/127.7 | 23.5/60.7 | 10 | 30 s | 0.0 s | 13.2 s | 720 | ok |
| C late buyer (saves 2x) | 7 | 4.8 | 11.1 | 18.8 | 54.2/127.5/– | 54.2/127.5 | 7 | 32 s | 0.0 s | affordable now | 447 | ok |
| C idle 30 s (60-90 s) | 9 | 4.8 | 11.1 | 12.6 | 34.7/109.9/179.6 | 34.7/109.9 | 9 | 46 s | 33.2 s | 73.5 s | 372 | ok |
| C ignores the upgrade | 0 | 4.8 | 11.1 | – | –/–/– | –/– | 0 | 180 s | 0.0 s | affordable now | 447 | ok |

## Sensitivity (each experiment's steady player)

| experiment | change | Lv @3:00 | 1st bought | next upgrade @3:00 | longest no-upgrade stretch |
|---|---|---|---|---|---|
| click | cost x0.8 | 10 | 10.7 | 24.1 s | 34 s |
| click | cost x1.25 | 8 | 14.9 | 12.1 s | 33 s |
| click | growth -0.1 | 11 | 12.6 | 30.3 s | 30 s |
| click | growth +0.1 | 8 | 12.6 | 29.8 s | 39 s |
| perfect | cost x0.8 | 13 | 9.2 | 2.2 s | 22 s |
| perfect | cost x1.25 | 11 | 11.2 | 51.4 s | 26 s |
| perfect | growth -0.1 | 14 | 9.2 | max | 33 s |
| perfect | growth +0.1 | 10 | 9.2 | 26.8 s | 31 s |
| explosion | cost x0.8 | 11 | 9.5 | 57.4 s | 29 s |
| explosion | cost x1.25 | 8 | 15.7 | 6.9 s | 29 s |
| explosion | growth -0.1 | 11 | 12.6 | 43.5 s | 26 s |
| explosion | growth +0.1 | 8 | 12.6 | 0.1 s | 37 s |
