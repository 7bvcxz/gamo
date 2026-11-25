# Snowball Relay -- input economy (deterministic, matched state, no buying)

| state | window | policy | touches | input % | snow | snow/touch | distance | radius x | avg roll s | moving % |
|---|---|---|---|---|---|---|---|---|---|---|
| fresh   lv 0/0/0/0/0 | 10s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| fresh   lv 0/0/0/0/0 | 10s | occasional | 4 | 8 | 42 | 10.6 | 29 | 1.23 | 2.6 | 100 |
| fresh   lv 0/0/0/0/0 | 10s | relaxed | 5 | 10 | 49 | 9.8 | 36 | 1.28 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 10s | spam | 75 | 150 | 54 | 0.7 | 36 | 1.28 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 30s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| fresh   lv 0/0/0/0/0 | 30s | occasional | 12 | 8 | 153 | 12.7 | 86 | 1.56 | 2.6 | 100 |
| fresh   lv 0/0/0/0/0 | 30s | relaxed | 15 | 10 | 191 | 12.7 | 108 | 1.67 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 30s | spam | 226 | 151 | 185 | 0.8 | 102 | 1.64 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 60s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| fresh   lv 0/0/0/0/0 | 60s | occasional | 24 | 8 | 309 | 12.9 | 170 | 1.92 | 2.6 | 100 |
| fresh   lv 0/0/0/0/0 | 60s | relaxed | 30 | 10 | 410 | 13.7 | 216 | 2.08 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 60s | spam | 451 | 150 | 385 | 0.9 | 201 | 2.04 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 180s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| fresh   lv 0/0/0/0/0 | 180s | occasional | 70 | 8 | 1025 | 14.6 | 507 | 2.85 | 2.6 | 100 |
| fresh   lv 0/0/0/0/0 | 180s | relaxed | 89 | 10 | 1344 | 15.1 | 645 | 3.14 | 0.0 | 100 |
| fresh   lv 0/0/0/0/0 | 180s | spam | 1350 | 150 | 1234 | 0.9 | 597 | 3.04 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 10s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| early   lv 2/2/2/2/1 | 10s | occasional | 2 | 4 | 139 | 69.4 | 52 | 1.65 | 6.7 | 100 |
| early   lv 2/2/2/2/1 | 10s | relaxed | 2 | 4 | 146 | 72.9 | 57 | 1.69 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 10s | spam | 75 | 150 | 244 | 3.2 | 90 | 1.96 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 30s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| early   lv 2/2/2/2/1 | 30s | occasional | 5 | 3 | 410 | 82.0 | 140 | 2.29 | 6.7 | 100 |
| early   lv 2/2/2/2/1 | 30s | relaxed | 6 | 4 | 498 | 83.0 | 172 | 2.47 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 30s | spam | 226 | 151 | 838 | 3.7 | 266 | 2.91 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 60s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| early   lv 2/2/2/2/1 | 60s | occasional | 9 | 3 | 839 | 93.2 | 266 | 2.91 | 6.7 | 100 |
| early   lv 2/2/2/2/1 | 60s | relaxed | 12 | 4 | 1093 | 91.1 | 342 | 3.21 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 60s | spam | 451 | 150 | 1815 | 4.0 | 530 | 3.82 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 180s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| early   lv 2/2/2/2/1 | 180s | occasional | 27 | 3 | 2897 | 107.3 | 797 | 4.51 | 6.7 | 100 |
| early   lv 2/2/2/2/1 | 180s | relaxed | 35 | 4 | 3887 | 111.1 | 1012 | 4.97 | 0.0 | 100 |
| early   lv 2/2/2/2/1 | 180s | spam | 1350 | 150 | 6745 | 5.0 | 1586 | 5.98 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 10s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| mid     lv 4/4/4/3/2 | 10s | occasional | 1 | 2 | 217 | 216.5 | 64 | 2.01 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 10s | relaxed | 2 | 4 | 307 | 153.3 | 83 | 2.19 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 10s | spam | 75 | 150 | 521 | 7.0 | 136 | 2.63 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 30s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| mid     lv 4/4/4/3/2 | 30s | occasional | 3 | 2 | 772 | 257.2 | 192 | 3.00 | 10.9 | 100 |
| mid     lv 4/4/4/3/2 | 30s | relaxed | 4 | 3 | 1012 | 252.9 | 240 | 3.27 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 30s | spam | 226 | 151 | 1759 | 7.8 | 409 | 4.05 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 60s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| mid     lv 4/4/4/3/2 | 60s | occasional | 6 | 2 | 1622 | 270.4 | 377 | 3.92 | 10.9 | 100 |
| mid     lv 4/4/4/3/2 | 60s | relaxed | 8 | 3 | 2013 | 251.6 | 460 | 4.25 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 60s | spam | 451 | 150 | 4020 | 8.9 | 818 | 5.38 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 180s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| mid     lv 4/4/4/3/2 | 180s | occasional | 17 | 2 | 5789 | 340.5 | 1094 | 6.07 | 10.9 | 100 |
| mid     lv 4/4/4/3/2 | 180s | relaxed | 22 | 2 | 7639 | 347.2 | 1380 | 6.68 | 0.0 | 100 |
| mid     lv 4/4/4/3/2 | 180s | spam | 1350 | 150 | 15553 | 11.5 | 2453 | 8.49 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 10s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| late    lv 8/7/7/7/7 | 10s | occasional | 1 | 2 | 987 | 986.9 | 120 | 3.05 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 10s | relaxed | 1 | 2 | 987 | 986.9 | 120 | 3.05 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 10s | spam | 75 | 150 | 1733 | 23.1 | 203 | 3.75 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 30s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| late    lv 8/7/7/7/7 | 30s | occasional | 2 | 1 | 2412 | 1205.9 | 278 | 4.26 | 17.1 | 100 |
| late    lv 8/7/7/7/7 | 30s | relaxed | 3 | 2 | 3000 | 1000.1 | 339 | 4.62 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 30s | spam | 226 | 151 | 5895 | 26.1 | 615 | 5.91 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 60s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| late    lv 8/7/7/7/7 | 60s | occasional | 4 | 1 | 5081 | 1270.1 | 541 | 5.60 | 17.1 | 100 |
| late    lv 8/7/7/7/7 | 60s | relaxed | 5 | 2 | 6481 | 1296.2 | 664 | 6.10 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 60s | spam | 451 | 150 | 13358 | 29.6 | 1232 | 7.88 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 180s | none | 0 | 0 | 0 | 0.0 | 0 | 1.00 | 0.0 | 0 |
| late    lv 8/7/7/7/7 | 180s | occasional | 11 | 1 | 17728 | 1611.7 | 1544 | 8.66 | 17.1 | 100 |
| late    lv 8/7/7/7/7 | 180s | relaxed | 14 | 2 | 23206 | 1657.6 | 1944 | 9.54 | 0.0 | 100 |
| late    lv 8/7/7/7/7 | 180s | spam | 1350 | 150 | 50622 | 37.5 | 3701 | 12.49 | 0.0 | 100 |

## spam / relaxed snow ratio
- fresh 10s spam/relaxed = 1.11x snow for 15x the touches (75 vs 5)
- fresh 30s spam/relaxed = 0.97x snow for 15x the touches (226 vs 15)
- fresh 60s spam/relaxed = 0.94x snow for 15x the touches (451 vs 30)
- fresh 180s spam/relaxed = 0.92x snow for 15x the touches (1350 vs 89)
- early 10s spam/relaxed = 1.67x snow for 38x the touches (75 vs 2)
- early 30s spam/relaxed = 1.68x snow for 38x the touches (226 vs 6)
- early 60s spam/relaxed = 1.66x snow for 38x the touches (451 vs 12)
- early 180s spam/relaxed = 1.74x snow for 39x the touches (1350 vs 35)
- mid   10s spam/relaxed = 1.70x snow for 38x the touches (75 vs 2)
- mid   30s spam/relaxed = 1.74x snow for 56x the touches (226 vs 4)
- mid   60s spam/relaxed = 2.00x snow for 56x the touches (451 vs 8)
- mid   180s spam/relaxed = 2.04x snow for 61x the touches (1350 vs 22)
- late  10s spam/relaxed = 1.76x snow for 75x the touches (75 vs 1)
- late  30s spam/relaxed = 1.96x snow for 75x the touches (226 vs 3)
- late  60s spam/relaxed = 2.06x snow for 90x the touches (451 vs 5)
- late  180s spam/relaxed = 2.18x snow for 96x the touches (1350 vs 14)

worst spam/relaxed ratio: 2.18x
