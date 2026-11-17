# Popcorn test report (AUTOMATED)

- git 1f537b542afc · build 0.34.0 game-4ffd2ca1ce17.pck
- 2026-11-17T15:10:03.933Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (248 passed, 0 failed, 11895 checks, 18 files, 140.2s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **PASSED** — passed 203 (on retry 0), failed 0, skipped 34

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
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
| experiments04.spec.mjs | the atlas draws: the money coin is gold, not a white square | desktop | PASSED |  |
| experiments04.spec.mjs | A Click & Pop: every press pays at once | desktop | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding into the gold pays double; a quick tap is early | desktop | PASSED |  |
| experiments04.spec.mjs | B Perfect Pop: holding on burns by itself and never locks | desktop | PASSED |  |
| experiments04.spec.mjs | C Pop Explosion: eight presses erupt, drawn pieces stay under the cap | desktop | PASSED |  |
| experiments04.spec.mjs | runs never leak between experiments | desktop | PASSED |  |
| factory16.spec.mjs | the factory: three floors fit, the ring is in the kitchen, nothing covers them | p720 | PASSED |  |
| factory16.spec.mjs | the factory: the kettle cooks, a floor opens its detail without cooking | p720 | PASSED |  |
| factory16.spec.mjs | idle memory: the factory keeps far less than the stand | p720 | SKIPPED | desktop measures |
| factory16.spec.mjs | the factory: three floors fit, the ring is in the kitchen, nothing covers them | phone | PASSED |  |
| factory16.spec.mjs | the factory: the kettle cooks, a floor opens its detail without cooking | phone | PASSED |  |
| factory16.spec.mjs | idle memory: the factory keeps far less than the stand | phone | SKIPPED | desktop measures |
| factory16.spec.mjs | the factory: three floors fit, the ring is in the kitchen, nothing covers them | desktop | PASSED |  |
| factory16.spec.mjs | the factory: the kettle cooks, a floor opens its detail without cooking | desktop | PASSED |  |
| factory16.spec.mjs | idle memory: the factory keeps far less than the stand | desktop | PASSED | memory: idle, kept JS heap after GC: factory 0.25 MB/min, stand 0.97 MB/min |
| factory17.spec.mjs | the factory: no money at the pop, the first sale pays the pack price, goods are conserved | p720 | PASSED |  |
| factory17.spec.mjs | the factory: no money at the pop, the first sale pays the pack price, goods are conserved | phone | PASSED |  |
| factory17.spec.mjs | the factory: no money at the pop, the first sale pays the pack price, goods are conserved | desktop | PASSED |  |
| factory18.spec.mjs | one batch from the kettle to a satisfied customer | p720 | PASSED |  |
| factory18.spec.mjs | one batch from the kettle to a satisfied customer | phone | PASSED |  |
| factory18.spec.mjs | one batch from the kettle to a satisfied customer | desktop | PASSED |  |
| factory19.spec.mjs | the factory kettle: a real lot, the crescendo fills, an unaffordable card answers | p720 | PASSED |  |
| factory19.spec.mjs | the factory kettle: a real lot, the crescendo fills, an unaffordable card answers | phone | PASSED |  |
| factory19.spec.mjs | the factory kettle: a real lot, the crescendo fills, an unaffordable card answers | desktop | PASSED |  |
| factory20.spec.mjs | the packing station: fill, seal, shelf; the middle floor card sells the station | p720 | PASSED |  |
| factory20.spec.mjs | the packing station: fill, seal, shelf; the middle floor card sells the station | phone | PASSED |  |
| factory20.spec.mjs | the packing station: fill, seal, shelf; the middle floor card sells the station | desktop | PASSED |  |
| factory21.spec.mjs | first pop -> first pack -> one paid hand-over; a calm empty shop between customers | p720 | PASSED |  |
| factory21.spec.mjs | no stock, no sale: the queue fills, faces change, people leave, money stays 0 | p720 | PASSED |  |
| factory21.spec.mjs | first pop -> first pack -> one paid hand-over; a calm empty shop between customers | phone | PASSED |  |
| factory21.spec.mjs | no stock, no sale: the queue fills, faces change, people leave, money stays 0 | phone | PASSED |  |
| factory21.spec.mjs | first pop -> first pack -> one paid hand-over; a calm empty shop between customers | desktop | PASSED |  |
| factory21.spec.mjs | no stock, no sale: the queue fills, faces change, people leave, money stays 0 | desktop | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | p720 | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | p720 | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | phone | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | phone | PASSED |  |
| factory22.spec.mjs | the shop card sells the sign; the factory is saved across a reload | desktop | PASSED |  |
| factory22.spec.mjs | a seeded session is fresh and never saved | desktop | PASSED |  |
| factory23.spec.mjs | two products: each customer gets the bag they ordered, once; the cue names the bottleneck | p720 | PASSED |  |
| factory23.spec.mjs | two products: each customer gets the bag they ordered, once; the cue names the bottleneck | phone | PASSED |  |
| factory23.spec.mjs | two products: each customer gets the bag they ordered, once; the cue names the bottleneck | desktop | PASSED |  |
| factory26.spec.mjs | a cooker, a bagger and a kiosk: built from the screen, working with real goods, paid for | p720 | PASSED |  |
| factory26.spec.mjs | a cooker, a bagger and a kiosk: built from the screen, working with real goods, paid for | phone | PASSED |  |
| factory26.spec.mjs | a cooker, a bagger and a kiosk: built from the screen, working with real goods, paid for | desktop | PASSED |  |
| factory28.spec.mjs | eight kitchen devices: built from the picker, each doing its own job with real inputs | p720 | PASSED |  |
| factory28.spec.mjs | eight kitchen devices: built from the picker, each doing its own job with real inputs | phone | PASSED |  |
| factory28.spec.mjs | eight kitchen devices: built from the picker, each doing its own job with real inputs | desktop | PASSED |  |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":53,"auto_lots":61,"premium_lots":19,"premium_sold":29,"sorted":16,"dispatch_held_ms":20150,"vent_saves":0,"upkeep":65,"kernels":114} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":55,"auto_lots":63,"premium_lots":19,"premium_sold":29,"sorted":16,"dispatch_held_ms":26500,"vent_saves":0,"upkeep":66,"kernels":117} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":51,"auto_lots":63,"premium_lots":19,"premium_sold":30,"sorted":16,"dispatch_held_ms":18000,"vent_saves":0,"upkeep":64,"kernels":113} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[22.640023632873792,21.7498764211567,21.7069560927479,23.40093602873757,20.412130633851763,21.562285598242987],"median":21.7498764211567,"heap0":14861439,"heap1":20998563,"kept_mb":6.137124,"draw_calls":[793 |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":19,"small":26,"large":11,"bagger":20,"cup_feeder":20,"packed":63,"upkeep":32} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":13,"small":27,"large":21,"bagger":26,"cup_feeder":14,"packed":69,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":19,"small":26,"large":11,"bagger":20,"cup_feeder":20,"packed":64,"upkeep":31} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[25.8,24.7,23.9,24.2,23.6,23],"median":24.210730209038825,"packers_running":[3,2,0,2,3,2],"draw_calls":[514,530,596,634,656,698],"objects":[866,892,984,996,1027,1056],"load":9.05} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":104,"cashier":52,"express":50,"routed":4,"express_jumped":7,"lanes":4,"lost":37,"upkeep":68,"revenue":1240} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":103,"cashier":55,"express":46,"routed":0,"express_jumped":7,"lanes":4,"lost":42,"upkeep":70,"revenue":1230} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":101,"cashier":54,"express":45,"routed":1,"express_jumped":9,"lanes":4,"lost":38,"upkeep":66,"revenue":1214} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":9,"moved":5,"line_portions":[1,0,6]}; hidden: {"before |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":45,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":11,"before_kitchen_pause":10,"moved":3,"line_portions":[3,0,4]}; hidden |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | PASSED | layout: {"smallest_place_px":21,"window":[1280,800]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":9,"moved":3,"line_portions":[1,0,0]}; hidden: {"before |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":1091,"cheese":1206,"spicy":1207,"caramel":1183,"cocoa":771},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":5,"cocoa":1,"spicy":4},"revenue":{"caramel":128,"cheese":77,"cocoa":34,"spicy":71},"coated":{"caramel":20,"cheese":16,"cocoa":8,"spicy":12},"ingredients":49,"minutes":3.0125,"s |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2824,"cheese":2758,"spicy":2773,"caramel":2747,"cocoa":2418},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":5,"cocoa":1,"spicy":4},"revenue":{"caramel":130,"cheese":80,"cocoa":39,"spicy":69},"coated":{"caramel":16,"cheese":16,"cocoa":8,"spicy":12},"ingredients":45,"minutes":3.0641666 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":2089,"cheese":1437,"spicy":1454,"caramel":1441,"cocoa":1275},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":4,"cheese":10,"cocoa":5,"spicy":5},"revenue":{"caramel":70,"cheese":126,"cocoa":164,"spicy":98},"coated":{"caramel":16,"cheese":28,"cocoa":24,"spicy":16},"ingredients":78,"minutes":3.0083 |
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
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2030,"heap_start":10214825,"heap_after_60s":11945765,"burst":{"fps":48.756218905472636,"draw_calls":117,"primitives":4303,"fx_peak":153,"fx_cap":400},"sleep":{"before":3155,"hidden_5s":3176,"after_wake": |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":179,"primitives":5345,"fx":44},"fps":[46.784789948390426,46.36022883325852,46.74291397314769,47.88985332821085,47.53416517224557,47.80400356713895],"median_fps":47.53416517224557,"heap_start" |
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
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | p720 | PASSED |  |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | p720 | PASSED |  |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | phone | PASSED | device: phone chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | phone | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | phone | SKIPPED | desktop measures |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | phone | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | phone | SKIPPED | one project |
| release12.spec.mjs | stand: saved across a reload, written when hidden, two taps to restart | desktop | PASSED | device: desktop chromium Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36 |
| release12.spec.mjs | plays on offline once loaded; follows reduce motion | desktop | SKIPPED | one project |
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 62190 ms |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | desktop | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | desktop | SKIPPED | one project |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | p720 | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | phone | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | desktop | PASSED |  |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | p720 | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.224 peak 0.792 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.231 peak 0.803; top stand rms 0.224 peak 0.774 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.225 peak 0.831 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1551 ms, game judged 1592 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1551 ms, game judged 1589 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1553 ms, game judged 1570 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 1992 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2192 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2032 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | desktop | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | desktop | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | desktop | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-p720 | PASSED | sizes: money 76 px tall, icon buttons 84 px, upgrade 520x166 px (CSS) |
| responsive07.spec.mjs | factory: floors fit, ring in the kitchen, nothing overlaps | m-p720 | PASSED | sizes: ring 332 CSS px, floors 218/191/476 CSS px tall |
| responsive07.spec.mjs | reduced motion and sound off still play | m-p720 | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-p720 | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-hd | PASSED | sizes: money 83 px tall, icon buttons 92 px, upgrade 571x140 px (CSS) |
| responsive07.spec.mjs | factory: floors fit, ring in the kitchen, nothing overlaps | m-hd | PASSED | sizes: ring 342 CSS px, floors 224/195/489 CSS px tall |
| responsive07.spec.mjs | reduced motion and sound off still play | m-hd | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-hd | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-small | PASSED | sizes: money 38 px tall, icon buttons 42 px, upgrade 260x83 px (CSS) |
| responsive07.spec.mjs | factory: floors fit, ring in the kitchen, nothing overlaps | m-small | PASSED | sizes: ring 166 CSS px, floors 109/95/238 CSS px tall |
| responsive07.spec.mjs | reduced motion and sound off still play | m-small | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-small | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-tablet | PASSED | sizes: money 61 px tall, icon buttons 67 px, upgrade 416x133 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-tablet | PASSED | sizes: money 61 px tall, icon buttons 67 px, upgrade 416x133 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-tablet | PASSED | sizes: money 61 px tall, icon buttons 67 px, upgrade 416x133 px (CSS) |
| responsive07.spec.mjs | factory: floors fit, ring in the kitchen, nothing overlaps | m-tablet | PASSED | sizes: ring 266 CSS px, floors 175/153/381 CSS px tall |
| responsive07.spec.mjs | reduced motion and sound off still play | m-tablet | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-tablet | PASSED |  |
| responsive07.spec.mjs | click: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | perfect: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | explosion: fits, no overlaps, readable | m-landscape | PASSED | sizes: money 30 px tall, icon buttons 33 px, upgrade 206x51 px (CSS) |
| responsive07.spec.mjs | factory: floors fit, ring in the kitchen, nothing overlaps | m-landscape | PASSED | sizes: ring 123 CSS px, floors 81/71/177 CSS px tall |
| responsive07.spec.mjs | reduced motion and sound off still play | m-landscape | PASSED |  |
| responsive07.spec.mjs | stand: card, shakers and helper fit | m-landscape | PASSED |  |
