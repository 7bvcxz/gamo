# Popcorn test report (AUTOMATED)

- git 6e5c4fbbee52 (uncommitted changes) · build 0.46.1 game-9b307aed1bd5.pck
- 2026-11-21T22:03:37.589Z
- target: local docs/ (http://127.0.0.1)
- headless: **PASSED** (348 passed, 0 failed, 24082 checks, 28 files, 678.4s)
- deploy: **PASSED**
- browser: **PASSED** — passed 310 (on retry 0), failed 0, skipped 58

- mode: **full**, 44 specs · load 2.66 6.67 6.89 → 8.49 9.67 9.61 · free memory 28624 → 33123 MB
- not run (SKIPPED, with why): perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | p720 | PASSED | art: {"kettle":{"sat":0.32,"lumStd":54.99,"skyShare":0.085,"vivid":0.327},"wall":{"sat":0.338,"lumStd":7.49,"skyShare":0,"vivid":0},"shop_window":{"sat":0.236,"lumStd":43.14,"skyShare":0.61,"vivid":0},"tiles":{"sat":0.03 |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | p720 | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.4,"skyShare":0,"vivid":0},"rich":{"sat":0.733,"lumStd":38.68,"skyShare":0.014,"vivid":0.878}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | phone | PASSED | art: {"kettle":{"sat":0.326,"lumStd":55.34,"skyShare":0.083,"vivid":0.334},"wall":{"sat":0.345,"lumStd":7.3,"skyShare":0,"vivid":0},"shop_window":{"sat":0.229,"lumStd":43.49,"skyShare":0.607,"vivid":0.004},"tiles":{"sat" |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | phone | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.23,"skyShare":0,"vivid":0},"rich":{"sat":0.731,"lumStd":36.37,"skyShare":0.015,"vivid":0.872}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | desktop | PASSED | art: {"kettle":{"sat":0.329,"lumStd":55.18,"skyShare":0.083,"vivid":0.336},"wall":{"sat":0.331,"lumStd":7.32,"skyShare":0,"vivid":0},"shop_window":{"sat":0.219,"lumStd":36.79,"skyShare":0.656,"vivid":0},"tiles":{"sat":0. |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | desktop | PASSED | card: {"poor":{"sat":0.052,"lumStd":31.47,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":38.8,"skyShare":0.014,"vivid":0.872}} |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | p720 | PASSED | cast: {"worst_iou":0.507,"pair":"heat~upkeep","ink":{"heat":150,"news":241,"pack_rate":0,"perfect":107,"pop_rate":0,"queue":118,"sales":0,"sign_up":156,"stock":250,"trophy":0,"upkeep":25},"mean":{"heat":[184,85,45],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | p720 | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":14,"stats":{"delight":11,"happy":55,"receive":109,"thanks":43},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | phone | PASSED | cast: {"worst_iou":0.531,"pair":"heat~upkeep","ink":{"heat":183,"news":281,"pack_rate":0,"perfect":126,"pop_rate":0,"queue":137,"sales":0,"sign_up":159,"stock":312,"trophy":0,"upkeep":28},"mean":{"heat":[182,85,44],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | phone | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.5,"most":14,"looks":13,"stats":{"delight":11,"happy":45,"receive":110,"thanks":54},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | desktop | PASSED | cast: {"worst_iou":0.553,"pair":"news~queue","ink":{"heat":71,"news":157,"pack_rate":0,"perfect":48,"pop_rate":0,"queue":53,"sales":0,"sign_up":82,"stock":111,"trophy":0,"upkeep":17},"mean":{"heat":[184,86,44],"news":[13 |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | desktop | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.4,"sign":2,"people":0,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":13,"stats":{"delight":12,"happy":55,"receive":109,"thanks":42},"hits":[]},"render":{"draw_calls" |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | p720 | PASSED | real3min: {"firstSale":9407,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | p720 | PASSED | sign: [{"tier":6,"warm":0,"px":8784},{"tier":7,"warm":661,"px":8784},{"tier":8,"warm":1670,"px":8784}]; money: {"rect":[120,34,298,76],"outside_one":88,"outside_seven":88} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | phone | SKIPPED | p720 is the portrait touch run; three real minutes each |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | phone | PASSED | sign: [{"tier":6,"warm":0,"px":17680},{"tier":7,"warm":1646,"px":17680},{"tier":8,"warm":2301,"px":17680}]; money: {"rect":[65,18.4184856414795,161.4166717529295,41.1707305908203],"outside_one":2256,"outside_seven":1213} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | desktop | PASSED | real3min: {"firstSale":9247,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | desktop | PASSED | sign: [{"tier":6,"warm":0,"px":5143},{"tier":7,"warm":312,"px":5143},{"tier":8,"warm":591,"px":5143}]; money: {"rect":[477.5,21.125,325,58.5],"outside_one":0,"outside_seven":0} |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136550,"leftHidden":136500}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.4,"packs":136,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135550,"leftHidden":135500}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":1.3,"packs":135,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135750,"leftHidden":135750}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.5,"packs":138,"tier":3,"prize":240,"overfill":2,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3652,"goldPre":3069,"turned":1062,"area":[448.5599975585934,301.07031860351617,145.0800476 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":4314,"goldPre":3582,"turned":1003,"area":[485.9400024414065,378.80126953125017,157.1700439 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":2595,"goldPre":2201,"turned":580,"area":[477.9150390625,221.80137939453132,170.03247070312 |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | p720 | PASSED | cast: {"arrived_who":{"classic":13,"elder":2,"kid":7,"student":13},"passed_by_who":{"kid":8,"rush":13},"sold":30,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":160,"thanks":true,"flavor_sold |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | phone | PASSED | cast: {"arrived_who":{"classic":13,"elder":2,"kid":7,"student":13},"passed_by_who":{"kid":8,"rush":13},"sold":30,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":283,"thanks":true,"flavor_sold |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | desktop | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":9,"student":13},"passed_by_who":{"kid":6,"rush":13},"sold":31,"happy":28,"popularity":[50.4,55.6],"stars":3,"favorite":"plain","studentPx":89,"thanks":true,"flavor_sold" |
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
| factory16.spec.mjs | idle memory: the factory keeps far less than the stand | desktop | PASSED | memory: idle, kept JS heap after GC: factory 0.16 MB/min, stand 1.11 MB/min |
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
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":51,"auto_lots":55,"premium_lots":20,"premium_sold":32,"sorted":15,"dispatch_held_ms":173900,"vent_saves":0,"upkeep":66,"kernels":105} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":54,"auto_lots":60,"premium_lots":21,"premium_sold":35,"sorted":16,"dispatch_held_ms":160600,"vent_saves":0,"upkeep":68,"kernels":112} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":49,"auto_lots":57,"premium_lots":22,"premium_sold":37,"sorted":16,"dispatch_held_ms":177600,"vent_saves":0,"upkeep":66,"kernels":104} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[20.27027027027027,19.525529626355365,20.132297950647242,20.013342224514208,19.882692124052735,21.65993896242129],"median":20.132297950647242,"heap0":20768114,"heap1":24239531,"kept_mb":3.471417,"draw_calls" |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":19,"small":29,"large":14,"bagger":23,"cup_feeder":20,"packed":71,"upkeep":33} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":33} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[20.8,20,20.4,20,19.9,20.6],"median":20.378457059679768,"packers_running":[3,2,0,2,2,0],"draw_calls":[580,613,581,609,632,585],"objects":[967,996,1007,1006,1035,987],"load":8.93} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":109,"cashier":53,"express":53,"routed":0,"express_jumped":9,"lanes":4,"lost":46,"upkeep":70,"revenue":1248} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":110,"cashier":63,"express":44,"routed":1,"express_jumped":8,"lanes":4,"lost":50,"upkeep":69,"revenue":1267} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":107,"cashier":49,"express":55,"routed":4,"express_jumped":6,"lanes":4,"lost":45,"upkeep":70,"revenue":1236} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":37,"never":["cooker","cooker","kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":["cooker","cooker"]}; lines: {"at_pause":10,"before_kitchen_pause": |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":52,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":["cooker"]}; lines: {"at_pause":11,"before_kitchen_pause":8,"moved":3,"line_ |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | PASSED | layout: {"smallest_place_px":21,"window":[1280,800]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":[]}; lines: {"at_pause":11,"before_kitchen_pause":9,"moved":4,"line_portions":[2,0,1] |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":965,"cheese":1174,"spicy":1196,"caramel":1039,"cocoa":698},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":2,"cheese":5,"cocoa":1,"spicy":2},"revenue":{"caramel":34,"cheese":67,"cocoa":34,"spicy":28},"coated":{"caramel":8,"cheese":16,"cocoa":4,"spicy":8},"ingredients":28,"minutes":3.1683333333 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2150,"cheese":2676,"spicy":2728,"caramel":2293,"cocoa":1919},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":8,"cocoa":3,"spicy":2},"revenue":{"caramel":83,"cheese":90,"cocoa":66,"spicy":28},"coated":{"caramel":15,"cheese":28,"cocoa":8,"spicy":4},"ingredients":47,"minutes":3.291666666 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":1948,"cheese":1392,"spicy":1443,"caramel":1250,"cocoa":1059},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":4,"cheese":9,"cocoa":3,"spicy":1},"revenue":{"caramel":81,"cheese":109,"cocoa":70,"spicy":14},"coated":{"caramel":18,"cheese":24,"cocoa":8,"spicy":4},"ingredients":47,"minutes":3.12333333 |
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
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10130,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10312,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | PASSED | by_hand: {"first_sale_ms":10145,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.3416666666667,7.92253333333333,3.1],"tier":"solo"}; celebrate: {"climb":[0.0474814814814814,0.180703703703704,0.31379012345679,0.741592592592593,0.885829576719577,1,1,1,-1,-1],"moved":0,"celebrations" |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":31,"alive":20,"given":{"ambient":98,"lot":29,"sparkle":28},"low":true,"fps":12.9},{"t":19,"running":27,"alive":47,"given":{"ambient":114,"lot":31,"sparkle":41},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":47,"secs":12.942,"phase":[[48.93,48.93,48.93,15.43,0,48.93],[440.17,429.33,440.17,358.82,312.76,440.17]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":12.909,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.6624,8.29820000000001,3.4394],"tier":"solo"}; celebrate: {"climb":[0.0583333333333333,0.231627572016461,0.343666666666667,0.919691358024692,1,1,-1,-1,-1,-1],"moved":0,"celebrations":1,"kind":"sign"} |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":28,"alive":27,"given":{"ambient":88,"lot":30,"sparkle":28},"low":true,"fps":10.9},{"t":19,"running":28,"alive":39,"given":{"ambient":105,"lot":31,"sparkle":42},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":56,"secs":16.349,"phase":[[58.03,58.03,58.03,37.12,0,58.03],[625.4,585.05,625.4,548.41,491.26,645.5]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","b |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.852,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.4333333333334,8.02444444444446,3.15666666666667],"tier":"solo"}; celebrate: {"climb":[0.0423292181069961,0.179106995884774,0.314106995884774,0.790995884773662,0.934090534979424,1,1,-1,-1,-1],"moved":0 |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":31,"alive":19,"given":{"ambient":97,"lot":29,"sparkle":28},"low":true,"fps":12.2},{"t":19,"running":27,"alive":41,"given":{"ambient":113,"lot":31,"sparkle":41},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":48,"secs":13.183,"phase":[[46.09,46.09,46.09,14.09,0,46.09],[417.44,408.89,417.44,339.84,297.53,417.44]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.178,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
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
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1543,"unread":1,"marks":1}; hidden: {"left0":112550,"leftHidden":112500}; craze: {"row":{"asked":10,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1869,"unread":1,"marks":1}; hidden: {"left0":111550,"leftHidden":111450}; craze: {"row":{"asked":17,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":112750,"leftHidden":112700}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":1269,"heap_start":10686858,"heap_after_60s":12280273,"burst":{"fps":50.6454816285998,"draw_calls":117,"primitives":4301,"fx_peak":151,"fx_cap":400},"sleep":{"before":3249,"hidden_5s":3266,"after_wake":42 |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":177,"primitives":5333,"fx":44},"fps":[46,47.99040192876769,46.71968190854871,44.63842875264588,48.313942032355705,48.3330045282908],"median_fps":47.99040192876769,"heap_start":12325759,"heap_ |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | SKIPPED | measured on the published URL |
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
| save45.spec.mjs | a killed browser loses seconds, never goods: nothing sold twice, every machine there | desktop | PASSED | kill: {"pids":2,"built_clock":31687,"before_kill_clock":38739,"saved_clock":31564,"sold":[14,12,12],"from":"main"} |
| save45.spec.mjs | old builds' saves open: a 0.12.2 stand and a 0.43.0 forty-four-machine factory | desktop | PASSED |  |
| save45.spec.mjs | a broken save is set aside, the backup comes back, and the saves page shows both | desktop | PASSED |  |
| save45.spec.mjs | the saves page exports and imports, and the factory comes back from the file | desktop | PASSED |  |
| save45.spec.mjs | restart takes two taps and the old factory waits in the backup | desktop | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | p720 | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | phone | PASSED |  |
| scorecard09.spec.mjs | scorecard: trial links, saved across a reload, exported as entered, nothing sent | desktop | PASSED |  |
| soak43.spec.mjs | the control: the sound off plays nothing | p720 | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | p720 | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the control: the sound off plays nothing | phone | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | phone | SKIPPED | one long run on the desktop |
| soak43.spec.mjs | the control: the sound off plays nothing | desktop | PASSED | serial: undefined; soak: [{"t":33,"pops":4,"blocked":7,"rms":0,"peak":0,"mean_rms":0,"buffers":0,"copies":0,"copy_mb":0,"sources":0,"heap_mb":13.6,"renderer_mb":339,"fps":14,"static_mb":0,"voices_peak":0,"beds":0,"bed_st |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | desktop | PASSED | serial: undefined; soak: [{"t":32,"pops":3,"blocked":8,"rms":0.1672,"peak":0.477,"mean_rms":0.0182,"buffers":16,"copies":173,"copy_mb":65.5,"sources":173,"heap_mb":42.6,"renderer_mb":350,"fps":16,"static_mb":0,"voices_pe |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | p720 | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.761 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.764 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | p720 | PASSED | mix: {"one":{"rms":0.045947339467713774,"peak":0.10156919062137604,"mean_rms":0.004869200624123709},"forty":{"rms":0.0491453261628363,"peak":0.12218932807445526,"mean_rms":0.012790368173855784},"hand":{"rms":0.1713273664 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | p720 | PASSED | pan: {"left":{"left":0.06194536500716811,"right":0.04348433510148132,"energy_left":19.244326124155695,"energy_right":9.524424453272857,"frames":44032,"mean_rms":0.01807429209452632},"right":{"left":0.043638591070210384," |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | p720 | PASSED | hidden: {"before":{"rms":0.03622258705881142,"peak":0.08455704897642136},"hidden":{"rms":0,"peak":0},"after":{"rms":0.049195979923098154,"peak":0.1226399764418602},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | p720 | PASSED | calm: {"loud":{"rms":0.03468637187956992,"peak":0.07476787269115448},"calmFloor":{"rms":0.023267282424675677,"peak":0.05613626539707184},"calmHand":{"rms":0.08555536237575516,"peak":0.2224583923816681},"popped":true,"bed |
| sound43.spec.mjs | one sale, one cash sound | p720 | PASSED | cash: {"sold":33,"asked":33,"played":23} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | phone | PASSED | mix: {"one":{"rms":0.04596767768951541,"peak":0.10165145248174667,"mean_rms":0.004873981447657744},"forty":{"rms":0.057046303449622686,"peak":0.16082151234149933,"mean_rms":0.012751033813116675},"hand":{"rms":0.171456341 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | phone | PASSED | pan: {"left":{"left":0.06206615786377223,"right":0.04360138492657425,"energy_left":19.407058310395982,"energy_right":9.768921552325015,"frames":44544,"mean_rms":0.01809685558344083},"right":{"left":0.04354346325647496,"r |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | phone | PASSED | hidden: {"before":{"rms":0.03624623276169784,"peak":0.07199190557003021},"hidden":{"rms":0,"peak":0},"after":{"rms":0.04906486344638054,"peak":0.11517506837844849},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | phone | PASSED | calm: {"loud":{"rms":0.035378856868407374,"peak":0.07194182276725769},"calmFloor":{"rms":0.022991100739846483,"peak":0.05061649903655052},"calmHand":{"rms":0.08330384791578375,"peak":0.2428015172481537},"popped":true,"be |
| sound43.spec.mjs | one sale, one cash sound | phone | PASSED | cash: {"sold":30,"asked":30,"played":21} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | desktop | PASSED | mix: {"one":{"rms":0.046082956575204746,"peak":0.0987391322851181,"mean_rms":0.004866873935346663},"forty":{"rms":0.04872556018172798,"peak":0.12265083938837051,"mean_rms":0.01221156175153886},"hand":{"rms":0.16944092066 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | desktop | PASSED | pan: {"left":{"left":0.06200263686912411,"right":0.04353609365348756,"energy_left":19.32140997834276,"energy_right":9.606916477999194,"frames":44544,"mean_rms":0.018019886462008985},"right":{"left":0.04355104312821967,"r |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | desktop | PASSED | hidden: {"before":{"rms":0.037362051369626545,"peak":0.07625885307788849},"hidden":{"rms":0,"peak":0},"after":{"rms":0.04884749511176413,"peak":0.12166635692119598},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | desktop | PASSED | calm: {"loud":{"rms":0.03668073263943227,"peak":0.07933110743761063},"calmFloor":{"rms":0.02330056319512711,"peak":0.05589177832007408},"calmHand":{"rms":0.08434315187348378,"peak":0.2262117862701416},"popped":true,"beds |
| sound43.spec.mjs | one sale, one cash sound | desktop | PASSED | cash: {"sold":31,"asked":31,"played":23} |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1552 ms, game judged 1586 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1551 ms, game judged 1611 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1552 ms, game judged 1559 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 1222 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 1409 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 1242 ms to the first drawn frame |
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
