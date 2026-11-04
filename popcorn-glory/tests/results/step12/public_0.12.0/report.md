# Popcorn test report (AUTOMATED)

- git ed0bd718d4e5 (uncommitted changes) · build 0.12.0 game-634c754f0c92.pck
- 2026-11-04T02:59:18.393Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (98 passed, 0 failed, 2430 checks, 15 files, 4.4s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **FAILED** — passed 110 (on retry 2), failed 1, skipped 16

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| experiments04.spec.mjs | the chooser lists A, B, C and each tile opens its experiment | p720 | PASSED |  |
| experiments04.spec.mjs | the atlas draws: the money coin is gold, not a white square | p720 | PASSED |  |
| experiments04.spec.mjs | A Click & Pop: every press pays at once | p720 | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding into the gold pays double; a quick tap is early | p720 | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding on burns by itself and never locks | p720 | PASSED |  |
| experiments04.spec.mjs | C Pop Explosion: eight presses erupt, drawn pieces stay under the cap | p720 | PASSED |  |
| experiments04.spec.mjs | runs never leak between experiments | p720 | PASSED |  |
| experiments04.spec.mjs | the chooser lists A, B, C and each tile opens its experiment | phone | PASSED |  |
| experiments04.spec.mjs | the atlas draws: the money coin is gold, not a white square | phone | PASSED |  |
| experiments04.spec.mjs | A Click & Pop: every press pays at once | phone | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding into the gold pays double; a quick tap is early | phone | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding on burns by itself and never locks | phone | PASSED |  |
| experiments04.spec.mjs | C Pop Explosion: eight presses erupt, drawn pieces stay under the cap | phone | PASSED |  |
| experiments04.spec.mjs | runs never leak between experiments | phone | PASSED |  |
| experiments04.spec.mjs | the chooser lists A, B, C and each tile opens its experiment | desktop | PASSED |  |
| experiments04.spec.mjs | the atlas draws: the money coin is gold, not a white square | desktop | PASSED (on retry) |  |
| experiments04.spec.mjs | A Click & Pop: every press pays at once | desktop | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding into the gold pays double; a quick tap is early | desktop | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding on burns by itself and never locks | desktop | PASSED |  |
| experiments04.spec.mjs | C Pop Explosion: eight presses erupt, drawn pieces stay under the cap | desktop | PASSED |  |
| experiments04.spec.mjs | runs never leak between experiments | desktop | PASSED |  |
| input07.spec.mjs | slide off the upgrade before letting go: no purchase | p720 | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | a double click buys once | p720 | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | the keyboard plays: space presses, escape goes back | p720 | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | slide off the upgrade before letting go: no purchase | phone | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | a double click buys once | phone | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | the keyboard plays: space presses, escape goes back | phone | SKIPPED | mouse paths on the desktop project |
| input07.spec.mjs | slide off the upgrade before letting go: no purchase | desktop | PASSED |  |
| input07.spec.mjs | a double click buys once | desktop | PASSED |  |
| input07.spec.mjs | the keyboard plays: space presses, escape goes back | desktop | PASSED |  |
| input07.spec.mjs | a cancelled touch never locks B | p720 | PASSED |  |
| input07.spec.mjs | dragging on the game never scrolls the page | p720 | PASSED |  |
| input07.spec.mjs | a cancelled touch never locks B | phone | PASSED |  |
| input07.spec.mjs | dragging on the game never scrolls the page | phone | PASSED |  |
| input07.spec.mjs | a cancelled touch never locks B | desktop | SKIPPED | touch paths on touch projects |
| input07.spec.mjs | dragging on the game never scrolls the page | desktop | SKIPPED | touch paths on touch projects |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2013,"heap_start":53500000,"heap_after_60s":53500000,"burst":{"fps":42.331167544719406,"draw_calls":117,"primitives":4295,"fx_peak":155,"fx_cap":400},"sleep":{"before":3499,"hidden_5s":3525,"after_wake": |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | FAILED | Error: expect(received).toBe(expected) // Object.is equality  Expected: 0 Received: 14  Call Log: |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | p720 | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | p720 | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | p720 | PASSED |  |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | phone | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | phone | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | phone | PASSED |  |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | desktop | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | desktop | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | desktop | PASSED |  |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | p720 | PASSED | device: p720 chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | p720 | PASSED |  |
| release12.spec.mjs | first load on a slow connection (recorded) | p720 | SKIPPED | desktop measures |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | phone | PASSED | device: phone chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | phone | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | phone | SKIPPED | desktop measures |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | desktop | PASSED | device: desktop chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | desktop | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 60896 ms |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | p720 | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | phone | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | desktop | PASSED |  |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1551 ms, game judged 1586 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1550 ms, game judged 1593 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1552 ms, game judged 1573 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 2010 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2299 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2071 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | desktop | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | desktop | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | desktop | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | reduced motion and sound off still play | m-p720 | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-p720 | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | reduced motion and sound off still play | m-hd | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-hd | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | reduced motion and sound off still play | m-small | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-small | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-tablet | PASSED (on retry) |  |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-tablet | PASSED | sizes: money 61 px tall, icon buttons 67 px, upgrade 416x133 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-tablet | PASSED | sizes: money 61 px tall, icon buttons 67 px, upgrade 416x133 px (CSS) |
| responsive07.spec.mjs | reduced motion and sound off still play | m-tablet | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-tablet | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | reduced motion and sound off still play | m-landscape | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-landscape | PASSED |  |
