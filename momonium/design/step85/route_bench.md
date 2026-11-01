# route_bench, 20 simulated minutes per scenario (Step 85 final)

`godot --headless --path momonium --script res://tools/route_bench.gd -- --minutes 20 --json design/step85/route_bench.json`

| Scenario | Strategy | Stages / 10 min | Walking | Idle | Ready work left while idle | Worst wait of a ready stop | Stages per stop (min-max) | Mid-walk retargets | Distance (tiles) | us / decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| four farms, tapped crosswise | A strict | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 103 |
| four farms, tapped crosswise | B priority | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 154 |
| four farms, tapped crosswise | C soonest | 44.5 | 30% | 3% | 122 s | 100 s | 21-25 | 0 | 272 | 167 |
| mixed: farm, lab, mine, farm, lumberyard | A strict | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 92 |
| mixed: farm, lab, mine, farm, lumberyard | B priority | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 121 |
| mixed: farm, lab, mine, farm, lumberyard | C soonest | 22.0 | 18% | 1% | 20 s | 138 s | 9-15 | 0 | 167 | 127 |
| three farms beside, a lab far away | A strict | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 99 |
| three farms beside, a lab far away | B priority | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 137 |
| three farms beside, a lab far away | C soonest | 35.0 | 25% | 0% | 0 s | 104 s | 10-26 | 0 | 232 | 156 |
| two Momo sharing six stops | A strict | 28.5 | 15% | 34% | 2540 s | 229 s | 7-15 | 0 | 283 | 81 |
| two Momo sharing six stops | B priority | 45.5 | 28% | 0% | 0 s | 175 s | 11-23 | 0 | 509 | 128 |
| two Momo sharing six stops | C soonest | 52.0 | 22% | 1% | 55 s | 122 s | 9-37 | 0 | 411 | 125 |
| large: four Momo, sixteen stops | A strict | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 99 |
| large: four Momo, sixteen stops | B priority | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 138 |
| large: four Momo, sixteen stops | C soonest | 135.0 | 14% | 3% | 421 s | 124 s | 10-35 | 0 | 530 | 143 |

## starve_seconds = 30 (tuning, `--starve 30`)

| Scenario | Strategy | Stages / 10 min | Walking | Idle | Ready work left while idle | Worst wait of a ready stop | Stages per stop (min-max) | Mid-walk retargets | Distance (tiles) | us / decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| four farms, tapped crosswise | A strict | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 107 |
| four farms, tapped crosswise | B priority | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 156 |
| four farms, tapped crosswise | C soonest | 38.5 | 41% | 0% | 10 s | 78 s | 18-21 | 0 | 377 | 164 |
| mixed: farm, lab, mine, farm, lumberyard | A strict | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 93 |
| mixed: farm, lab, mine, farm, lumberyard | B priority | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 123 |
| mixed: farm, lab, mine, farm, lumberyard | C soonest | 22.0 | 19% | 0% | 10 s | 106 s | 10-13 | 0 | 176 | 127 |
| three farms beside, a lab far away | A strict | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 101 |
| three farms beside, a lab far away | B priority | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 139 |
| three farms beside, a lab far away | C soonest | 28.5 | 30% | 0% | 0 s | 78 s | 14-15 | 0 | 278 | 154 |
| two Momo sharing six stops | A strict | 28.5 | 15% | 34% | 2540 s | 229 s | 7-15 | 0 | 283 | 81 |
| two Momo sharing six stops | B priority | 48.5 | 27% | 0% | 0 s | 118 s | 14-23 | 0 | 501 | 128 |
| two Momo sharing six stops | C soonest | 46.5 | 28% | 0% | 7 s | 122 s | 11-22 | 0 | 516 | 130 |
| large: four Momo, sixteen stops | A strict | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 98 |
| large: four Momo, sixteen stops | B priority | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 146 |
| large: four Momo, sixteen stops | C soonest | 115.5 | 18% | 0% | 31 s | 100 s | 10-18 | 0 | 680 | 140 |

## starve_seconds = 45 (tuning, `--starve 45`)

| Scenario | Strategy | Stages / 10 min | Walking | Idle | Ready work left while idle | Worst wait of a ready stop | Stages per stop (min-max) | Mid-walk retargets | Distance (tiles) | us / decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| four farms, tapped crosswise | A strict | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 109 |
| four farms, tapped crosswise | B priority | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 155 |
| four farms, tapped crosswise | C soonest | 39.0 | 40% | 0% | 10 s | 88 s | 18-23 | 0 | 367 | 158 |
| mixed: farm, lab, mine, farm, lumberyard | A strict | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 95 |
| mixed: farm, lab, mine, farm, lumberyard | B priority | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 121 |
| mixed: farm, lab, mine, farm, lumberyard | C soonest | 22.0 | 19% | 0% | 10 s | 114 s | 10-14 | 0 | 174 | 126 |
| three farms beside, a lab far away | A strict | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 98 |
| three farms beside, a lab far away | B priority | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 142 |
| three farms beside, a lab far away | C soonest | 31.5 | 29% | 0% | 0 s | 88 s | 12-18 | 0 | 263 | 149 |
| two Momo sharing six stops | A strict | 28.5 | 15% | 34% | 2540 s | 229 s | 7-15 | 0 | 283 | 81 |
| two Momo sharing six stops | B priority | 46.0 | 28% | 0% | 0 s | 128 s | 10-22 | 0 | 512 | 127 |
| two Momo sharing six stops | C soonest | 49.5 | 25% | 1% | 53 s | 122 s | 9-27 | 0 | 454 | 122 |
| large: four Momo, sixteen stops | A strict | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 99 |
| large: four Momo, sixteen stops | B priority | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 140 |
| large: four Momo, sixteen stops | C soonest | 124.5 | 17% | 1% | 171 s | 111 s | 10-27 | 0 | 611 | 141 |

## starve_seconds = 90 (tuning, `--starve 90`)

| Scenario | Strategy | Stages / 10 min | Walking | Idle | Ready work left while idle | Worst wait of a ready stop | Stages per stop (min-max) | Mid-walk retargets | Distance (tiles) | us / decision |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| four farms, tapped crosswise | A strict | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 102 |
| four farms, tapped crosswise | B priority | 35.0 | 46% | 0% | 0 s | 62 s | 17-18 | 0 | 423 | 157 |
| four farms, tapped crosswise | C soonest | 49.5 | 20% | 6% | 209 s | 133 s | 22-28 | 0 | 182 | 166 |
| mixed: farm, lab, mine, farm, lumberyard | A strict | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 91 |
| mixed: farm, lab, mine, farm, lumberyard | B priority | 20.5 | 21% | 0% | 0 s | 107 s | 10-11 | 0 | 194 | 121 |
| mixed: farm, lab, mine, farm, lumberyard | C soonest | 29.5 | 14% | 2% | 88 s | 159 s | 7-29 | 0 | 133 | 144 |
| three farms beside, a lab far away | A strict | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 95 |
| three farms beside, a lab far away | B priority | 27.5 | 32% | 0% | 0 s | 80 s | 13-14 | 0 | 292 | 144 |
| three farms beside, a lab far away | C soonest | 41.0 | 19% | 1% | 30 s | 127 s | 9-27 | 0 | 180 | 192 |
| two Momo sharing six stops | A strict | 28.5 | 15% | 34% | 2540 s | 229 s | 7-15 | 0 | 283 | 78 |
| two Momo sharing six stops | B priority | 48.5 | 28% | 0% | 0 s | 135 s | 11-25 | 0 | 519 | 127 |
| two Momo sharing six stops | C soonest | 63.0 | 18% | 3% | 148 s | 152 s | 8-32 | 0 | 337 | 141 |
| large: four Momo, sixteen stops | A strict | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 97 |
| large: four Momo, sixteen stops | B priority | 108.5 | 21% | 0% | 0 s | 102 s | 10-16 | 0 | 793 | 137 |
| large: four Momo, sixteen stops | C soonest | 153.0 | 12% | 4% | 612 s | 156 s | 8-36 | 0 | 442 | 152 |
