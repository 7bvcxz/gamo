# Popcorn test report (AUTOMATED)

- git 9f32470e4975 (uncommitted changes) · build 0.48.0 game-b200c5621787.pck
- 2026-11-22T04:10:40.640Z
- target: local docs/ (http://127.0.0.1)
- headless: **PASSED** (354 passed, 0 failed, 24130 checks, 31 files, 693.9s)
- deploy: **PASSED**
- browser: **FAILED** — passed 64 (on retry 0), failed 3, skipped 25

- mode: **only**, 9 specs · load 1.15 1.92 4.10 → 10.22 9.57 8.79 · free memory 33687 → 33542 MB
- not run (SKIPPED, with why): art15.spec.mjs — not asked for (--only); art40.spec.mjs — not asked for (--only); art41.spec.mjs — not asked for (--only); burst14.spec.mjs — not asked for (--only); career39.spec.mjs — not asked for (--only); catalog27.spec.mjs — not asked for (--only); craft35.spec.mjs — not asked for (--only); customers36.spec.mjs — not asked for (--only); experiments04.spec.mjs — not asked for (--only); factory16.spec.mjs — not asked for (--only); factory17.spec.mjs — not asked for (--only); factory18.spec.mjs — not asked for (--only); factory19.spec.mjs — not asked for (--only); factory20.spec.mjs — not asked for (--only); factory21.spec.mjs — not asked for (--only); factory23.spec.mjs — not asked for (--only); factory26.spec.mjs — not asked for (--only); factory28.spec.mjs — not asked for (--only); factory29.spec.mjs — not asked for (--only); factory30.spec.mjs — not asked for (--only); factory31.spec.mjs — not asked for (--only); factory32.spec.mjs — not asked for (--only); factory33.spec.mjs — not asked for (--only); flavors34.spec.mjs — not asked for (--only); input07.spec.mjs — not asked for (--only); motion42.spec.mjs — not asked for (--only); perf07.spec.mjs — not asked for (--only); perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); progression07.spec.mjs — not asked for (--only); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); responsive07.spec.mjs — not asked for (--only); save45.spec.mjs — not asked for (--only); scorecard09.spec.mjs — not asked for (--only); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow); soak43.spec.mjs — not asked for (--only); sound05.spec.mjs — not asked for (--only); sound43.spec.mjs — not asked for (--only); stall09.spec.mjs — not asked for (--only); stand10.spec.mjs — not asked for (--only)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | FAILED | Error: expect(received).toBe(expected) // Object.is equality  Expected: "perfect_streak" Received: undefined  Call Log: |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.4,"packs":135,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135400,"leftHidden":135350}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":1.3,"packs":135,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | FAILED | Error: expect(received).toBe(expected) // Object.is equality  Expected: "perfect_streak" Received: undefined  Call Log: |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.5,"packs":138,"tier":3,"prize":240,"overfill":2,"lost":0} |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | p720 | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | p720 | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | phone | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | phone | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | desktop | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | desktop | PASSED |  |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10148,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10339,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | FAILED | Error: entered by a tap  entered by a tap  expect(received).toBe(expected) // Object.is equality  |
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
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1546,"unread":1,"marks":1}; hidden: {"left0":112600,"leftHidden":112500}; craze: {"row":{"asked":13,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1869,"unread":1,"marks":1}; hidden: {"left0":111500,"leftHidden":111450}; craze: {"row":{"asked":14,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":112700,"leftHidden":112650}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | p720 | PASSED | ready47: {"ring_sat":{"ready":0.478,"waiting":0.379},"cue_after_lift":true,"refused":1} |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | phone | PASSED | ready47: {"ring_sat":{"ready":0.483,"waiting":0.37},"cue_after_lift":true,"refused":1} |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | desktop | PASSED | ready47: {"ring_sat":{"ready":0.483,"waiting":0.374},"cue_after_lift":true,"refused":1} |
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
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 1141 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 1419 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 1219 ms to the first drawn frame |
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
