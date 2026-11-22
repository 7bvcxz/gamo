# Popcorn test report (AUTOMATED)

- git 36b981c2b815 (uncommitted changes) · build 0.46.2 game-57079235c929.pck
- 2026-11-21T23:07:51.142Z
- target: local docs/ (http://127.0.0.1)
- headless: **PASSED** (349 passed, 0 failed, 24097 checks, 29 files, 680.0s)
- deploy: **PASSED**
- browser: **FAILED** — passed 53 (on retry 0), failed 1, skipped 9

- mode: **only**, 7 specs · load 0.81 1.33 4.08 → 10.78 8.96 7.54 · free memory 33030 → 33838 MB
- not run (SKIPPED, with why): art15.spec.mjs — not asked for (--only); art40.spec.mjs — not asked for (--only); art41.spec.mjs — not asked for (--only); burst14.spec.mjs — not asked for (--only); career39.spec.mjs — not asked for (--only); catalog27.spec.mjs — not asked for (--only); contests38.spec.mjs — not asked for (--only); craft35.spec.mjs — not asked for (--only); customers36.spec.mjs — not asked for (--only); experiments04.spec.mjs — not asked for (--only); factory16.spec.mjs — not asked for (--only); factory17.spec.mjs — not asked for (--only); factory18.spec.mjs — not asked for (--only); factory19.spec.mjs — not asked for (--only); factory20.spec.mjs — not asked for (--only); factory21.spec.mjs — not asked for (--only); factory23.spec.mjs — not asked for (--only); factory26.spec.mjs — not asked for (--only); factory28.spec.mjs — not asked for (--only); factory29.spec.mjs — not asked for (--only); factory30.spec.mjs — not asked for (--only); factory31.spec.mjs — not asked for (--only); factory32.spec.mjs — not asked for (--only); flavors34.spec.mjs — not asked for (--only); input07.spec.mjs — not asked for (--only); news37.spec.mjs — not asked for (--only); perf07.spec.mjs — not asked for (--only); perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); progression07.spec.mjs — not asked for (--only); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); responsive07.spec.mjs — not asked for (--only); save45.spec.mjs — not asked for (--only); scorecard09.spec.mjs — not asked for (--only); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow); soak43.spec.mjs — not asked for (--only); sound05.spec.mjs — not asked for (--only); sound43.spec.mjs — not asked for (--only); stall09.spec.mjs — not asked for (--only); stand10.spec.mjs — not asked for (--only); ui44.spec.mjs — not asked for (--only)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | p720 | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | p720 | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | phone | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | phone | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | desktop | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":37,"never":["cooker","cooker","kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":["cooker","cooker"]}; lines: {"at_pause":10,"before_kitchen_pause": |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":52,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":["cooker"]}; lines: {"at_pause":11,"before_kitchen_pause":8,"moved":3,"line_ |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | FAILED | Error: frame rate with forty-four machines (load 4.7)  expect(received).toBeGreaterThan(expected)  Expected: > 20 Received:   13.775459999382603 |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10092,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10298,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | PASSED | by_hand: {"first_sale_ms":10139,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.3882,7.98516666666666,3.11813333333333],"tier":"solo"}; celebrate: {"climb":[0.0457037037037038,0.203259259259259,0.349913580246914,0.806,0.938,1,1,-1,-1,-1],"moved":0,"celebrations":1,"kind":"sign"} |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":30,"alive":16,"given":{"ambient":98,"lot":26,"sparkle":28},"low":true,"fps":13.2},{"t":19,"running":27,"alive":45,"given":{"ambient":113,"lot":30,"sparkle":42},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":48,"secs":13.04,"phase":[[47.86,47.86,47.86,13.97,0,47.86],[441.1,422.25,441.1,358.58,311.54,441.1]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","ba |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":12.805,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.7465151515152,8.34444444444445,3.49787222222222],"tier":"solo"}; celebrate: {"climb":[0.0580925925925926,0.179520202020202,0.290759259259259,0.845771604938272,0.956882716049383,1,1,-1,-1,-1],"moved":0 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":32,"alive":25,"given":{"ambient":88,"lot":30,"sparkle":28},"low":true,"fps":11.5},{"t":19,"running":29,"alive":26,"given":{"ambient":105,"lot":31,"sparkle":42},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":50,"secs":13.917,"phase":[[58.16,58.16,58.16,19.29,0,58.16],[557.63,524.2,557.63,461.4,403.09,557.63]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start"," |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.813,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.3832158730159,7.98576666666667,3.14446666666667],"tier":"solo"}; celebrate: {"climb":[0.0426296296296294,0.175925925925926,0.357962962962963,0.768629629629629,0.907518518518518,1,1,-1,-1,-1],"moved":0 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":29,"alive":16,"given":{"ambient":97,"lot":26,"sparkle":28},"low":true,"fps":12.3},{"t":19,"running":27,"alive":41,"given":{"ambient":114,"lot":30,"sparkle":41},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":46,"secs":13.212,"phase":[[45.13,45.13,45.13,14.64,0,45.13],[417.16,398.56,417.16,342.19,296.82,417.16]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.141,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | SKIPPED | measured on the published URL |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | desktop | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | desktop | SKIPPED | one project |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 1248 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 1392 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 1221 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | desktop | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | desktop | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | desktop | PASSED |  |
