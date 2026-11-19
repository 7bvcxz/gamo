# Popcorn test report (AUTOMATED)

- git feb469e2a5a1 (uncommitted changes) · build 0.44.0 game-54f215a65e98.pck
- 2026-11-19T19:58:31.279Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (325 passed, 0 failed, 22865 checks, 23 files, 551.8s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **FAILED** — passed 263 (on retry 0), failed 1, skipped 39

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | p720 | PASSED | art: {"kettle":{"sat":0.32,"lumStd":54.98,"skyShare":0.086,"vivid":0.328},"wall":{"sat":0.338,"lumStd":7.49,"skyShare":0,"vivid":0},"shop_window":{"sat":0.235,"lumStd":43.26,"skyShare":0.61,"vivid":0},"tiles":{"sat":0.03 |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | p720 | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.4,"skyShare":0,"vivid":0},"rich":{"sat":0.73,"lumStd":38.64,"skyShare":0.014,"vivid":0.874}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | phone | PASSED | art: {"kettle":{"sat":0.328,"lumStd":55.64,"skyShare":0.083,"vivid":0.337},"wall":{"sat":0.345,"lumStd":7.3,"skyShare":0,"vivid":0},"shop_window":{"sat":0.229,"lumStd":43.88,"skyShare":0.606,"vivid":0.005},"tiles":{"sat" |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | phone | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.23,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":37.26,"skyShare":0.014,"vivid":0.87}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | desktop | PASSED | art: {"kettle":{"sat":0.324,"lumStd":54.76,"skyShare":0.083,"vivid":0.329},"wall":{"sat":0.331,"lumStd":7.32,"skyShare":0,"vivid":0},"shop_window":{"sat":0.218,"lumStd":36.93,"skyShare":0.655,"vivid":0},"tiles":{"sat":0. |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | desktop | PASSED | card: {"poor":{"sat":0.052,"lumStd":31.47,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":38.8,"skyShare":0.014,"vivid":0.872}} |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | p720 | PASSED | cast: {"worst_iou":0.507,"pair":"heat~upkeep","ink":{"heat":150,"news":241,"pack_rate":0,"perfect":107,"pop_rate":0,"queue":118,"sales":0,"sign_up":156,"stock":250,"trophy":0,"upkeep":25},"mean":{"heat":[184,85,45],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | p720 | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":14,"stats":{"delight":15,"happy":49,"receive":109,"thanks":45},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | phone | PASSED | cast: {"worst_iou":0.531,"pair":"heat~upkeep","ink":{"heat":183,"news":281,"pack_rate":0,"perfect":126,"pop_rate":0,"queue":137,"sales":0,"sign_up":159,"stock":312,"trophy":0,"upkeep":28},"mean":{"heat":[182,85,44],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | phone | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.5,"most":14,"looks":13,"stats":{"delight":8,"happy":49,"receive":110,"thanks":53},"hits":[]},"render":{"draw_calls": |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | desktop | PASSED | cast: {"worst_iou":0.553,"pair":"news~queue","ink":{"heat":71,"news":157,"pack_rate":0,"perfect":48,"pop_rate":0,"queue":53,"sales":0,"sign_up":82,"stock":111,"trophy":0,"upkeep":17},"mean":{"heat":[184,86,44],"news":[13 |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | desktop | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.4,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":14,"stats":{"delight":17,"happy":52,"receive":109,"thanks":40},"hits":[]},"render":{"draw_calls" |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | p720 | PASSED | real3min: {"firstSale":9392,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":0.9999,"revenue":1 |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | p720 | PASSED | sign: [{"tier":6,"warm":0,"px":8784},{"tier":7,"warm":661,"px":8784},{"tier":8,"warm":1318,"px":8784}]; money: {"rect":[120,34,298,76],"outside_one":88,"outside_seven":88} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | phone | SKIPPED | p720 is the portrait touch run; three real minutes each |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | phone | PASSED | sign: [{"tier":6,"warm":0,"px":17680},{"tier":7,"warm":962,"px":17680},{"tier":8,"warm":1675,"px":17680}]; money: {"rect":[65,18.4184856414795,161.4166717529295,41.1707305908203],"outside_one":2256,"outside_seven":1213} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | desktop | PASSED | real3min: {"firstSale":9426,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | desktop | PASSED | sign: [{"tier":6,"warm":0,"px":5143},{"tier":7,"warm":312,"px":5143},{"tier":8,"warm":591,"px":5143}]; money: {"rect":[477.5,21.125,325,58.5],"outside_one":0,"outside_seven":0} |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":134950,"leftHidden":134900}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.4,"packs":135,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135800,"leftHidden":135750}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":0.5,"packs":137,"tier":3,"prize":240,"overfill":3,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135450,"leftHidden":135450}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":1.6,"packs":136,"tier":2,"prize":120,"overfill":7,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3576,"goldPre":3265,"turned":807,"area":[448.5599975585934,301.07031860351617,145.08004760 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":5469,"goldPre":4008,"turned":1921,"area":[485.9400024414065,378.80126953125017,157.1700439 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":2927,"goldPre":2256,"turned":910,"area":[477.9150390625,221.80137939453132,170.03247070312 |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | p720 | PASSED | cast: {"arrived_who":{"classic":15,"elder":2,"kid":6,"student":13},"passed_by_who":{"kid":10,"rush":13},"sold":31,"happy":30,"popularity":[50.4,56],"stars":3,"favorite":"plain","studentPx":156,"thanks":true,"flavor_sold" |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | phone | PASSED | cast: {"arrived_who":{"classic":13,"elder":2,"kid":7,"student":13},"passed_by_who":{"kid":8,"rush":13},"sold":30,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":452,"thanks":true,"flavor_sold |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | desktop | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":9,"student":13},"passed_by_who":{"kid":6,"rush":13},"sold":31,"happy":30,"popularity":[50.4,56],"stars":3,"favorite":"plain","studentPx":88,"thanks":true,"flavor_sold":{ |
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
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":52,"auto_lots":55,"premium_lots":20,"premium_sold":32,"sorted":15,"dispatch_held_ms":184600,"vent_saves":0,"upkeep":63,"kernels":107} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":55,"auto_lots":60,"premium_lots":22,"premium_sold":37,"sorted":15,"dispatch_held_ms":162850,"vent_saves":0,"upkeep":69,"kernels":113} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":49,"auto_lots":56,"premium_lots":22,"premium_sold":37,"sorted":15,"dispatch_held_ms":178050,"vent_saves":0,"upkeep":66,"kernels":105} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[19.45336057886519,18.817470521584045,18.977227330822632,18.26923076923077,18.60374032747637,18.225419664268586],"median":18.817470521584045,"heap0":22316681,"heap1":30895657,"kept_mb":8.578976,"draw_calls": |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":36} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":19,"small":29,"large":13,"bagger":21,"cup_feeder":20,"packed":69,"upkeep":31} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":14,"small":27,"large":20,"bagger":26,"cup_feeder":15,"packed":69,"upkeep":34} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[21.1,20.4,19.9,20,19,18.4],"median":20.017157556347403,"packers_running":[3,2,2,2,2,3],"draw_calls":[654,711,724,789,825,872],"objects":[1046,1113,1149,1193,1236,1289],"load":11.16} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":109,"cashier":59,"express":47,"routed":3,"express_jumped":9,"lanes":4,"lost":48,"upkeep":70,"revenue":1265} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":110,"cashier":59,"express":48,"routed":0,"express_jumped":8,"lanes":4,"lost":50,"upkeep":71,"revenue":1278} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":106,"cashier":56,"express":47,"routed":2,"express_jumped":8,"lanes":4,"lost":47,"upkeep":70,"revenue":1243} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":7,"moved":3,"line_portions":[0,0,2]}; hidden: {"before |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":52,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":6,"moved":2,"line_portions":[4,0,2]}; hidden: |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | FAILED | Error: frame rate with forty-four machines (load 5.3)  expect(received).toBeGreaterThan(expected)  Expected: > 20 Received:   13.853156548512606 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":914,"cheese":1172,"spicy":1196,"caramel":1034,"cocoa":702},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":2,"cheese":5,"cocoa":1,"spicy":3},"revenue":{"caramel":34,"cheese":65,"cocoa":34,"spicy":53},"coated":{"caramel":8,"cheese":16,"cocoa":4,"spicy":8},"ingredients":28,"minutes":3.19,"sold_t |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2268,"cheese":2681,"spicy":2744,"caramel":2381,"cocoa":2017},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":4,"cocoa":2,"spicy":1},"revenue":{"caramel":96,"cheese":48,"cocoa":55,"spicy":14},"coated":{"caramel":18,"cheese":16,"cocoa":12,"spicy":4},"ingredients":51,"minutes":3.40333333 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":1873,"cheese":1391,"spicy":1441,"caramel":1247,"cocoa":1059},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":7,"cocoa":2,"spicy":4},"revenue":{"caramel":98,"cheese":90,"cocoa":52,"spicy":58},"coated":{"caramel":18,"cheese":28,"cocoa":8,"spicy":12},"ingredients":55,"minutes":3.135,"sol |
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
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.2909555555556,7.89293333333334,3.01526666666667],"tier":"solo"}; celebrate: {"climb":[0.0483185714285714,0.198465608465608,0.344244497354497,0.494849435626102,0.654391534391534,0.804318571428571,0.945 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":30,"alive":19,"given":{"ambient":97,"lot":29,"sparkle":28},"low":true,"fps":12.4},{"t":19,"running":26,"alive":15,"given":{"ambient":114,"lot":30,"sparkle":42},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":48,"secs":13.377,"phase":[[47.77,47.77,47.77,30.4,0,47.77],[451.03,422.14,451.03,370.3,321.96,451.03]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start"," |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.283,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.6965484848485,8.27509999999998,3.42596666666667],"tier":"solo"}; celebrate: {"climb":[0.0611111111111111,0.186777777777778,0.300666666666667,0.414555555555556,0.538777777777778,0.662666666666667,0.788 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":31,"alive":22,"given":{"ambient":89,"lot":30,"sparkle":28},"low":true,"fps":11.6},{"t":19,"running":31,"alive":35,"given":{"ambient":108,"lot":31,"sparkle":43},"low":true,"fps":10. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":49,"secs":14.052,"phase":[[56.92,56.92,56.92,16.14,0,56.92],[562.67,527.16,562.67,462.69,405.45,562.67]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":14.035,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.35,7.93343333333334,3.08484848484848],"tier":"solo"}; celebrate: {"climb":[0.0425925925925926,0.187486772486772,0.33526455026455,0.500597883597884,0.659116402116402,0.813116402116402,0.956338624338624 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":29,"alive":17,"given":{"ambient":98,"lot":29,"sparkle":28},"low":true,"fps":11.5},{"t":19,"running":27,"alive":37,"given":{"ambient":117,"lot":31,"sparkle":43},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":48,"secs":13.665,"phase":[[44.88,44.88,44.88,13.8,0,44.88],[430.77,408.27,430.77,353.36,307.11,430.77]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start", |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.67,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"], |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1543,"unread":1,"marks":1}; hidden: {"left0":112900,"leftHidden":112850}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1869,"unread":1,"marks":1}; hidden: {"left0":112500,"leftHidden":112400}; craze: {"row":{"asked":15,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":113250,"leftHidden":113200}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2050,"heap_start":10658161,"heap_after_60s":12593193,"burst":{"fps":49.82561036372696,"draw_calls":117,"primitives":4293,"fx_peak":155,"fx_cap":400},"sleep":{"before":3092,"hidden_5s":3113,"after_wake":4 |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":179,"primitives":5345,"fx":44},"fps":[46.59462675610907,48.10524247167613,46.80342562131751,47.360631475086336,47.327943215368855,48.62075807772011],"median_fps":47.360631475086336,"heap_star |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 64061 ms |
| release12.spec.mjs | the game page asks browsers not to translate it (a Korean phone offered to, over the coins) | desktop | SKIPPED | one project |
| release12.spec.mjs | the about page: links to the game, privacy and licences, nothing loaded from elsewhere | desktop | SKIPPED | one project |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | p720 | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | phone | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | desktop | PASSED |  |
| soak43.spec.mjs | the control: the sound off plays nothing | p720 | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | p720 | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the control: the sound off plays nothing | phone | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | phone | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the control: the sound off plays nothing | desktop | PASSED | serial: undefined; soak: [{"t":33,"pops":4,"blocked":7,"rms":0,"peak":0,"mean_rms":0,"buffers":0,"copies":0,"copy_mb":0,"sources":0,"heap_mb":48.1,"renderer_mb":339,"fps":13,"static_mb":0,"voices_peak":0,"beds":0,"bed_st |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | desktop | PASSED | serial: undefined; soak: [{"t":35,"pops":4,"blocked":8,"rms":0.1681,"peak":0.485,"mean_rms":0.0189,"buffers":16,"copies":179,"copy_mb":69.7,"sources":179,"heap_mb":77.6,"renderer_mb":401,"fps":12,"static_mb":0,"voices_pe |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | p720 | PASSED | mix: fresh perfect rms 0.224 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.225 peak 0.761 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.224 peak 0.764 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | p720 | PASSED | mix: {"one":{"rms":0.04588119407415607,"peak":0.10349559783935547,"mean_rms":0.004870106041678095},"forty":{"rms":0.04922050727272974,"peak":0.12266578525304794,"mean_rms":0.01268935401661931},"hand":{"rms":0.16791173238 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | p720 | PASSED | pan: {"left":{"left":0.06200622515992788,"right":0.043536962708651934,"energy_left":19.26254892968288,"energy_right":9.534829711924587,"frames":43648,"mean_rms":0.01816265385536303},"right":{"left":0.04353333716361319,"r |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | p720 | PASSED | hidden: {"before":{"rms":0.0364900968321283,"peak":0.06567420065402985},"hidden":{"rms":0,"peak":0},"after":{"rms":0.05206712087549557,"peak":0.15168654918670654},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | p720 | PASSED | calm: {"loud":{"rms":0.034352492715738966,"peak":0.07026497274637222},"calmFloor":{"rms":0.023585763643278548,"peak":0.05711142718791962},"calmHand":{"rms":0.08335740331976854,"peak":0.24017444252967834},"popped":true,"b |
| sound43.spec.mjs | one sale, one cash sound | p720 | PASSED | cash: {"sold":33,"asked":33,"played":24} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | phone | PASSED | mix: {"one":{"rms":0.04585168091659133,"peak":0.10277015715837479,"mean_rms":0.00483316520009923},"forty":{"rms":0.059732926952665265,"peak":0.15701861679553986,"mean_rms":0.012956557171253606},"hand":{"rms":0.1698972699 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | phone | PASSED | pan: {"left":{"left":0.061991090341508064,"right":0.04352707027739383,"energy_left":19.409632142105245,"energy_right":9.771678116125315,"frames":44544,"mean_rms":0.01809850863832838},"right":{"left":0.043570610927561065, |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | phone | PASSED | hidden: {"before":{"rms":0.03328097941290696,"peak":0.06134248897433281},"hidden":{"rms":0,"peak":0},"after":{"rms":0.0517563864567687,"peak":0.13763366639614105},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | phone | PASSED | calm: {"loud":{"rms":0.03412316401933154,"peak":0.07786774635314941},"calmFloor":{"rms":0.023166700242092917,"peak":0.05440063774585724},"calmHand":{"rms":0.08368718720116433,"peak":0.2255556732416153},"popped":true,"bed |
| sound43.spec.mjs | one sale, one cash sound | phone | PASSED | cash: {"sold":31,"asked":31,"played":23} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | desktop | PASSED | mix: {"one":{"rms":0.04591379729726493,"peak":0.10102313756942749,"mean_rms":0.004875901252181408},"forty":{"rms":0.04838802648458831,"peak":0.11606873571872711,"mean_rms":0.012162664342680218},"hand":{"rms":0.1685582175 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | desktop | PASSED | pan: {"left":{"left":0.06191952926912919,"right":0.043456361265048364,"energy_left":19.22154049090177,"energy_right":9.506527442330032,"frames":43648,"mean_rms":0.01814078337878096},"right":{"left":0.04361457116043018,"r |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | desktop | PASSED | hidden: {"before":{"rms":0.03456991573010964,"peak":0.07765965163707733},"hidden":{"rms":0,"peak":0},"after":{"rms":0.051217098205887296,"peak":0.1365775763988495},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | desktop | PASSED | calm: {"loud":{"rms":0.036998509440221566,"peak":0.07387271523475647},"calmFloor":{"rms":0.02334938498049493,"peak":0.05589177832007408},"calmHand":{"rms":0.08431967680382056,"peak":0.22073504328727722},"popped":true,"be |
| sound43.spec.mjs | one sale, one cash sound | desktop | PASSED | cash: {"sold":33,"asked":33,"played":24} |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1550 ms, game judged 1590 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1552 ms, game judged 1581 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1552 ms, game judged 1553 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 2057 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2212 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2056 ms to the first drawn frame |
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
