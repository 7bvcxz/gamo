# Popcorn test report (AUTOMATED)

- git 8d341a44b9a8 (uncommitted changes) · build 0.47.0 game-3e07f899dc75.pck
- 2026-11-22T02:16:45.548Z
- target: local docs/ (http://127.0.0.1)
- headless: **PASSED** (351 passed, 0 failed, 24111 checks, 30 files, 693.3s)
- deploy: **PASSED**
- browser: **FAILED** — passed 64 (on retry 0), failed 3, skipped 25

- mode: **only**, 9 specs · load 0.62 2.74 5.65 → 8.44 8.91 8.41 · free memory 33776 → 33581 MB
- not run (SKIPPED, with why): art15.spec.mjs — not asked for (--only); art40.spec.mjs — not asked for (--only); art41.spec.mjs — not asked for (--only); burst14.spec.mjs — not asked for (--only); career39.spec.mjs — not asked for (--only); catalog27.spec.mjs — not asked for (--only); customers36.spec.mjs — not asked for (--only); experiments04.spec.mjs — not asked for (--only); factory16.spec.mjs — not asked for (--only); factory17.spec.mjs — not asked for (--only); factory18.spec.mjs — not asked for (--only); factory19.spec.mjs — not asked for (--only); factory20.spec.mjs — not asked for (--only); factory21.spec.mjs — not asked for (--only); factory23.spec.mjs — not asked for (--only); factory26.spec.mjs — not asked for (--only); factory28.spec.mjs — not asked for (--only); factory29.spec.mjs — not asked for (--only); factory30.spec.mjs — not asked for (--only); factory31.spec.mjs — not asked for (--only); factory32.spec.mjs — not asked for (--only); factory33.spec.mjs — not asked for (--only); flavors34.spec.mjs — not asked for (--only); input07.spec.mjs — not asked for (--only); negative46.spec.mjs — not asked for (--only); news37.spec.mjs — not asked for (--only); perf07.spec.mjs — not asked for (--only); perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); progression07.spec.mjs — not asked for (--only); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); responsive07.spec.mjs — not asked for (--only); save45.spec.mjs — not asked for (--only); scorecard09.spec.mjs — not asked for (--only); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow); soak43.spec.mjs — not asked for (--only); sound05.spec.mjs — not asked for (--only); sound43.spec.mjs — not asked for (--only); stall09.spec.mjs — not asked for (--only); stand10.spec.mjs — not asked for (--only)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136600,"leftHidden":136550}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.1,"packs":136,"tier":2,"prize":120,"overfill":4,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135450,"leftHidden":135400}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":1.3,"packs":135,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136950,"leftHidden":136900}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.8,"packs":137,"tier":3,"prize":240,"overfill":3,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"caramel","gold":[1100,1450],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3579,"goldPre":3374,"turned":812,"area":[448.5599975585934,301.07031860351617,145.08004 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":5442,"goldPre":3583,"turned":2275,"area":[485.9400024414065,378.80126953125017,157.1700439 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":2596,"goldPre":2201,"turned":580,"area":[477.9150390625,221.80137939453132,170.03247070312 |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | p720 | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | p720 | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | phone | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | phone | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | desktop | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | desktop | PASSED |  |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10064,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10268,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | PASSED | by_hand: {"first_sale_ms":10173,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.3984848484848,7.97696666666666,3.11533333333333],"tier":"solo"}; celebrate: {"climb":[0.0404040404040404,0.178913580246914,0.314246913580247,0.722111111111111,0.858860670194003,0.993543209876543,1,1,- |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":30,"alive":19,"given":{"ambient":97,"lot":26,"sparkle":28},"low":true,"fps":12.8},{"t":19,"running":27,"alive":19,"given":{"ambient":113,"lot":30,"sparkle":41},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":46,"secs":13.175,"phase":[[48.11,48.11,48.11,16.44,0,48.11],[445.88,421.06,445.88,364.73,316.08,445.88]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":12.996,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.7362666666667,8.33843333333333,3.47194814814815],"tier":"solo"}; celebrate: {"climb":[0.0574444444444444,0.237555555555556,0.348666666666667,0.904592592592593,1,1,1,-1,-1,-1],"moved":0,"celebrations": |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":18,"alive":32,"given":{"ambient":90,"lot":32,"sparkle":30},"low":true,"fps":11.6},{"t":19,"running":28,"alive":33,"given":{"ambient":108,"lot":32,"sparkle":43},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":49,"secs":14.24,"phase":[[57.84,57.84,57.84,18.17,0,57.84],[568.52,554.14,568.52,470.44,394.69,568.52]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start", |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.86,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"], |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.382796969697,7.99044242424243,3.12838484848485],"tier":"solo"}; celebrate: {"climb":[0.0432098765432099,0.184444444444444,0.328037037037037,0.781111111111111,0.920517407407408,1,1,-1,-1,-1],"moved":0, |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":29,"alive":17,"given":{"ambient":97,"lot":29,"sparkle":28},"low":true,"fps":12},{"t":19,"running":27,"alive":42,"given":{"ambient":113,"lot":31,"sparkle":41},"low":true,"fps":12.4} |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":47,"secs":13.227,"phase":[[45.6,45.6,45.6,14.31,0,45.6],[418.27,399.47,418.27,341.48,298.78,418.27]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","ba |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.178,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | p720 | FAILED | Error: the dimmed ring is less saturated (ready 0.385, waiting 0.367)  expect(received).toBeLessThan(expected)  Expected: < 0.30778162897214395 Received:   0.3672537332049137 |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | phone | FAILED | Error: the dimmed ring is less saturated (ready 0.327, waiting 0.332)  expect(received).toBeLessThan(expected)  Expected: < 0.26170680894992726 Received:   0.33213524911909226 |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | desktop | FAILED | Error: the dimmed ring is less saturated (ready 0.376, waiting 0.373)  expect(received).toBeLessThan(expected)  Expected: < 0.3004660393007852 Received:   0.3733351889567971 |
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
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 1188 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 1403 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 1260 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | desktop | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | desktop | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | desktop | PASSED |  |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | p720 | PASSED | targets: {"project":"p720","viewport":{"width":720,"height":1280},"scenes":{"fresh":{"k":1,"min":48,"rows":{"back":84,"motion":84,"news":64,"restart":84,"slot_kitchen_0":85.4,"slot_kitchen_1":85.4,"slot_kitchen_2":85.4," |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | p720 | PASSED |  |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | p720 | PASSED |  |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | p720 | PASSED |  |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | phone | PASSED | targets: {"project":"phone","viewport":{"width":390,"height":844},"scenes":{"fresh":{"k":0.5,"min":26,"rows":{"back":45.5,"motion":45.5,"news":34.7,"restart":45.5,"slot_kitchen_0":43.1,"slot_kitchen_1":43.1,"slot_kitchen |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | phone | PASSED |  |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | phone | PASSED |  |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | phone | PASSED |  |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | desktop | PASSED | targets: {"project":"desktop","viewport":{"width":1280,"height":800},"scenes":{"fresh":{"k":1,"min":39,"rows":{"back":65,"motion":65,"news":52,"restart":65,"slot_kitchen_0":64.3,"slot_kitchen_1":64.3,"slot_kitchen_2":64. |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | desktop | PASSED |  |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | desktop | PASSED |  |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | desktop | PASSED |  |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | m-p720 | SKIPPED | p720 runs it |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | m-p720 | SKIPPED | the everyday three |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | m-p720 | SKIPPED | the everyday three |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | m-p720 | SKIPPED | the everyday three |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | m-hd | PASSED | targets: {"project":"m-hd","viewport":{"width":1920,"height":1080},"scenes":{"fresh":{"k":1,"min":52.7,"rows":{"back":87.8,"motion":87.8,"news":70.2,"restart":87.8,"slot_kitchen_0":86.9,"slot_kitchen_1":86.9,"slot_kitche |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | m-hd | SKIPPED | the everyday three |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | m-hd | SKIPPED | the everyday three |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | m-hd | SKIPPED | the everyday three |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | m-small | PASSED | targets: {"project":"m-small","viewport":{"width":360,"height":640},"scenes":{"fresh":{"k":0.333,"min":24,"rows":{"back":42,"motion":42,"news":32,"restart":42,"slot_kitchen_0":42.7,"slot_kitchen_1":42.7,"slot_kitchen_2": |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | m-small | SKIPPED | the everyday three |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | m-small | SKIPPED | the everyday three |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | m-small | SKIPPED | the everyday three |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | m-tablet | PASSED | targets: {"project":"m-tablet","viewport":{"width":768,"height":1024},"scenes":{"fresh":{"k":0.5,"min":38.4,"rows":{"back":67.2,"motion":67.2,"news":51.2,"restart":67.2,"slot_kitchen_0":68.3,"slot_kitchen_1":68.3,"slot_k |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | m-tablet | SKIPPED | the everyday three |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | m-tablet | SKIPPED | the everyday three |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | m-tablet | SKIPPED | the everyday three |
| ui44.spec.mjs | every finger target is big enough and nothing pressable sits on the ring, at every size | m-landscape | PASSED | targets: {"project":"m-landscape","viewport":{"width":844,"height":390},"scenes":{"fresh":{"k":0.333,"min":19,"rows":{"back":31.7,"motion":31.7,"news":25.4,"restart":31.7,"slot_kitchen_0":31.4,"slot_kitchen_1":31.4,"slot |
| ui44.spec.mjs | a refused press shows the full bin, a first tap brings the hold hint | m-landscape | SKIPPED | the everyday three |
| ui44.spec.mjs | a cancelled touch or a mouse that leaves ends the hold | m-landscape | SKIPPED | the everyday three |
| ui44.spec.mjs | the motion button calms the factory and the choice survives a reload | m-landscape | SKIPPED | the everyday three |
