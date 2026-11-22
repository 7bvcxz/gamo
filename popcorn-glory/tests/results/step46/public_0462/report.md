# Popcorn test report (AUTOMATED)

- git a831551aec88 (uncommitted changes) · build 0.46.2 game-a96a4a030639.pck
- 2026-11-22T00:24:58.680Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **SKIPPED** 
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **PASSED** — passed 38 (on retry 0), failed 0, skipped 10

- mode: **only**, 4 specs · load 1.36 5.58 7.17 → 6.83 7.07 7.47 · free memory 33868 → 33627 MB
- not run (SKIPPED, with why): art15.spec.mjs — not asked for (--only); art40.spec.mjs — not asked for (--only); art41.spec.mjs — not asked for (--only); burst14.spec.mjs — not asked for (--only); career39.spec.mjs — not asked for (--only); catalog27.spec.mjs — not asked for (--only); contests38.spec.mjs — not asked for (--only); craft35.spec.mjs — not asked for (--only); customers36.spec.mjs — not asked for (--only); experiments04.spec.mjs — not asked for (--only); factory16.spec.mjs — not asked for (--only); factory17.spec.mjs — not asked for (--only); factory18.spec.mjs — not asked for (--only); factory19.spec.mjs — not asked for (--only); factory20.spec.mjs — not asked for (--only); factory21.spec.mjs — not asked for (--only); factory22.spec.mjs — not asked for (--only); factory23.spec.mjs — not asked for (--only); factory26.spec.mjs — not asked for (--only); factory28.spec.mjs — not asked for (--only); factory29.spec.mjs — not asked for (--only); factory30.spec.mjs — not asked for (--only); factory31.spec.mjs — not asked for (--only); factory32.spec.mjs — not asked for (--only); factory33.spec.mjs — not asked for (--only); flavors34.spec.mjs — not asked for (--only); input07.spec.mjs — not asked for (--only); motion42.spec.mjs — not asked for (--only); news37.spec.mjs — not asked for (--only); perf07.spec.mjs — not asked for (--only); perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); progression07.spec.mjs — not asked for (--only); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); responsive07.spec.mjs — not asked for (--only); scorecard09.spec.mjs — not asked for (--only); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow); soak43.spec.mjs — not asked for (--only); sound05.spec.mjs — not asked for (--only); sound43.spec.mjs — not asked for (--only); stall09.spec.mjs — not asked for (--only); stand10.spec.mjs — not asked for (--only); stub03.spec.mjs — not asked for (--only); ui44.spec.mjs — not asked for (--only)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10149,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10256,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | PASSED | by_hand: {"first_sale_ms":10173,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| negative46.spec.mjs | a game pack that fails to download says so -- no endless blank page | p720 | PASSED | pack_failure: {"aborted":4,"notice":"Failed to fetch"} |
| negative46.spec.mjs | a jittery finger on the kettle: one press a press, nothing stuck, nothing burnt by the jitter | p720 | PASSED | jitter: {"taps":24,"presses":12,"heating":false,"outcomes":{"burnt":0,"early":12,"late":0,"near":0,"perfect":0}} |
| negative46.spec.mjs | a reload in the middle of a pack: every portion and every coin where it was | p720 | PASSED | mid_pack: {"before":{"sold":4,"money":400024,"made":16,"lift":4,"serves":1},"after":{"sold":3,"money":400017,"made":8,"from":"main"}} |
| negative46.spec.mjs | a hold across a hidden tab ends the press: nothing heats while nobody looks | p720 | PASSED |  |
| negative46.spec.mjs | a game pack that fails to download says so -- no endless blank page | phone | PASSED | pack_failure: {"aborted":4,"notice":"Failed to fetch"} |
| negative46.spec.mjs | a jittery finger on the kettle: one press a press, nothing stuck, nothing burnt by the jitter | phone | PASSED | jitter: {"taps":24,"presses":12,"heating":false,"outcomes":{"burnt":0,"early":12,"late":0,"near":0,"perfect":0}} |
| negative46.spec.mjs | a reload in the middle of a pack: every portion and every coin where it was | phone | PASSED | mid_pack: {"before":{"sold":4,"money":400024,"made":16,"lift":4,"serves":1},"after":{"sold":3,"money":400017,"made":8,"from":"main"}} |
| negative46.spec.mjs | a hold across a hidden tab ends the press: nothing heats while nobody looks | phone | PASSED |  |
| negative46.spec.mjs | a game pack that fails to download says so -- no endless blank page | desktop | PASSED | pack_failure: {"aborted":4,"notice":"Failed to fetch"} |
| negative46.spec.mjs | a jittery finger on the kettle: one press a press, nothing stuck, nothing burnt by the jitter | desktop | PASSED | jitter: {"taps":24,"presses":12,"heating":false,"outcomes":{"burnt":0,"early":12,"late":0,"near":0,"perfect":0}} |
| negative46.spec.mjs | a reload in the middle of a pack: every portion and every coin where it was | desktop | PASSED | mid_pack: {"before":{"sold":4,"money":400024,"made":16,"lift":4,"serves":1},"after":{"sold":3,"money":400017,"made":8,"from":"main"}} |
| negative46.spec.mjs | a hold across a hidden tab ends the press: nothing heats while nobody looks | desktop | PASSED |  |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | p720 | PASSED | device: p720 chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | p720 | PASSED |  |
| release12.spec.mjs | first load on a slow connection (recorded) | p720 | SKIPPED | desktop measures |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | p720 | PASSED |  |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | p720 | PASSED |  |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | phone | PASSED | device: phone chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | phone | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | phone | SKIPPED | desktop measures |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | phone | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | phone | SKIPPED | one project |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | desktop | PASSED | device: desktop chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | desktop | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 64162 ms |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | desktop | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | desktop | SKIPPED | one project |
| save45.spec.mjs | a reload and a trip to the stand keep the factory, and the stand keeps its own | p720 | PASSED |  |
| save45.spec.mjs | a killed browser loses seconds, never goods: nothing sold twice, every machine there | p720 | SKIPPED | one browser kill is enough; the save path is the same on every screen |
| save45.spec.mjs | old builds' saves open: a 0.12.2 stand and a 0.43.0 forty-four-machine factory | p720 | PASSED |  |
| save45.spec.mjs | a broken save is set aside, the backup comes back, and the saves page shows both | p720 | PASSED |  |
| save45.spec.mjs | the saves page exports and imports, and the factory comes back from the file | p720 | PASSED |  |
| save45.spec.mjs | restart takes two taps and the old factory waits in the backup | p720 | PASSED |  |
| save45.spec.mjs | a reload and a trip to the stand keep the factory, and the stand keeps its own | phone | PASSED |  |
| save45.spec.mjs | a killed browser loses seconds, never goods: nothing sold twice, every machine there | phone | SKIPPED | one browser kill is enough; the save path is the same on every screen |
| save45.spec.mjs | old builds' saves open: a 0.12.2 stand and a 0.43.0 forty-four-machine factory | phone | PASSED |  |
| save45.spec.mjs | a broken save is set aside, the backup comes back, and the saves page shows both | phone | PASSED |  |
| save45.spec.mjs | the saves page exports and imports, and the factory comes back from the file | phone | PASSED |  |
| save45.spec.mjs | restart takes two taps and the old factory waits in the backup | phone | PASSED |  |
| save45.spec.mjs | a reload and a trip to the stand keep the factory, and the stand keeps its own | desktop | PASSED |  |
| save45.spec.mjs | a killed browser loses seconds, never goods: nothing sold twice, every machine there | desktop | PASSED | kill: {"pids":2,"built_clock":31662,"before_kill_clock":38710,"saved_clock":31544,"sold":[14,12,12],"from":"main"} |
| save45.spec.mjs | old builds' saves open: a 0.12.2 stand and a 0.43.0 forty-four-machine factory | desktop | PASSED |  |
| save45.spec.mjs | a broken save is set aside, the backup comes back, and the saves page shows both | desktop | PASSED |  |
| save45.spec.mjs | the saves page exports and imports, and the factory comes back from the file | desktop | PASSED |  |
| save45.spec.mjs | restart takes two taps and the old factory waits in the backup | desktop | PASSED |  |
