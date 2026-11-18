# Popcorn test report (AUTOMATED)

- git f735656db781 · build 0.42.0 game-9a85a56f9308.pck
- 2026-11-18T22:12:44.386Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (308 passed, 0 failed, 22589 checks, 20 files, 344.8s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **PASSED** — passed 247 (on retry 1), failed 0, skipped 35

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | p720 | PASSED | art: {"kettle":{"sat":0.32,"lumStd":54.97,"skyShare":0.086,"vivid":0.328},"wall":{"sat":0.338,"lumStd":7.49,"skyShare":0,"vivid":0},"shop_window":{"sat":0.234,"lumStd":43,"skyShare":0.616,"vivid":0.001},"tiles":{"sat":0. |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | p720 | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.4,"skyShare":0,"vivid":0},"rich":{"sat":0.733,"lumStd":38.32,"skyShare":0.014,"vivid":0.875}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | phone | PASSED | art: {"kettle":{"sat":0.328,"lumStd":55.38,"skyShare":0.082,"vivid":0.331},"wall":{"sat":0.345,"lumStd":7.3,"skyShare":0,"vivid":0},"shop_window":{"sat":0.228,"lumStd":43.97,"skyShare":0.603,"vivid":0.005},"tiles":{"sat" |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | phone | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.23,"skyShare":0,"vivid":0},"rich":{"sat":0.732,"lumStd":37.32,"skyShare":0.015,"vivid":0.876}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | desktop | PASSED | art: {"kettle":{"sat":0.324,"lumStd":54.61,"skyShare":0.084,"vivid":0.329},"wall":{"sat":0.331,"lumStd":7.32,"skyShare":0,"vivid":0},"shop_window":{"sat":0.218,"lumStd":36.93,"skyShare":0.654,"vivid":0},"tiles":{"sat":0. |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | desktop | PASSED | card: {"poor":{"sat":0.052,"lumStd":31.47,"skyShare":0,"vivid":0},"rich":{"sat":0.727,"lumStd":38.75,"skyShare":0.014,"vivid":0.869}} |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | p720 | PASSED | cast: {"worst_iou":0.507,"pair":"heat~upkeep","ink":{"heat":150,"news":241,"pack_rate":0,"perfect":107,"pop_rate":0,"queue":118,"sales":0,"sign_up":156,"stock":250,"trophy":0,"upkeep":25},"mean":{"heat":[184,85,45],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | p720 | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.4,"most":14,"looks":13,"stats":{"delight":13,"happy":48,"receive":110,"thanks":49},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | phone | PASSED | cast: {"worst_iou":0.531,"pair":"heat~upkeep","ink":{"heat":183,"news":281,"pack_rate":0,"perfect":126,"pop_rate":0,"queue":137,"sales":0,"sign_up":159,"stock":312,"trophy":0,"upkeep":28},"mean":{"heat":[182,85,44],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | phone | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.5,"most":14,"looks":14,"stats":{"delight":10,"happy":45,"receive":110,"thanks":55},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | desktop | PASSED | cast: {"worst_iou":0.553,"pair":"news~queue","ink":{"heat":71,"news":157,"pack_rate":0,"perfect":48,"pop_rate":0,"queue":53,"sales":0,"sign_up":82,"stock":111,"trophy":0,"upkeep":17},"mean":{"heat":[184,86,44],"news":[13 |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | desktop | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.4,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":13,"stats":{"delight":15,"happy":49,"receive":109,"thanks":45},"hits":[]},"render":{"draw_calls" |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | p720 | PASSED | real3min: {"firstSale":9373,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | p720 | PASSED | sign: [{"tier":6,"warm":0,"px":8784},{"tier":7,"warm":661,"px":8784},{"tier":8,"warm":1305,"px":8784}]; money: {"rect":[120,34,390,76],"outside_one":114,"outside_seven":114} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | phone | SKIPPED | p720 is the portrait touch run; three real minutes each |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | phone | PASSED | sign: [{"tier":6,"warm":0,"px":17680},{"tier":7,"warm":967,"px":17680},{"tier":8,"warm":1638,"px":17680}]; money: {"rect":[65,18.4184856414795,211.25,41.1707305908203],"outside_one":2474,"outside_seven":2420} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | desktop | PASSED | real3min: {"firstSale":9399,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | desktop | PASSED | sign: [{"tier":6,"warm":0,"px":5143},{"tier":7,"warm":312,"px":5143},{"tier":8,"warm":591,"px":5143}]; money: {"rect":[477.5,21.125,325,58.5],"outside_one":0,"outside_seven":0} |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":134100,"leftHidden":134050}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.1,"packs":136,"tier":2,"prize":120,"overfill":4,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135350,"leftHidden":135300}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":1.3,"packs":136,"tier":2,"prize":120,"overfill":6,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135600,"leftHidden":135550}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.3,"packs":137,"tier":3,"prize":240,"overfill":1,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"caramel","gold":[1100,1450],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3452,"goldPre":3440,"turned":843,"area":[448.5599975585934,301.07031860351617,145.08004 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"caramel","gold":[1100,1450],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":4705,"goldPre":4143,"turned":1353,"area":[485.9400024414065,378.80126953125017,157.1700 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED (on retry) |  |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | p720 | PASSED | cast: {"arrived_who":{"classic":13,"elder":2,"kid":7,"student":13},"passed_by_who":{"kid":8,"rush":13},"sold":30,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":170,"thanks":true,"flavor_sold |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | phone | PASSED | cast: {"arrived_who":{"classic":17,"elder":2,"kid":6,"student":13},"passed_by_who":{"kid":12,"rush":15,"student":4},"sold":32,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":1035,"thanks":tru |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | desktop | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":9,"student":13},"passed_by_who":{"kid":6,"rush":13},"sold":31,"happy":31,"popularity":[50.4,56.2],"stars":3,"favorite":"plain","studentPx":94,"thanks":true,"flavor_sold" |
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
| factory16.spec.mjs | idle memory: the factory keeps far less than the stand | desktop | PASSED | memory: idle, kept JS heap after GC: factory 0.31 MB/min, stand 0.97 MB/min |
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
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":48,"auto_lots":57,"premium_lots":24,"premium_sold":40,"sorted":16,"dispatch_held_ms":184400,"vent_saves":0,"upkeep":66,"kernels":104} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":55,"auto_lots":63,"premium_lots":19,"premium_sold":32,"sorted":15,"dispatch_held_ms":168100,"vent_saves":0,"upkeep":70,"kernels":117} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":49,"auto_lots":57,"premium_lots":22,"premium_sold":37,"sorted":16,"dispatch_held_ms":181150,"vent_saves":0,"upkeep":66,"kernels":105} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[19.988007188062344,19.18281219324989,19.476093084872616,18.51851851851852,19.175455417066157,18.730283918715532],"median":19.18281219324989,"heap0":16252143,"heap1":25047839,"kept_mb":8.795696,"draw_calls": |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":36} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":19,"small":29,"large":13,"bagger":23,"cup_feeder":20,"packed":69,"upkeep":33} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":14,"small":27,"large":20,"bagger":26,"cup_feeder":15,"packed":69,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[21.5,20.1,19.6,19.2,18.6,18.9],"median":19.62130873762144,"packers_running":[1,2,2,2,2,2],"draw_calls":[698,744,804,861,866,904],"objects":[1105,1149,1226,1263,1270,1321],"load":13.72} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":107,"cashier":54,"express":50,"routed":0,"express_jumped":7,"lanes":4,"lost":49,"upkeep":70,"revenue":1230} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":110,"cashier":59,"express":48,"routed":3,"express_jumped":6,"lanes":4,"lost":51,"upkeep":74,"revenue":1277} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":106,"cashier":55,"express":48,"routed":4,"express_jumped":7,"lanes":4,"lost":46,"upkeep":70,"revenue":1233} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":8,"moved":3,"line_portions":[1,0,0]}; hidden: |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":45,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":9,"before_kitchen_pause":7,"moved":1,"line_portions":[2,0,3]}; hidden:  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | PASSED | layout: {"smallest_place_px":21,"window":[1280,800]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":8,"moved":3,"line_portions":[0,0,0]}; hidden: |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":921,"cheese":1177,"spicy":1202,"caramel":1034,"cocoa":697},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":2,"cheese":5,"cocoa":1,"spicy":2},"revenue":{"caramel":34,"cheese":65,"cocoa":34,"spicy":28},"coated":{"caramel":8,"cheese":20,"cocoa":4,"spicy":4},"ingredients":31,"minutes":3.1908333333 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2253,"cheese":2679,"spicy":2747,"caramel":2362,"cocoa":1989},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":7,"cocoa":3,"spicy":2},"revenue":{"caramel":85,"cheese":84,"cocoa":70,"spicy":28},"coated":{"caramel":18,"cheese":20,"cocoa":8,"spicy":4},"ingredients":49,"minutes":3.324166666 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":1885,"cheese":1389,"spicy":1437,"caramel":1248,"cocoa":1055},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":7,"cocoa":2,"spicy":2},"revenue":{"caramel":98,"cheese":79,"cocoa":64,"spicy":28},"coated":{"caramel":18,"cheese":24,"cocoa":8,"spicy":4},"ingredients":47,"minutes":3.1275,"sol |
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
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.3451333333333,7.93646666666665,3.08513333333333],"tier":"solo"}; celebrate: {"climb":[0.0492222222222222,0.220296296296296,0.36162962962963,0.507407407407407,0.655296296296296,0.795074074074074,0.943, |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":38,"alive":18,"given":{"ambient":99,"lot":29,"sparkle":28},"low":true,"fps":11.2},{"t":19,"running":32,"alive":17,"given":{"ambient":120,"lot":42,"sparkle":39},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":56,"secs":13.877,"phase":[[48.65,48.65,48.65,14.79,0,48.65],[465.98,465.98,465.98,382.53,333.52,465.98]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.594,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.7212676666667,8.33756766666668,3.45],"tier":"solo"}; celebrate: {"climb":[0.0565544444444444,0.178666666666667,0.289777777777778,0.400888888888889,0.525666666666667,0.649727283950617,0.773184074074074 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":38,"alive":21,"given":{"ambient":90,"lot":30,"sparkle":28},"low":true,"fps":10.2},{"t":19,"running":33,"alive":13,"given":{"ambient":110,"lot":43,"sparkle":41},"low":true,"fps":10. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":57,"secs":14.093,"phase":[[56.98,56.98,56.98,16.41,0,56.98],[561.08,561.08,561.08,462.88,406.31,561.08]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.756,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.3918228095238,7.99814814814814,3.14664242424242],"tier":"solo"}; celebrate: {"climb":[0.0427407407407409,0.181148148148148,0.324971193415638,0.470259259259259,0.613645353535354,0.762814814814815,0.915 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":37,"alive":15,"given":{"ambient":98,"lot":29,"sparkle":28},"low":true,"fps":10.8},{"t":19,"running":32,"alive":18,"given":{"ambient":119,"lot":42,"sparkle":39},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":56,"secs":13.852,"phase":[[45.5,45.5,45.5,14.15,0,45.5],[436.51,436.51,436.51,360.22,316.85,436.51]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","ba |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.469,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1559,"unread":1,"marks":1}; hidden: {"left0":113000,"leftHidden":112950}; craze: {"row":{"asked":13,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1953,"unread":1,"marks":1}; hidden: {"left0":112500,"leftHidden":112400}; craze: {"row":{"asked":15,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":113300,"leftHidden":113250}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2034,"heap_start":10406009,"heap_after_60s":12342953,"burst":{"fps":49.67709885742673,"draw_calls":117,"primitives":4303,"fx_peak":151,"fx_cap":400},"sleep":{"before":3167,"hidden_5s":3187,"after_wake":4 |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":179,"primitives":5347,"fx":44},"fps":[47.21621092565152,48.095799015208264,47.83735297252068,48.337772480143244,47.02655041537142,46.55770183259039],"median_fps":47.83735297252068,"heap_start |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 63174 ms |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | desktop | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | desktop | SKIPPED | one project |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | p720 | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | phone | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | desktop | PASSED |  |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | p720 | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.229 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1551 ms, game judged 1604 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1551 ms, game judged 1614 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1551 ms, game judged 1563 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 2070 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2240 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2064 ms to the first drawn frame |
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
