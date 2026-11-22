# Popcorn test report (AUTOMATED)

- git 40d187d9a71f (uncommitted changes) · build 0.48.1 game-a0c5dc788068.pck
- 2026-11-22T08:15:16.240Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (354 passed, 0 failed, 24130 checks, 31 files, 697.7s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **PASSED** — passed 314 (on retry 0), failed 0, skipped 57

- mode: **full**, 45 specs · load 2.20 5.09 5.52 → 10.85 10.15 9.43 · free memory 33642 → 33724 MB
- not run (SKIPPED, with why): perf46.spec.mjs — the Step 46 benchmark table, desktop and phone (--perf); play180.spec.mjs — three real minutes per experiment (--slow); play_stand.spec.mjs — a long real-time stand session, one project (--slow); render_probe.spec.mjs — a probe, not a gate: load time and render cost of a build (--perf); sessions22.spec.mjs — Step 22 evidence: real-time 3-minute sessions from seeds, writes $OUT/sessions22.json (--slow)

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | p720 | PASSED | art: {"kettle":{"sat":0.322,"lumStd":55.29,"skyShare":0.085,"vivid":0.337},"wall":{"sat":0.338,"lumStd":7.49,"skyShare":0,"vivid":0},"shop_window":{"sat":0.236,"lumStd":43.15,"skyShare":0.61,"vivid":0},"tiles":{"sat":0.0 |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | p720 | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.4,"skyShare":0,"vivid":0},"rich":{"sat":0.73,"lumStd":38.64,"skyShare":0.014,"vivid":0.874}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | phone | PASSED | art: {"kettle":{"sat":0.329,"lumStd":55.58,"skyShare":0.083,"vivid":0.338},"wall":{"sat":0.345,"lumStd":7.3,"skyShare":0,"vivid":0},"shop_window":{"sat":0.229,"lumStd":43.5,"skyShare":0.607,"vivid":0.004},"tiles":{"sat": |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | phone | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.23,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":37.01,"skyShare":0.014,"vivid":0.871}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | desktop | PASSED | art: {"kettle":{"sat":0.335,"lumStd":55.98,"skyShare":0.083,"vivid":0.353},"wall":{"sat":0.331,"lumStd":7.32,"skyShare":0,"vivid":0},"shop_window":{"sat":0.219,"lumStd":36.79,"skyShare":0.656,"vivid":0},"tiles":{"sat":0. |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | desktop | PASSED | card: {"poor":{"sat":0.052,"lumStd":31.47,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":38.82,"skyShare":0.014,"vivid":0.872}} |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | p720 | PASSED | cast: {"worst_iou":0.507,"pair":"heat~upkeep","ink":{"heat":150,"news":241,"pack_rate":0,"perfect":107,"pop_rate":0,"queue":118,"sales":0,"sign_up":156,"stock":250,"trophy":0,"upkeep":25},"mean":{"heat":[184,85,45],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | p720 | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":0,"hits":[]},"30m":{"minute":31.3,"most":13,"looks":14,"stats":{"delight":13,"happy":49,"receive":109,"thanks":47},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | phone | PASSED | cast: {"worst_iou":0.531,"pair":"heat~upkeep","ink":{"heat":183,"news":281,"pack_rate":0,"perfect":126,"pop_rate":0,"queue":137,"sales":0,"sign_up":159,"stock":312,"trophy":0,"upkeep":28},"mean":{"heat":[182,85,44],"news |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | phone | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.5,"sign":2,"people":1,"hits":[]},"30m":{"minute":31.5,"most":14,"looks":14,"stats":{"delight":12,"happy":47,"receive":110,"thanks":51},"hits":[]},"render":{"draw_calls" |
| art41.spec.mjs | the cast sheet: an icon set told apart by shape and colour, and walkers whose feet stay put | desktop | PASSED | cast: {"worst_iou":0.553,"pair":"news~queue","ink":{"heat":71,"news":157,"pack_rate":0,"perfect":48,"pop_rate":0,"queue":53,"sales":0,"sign_up":82,"stock":111,"trophy":0,"upkeep":17},"mean":{"heat":[184,86,44],"news":[13 |
| art41.spec.mjs | the shop at 0 m, 3 m and a 30-minute rush: people of many looks, clear of the tube and the buttons | desktop | PASSED | shop: {"0m":{"people":1,"hits":[]},"3m":{"minute":3.4,"sign":2,"people":0,"hits":[]},"30m":{"minute":31.3,"most":14,"looks":14,"stats":{"delight":13,"happy":54,"receive":109,"thanks":42},"hits":[]},"render":{"draw_calls" |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | p720 | PASSED | real3min: {"firstSale":9337,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | p720 | PASSED | sign: [{"tier":6,"warm":0,"px":8784},{"tier":7,"warm":661,"px":8784},{"tier":8,"warm":1668,"px":8784}]; money: {"rect":[120,34,298,76],"outside_one":88,"outside_seven":88} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | phone | SKIPPED | p720 is the portrait touch run; three real minutes each |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | phone | PASSED | sign: [{"tier":6,"warm":0,"px":17680},{"tier":7,"warm":1662,"px":17680},{"tier":8,"warm":2294,"px":17680}]; money: {"rect":[65,18.4184856414795,161.4166717529295,41.1707305908203],"outside_one":2256,"outside_seven":1213} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | desktop | PASSED | real3min: {"firstSale":9307,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | desktop | PASSED | sign: [{"tier":6,"warm":0,"px":5143},{"tier":7,"warm":312,"px":5143},{"tier":8,"warm":591,"px":5143}]; money: {"rect":[477.5,21.125,325,58.5],"outside_one":0,"outside_seven":0} |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136700,"leftHidden":136650}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.4,"packs":136,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135550,"leftHidden":135500}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":1.3,"packs":136,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136900,"leftHidden":136850}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.8,"packs":137,"tier":3,"prize":240,"overfill":3,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3683,"goldPre":3349,"turned":828,"area":[448.5599975585934,301.07031860351617,145.08004760 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":4756,"goldPre":3583,"turned":1450,"area":[485.9400024414065,378.80126953125017,157.1700439 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":2515,"goldPre":2201,"turned":497,"area":[477.9150390625,221.80137939453132,170.03247070312 |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | p720 | PASSED | cast: {"arrived_who":{"classic":13,"elder":2,"kid":7,"student":13},"passed_by_who":{"kid":8,"rush":13},"sold":30,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":162,"thanks":true,"flavor_sold |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | phone | PASSED | cast: {"arrived_who":{"classic":15,"elder":2,"kid":7,"student":10},"passed_by_who":{"kid":10,"rush":14,"student":3},"sold":31,"happy":29,"popularity":[50.4,55.8],"stars":3,"favorite":"plain","studentPx":282,"thanks":true |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | desktop | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":9,"student":13},"passed_by_who":{"kid":6,"rush":13},"sold":31,"happy":31,"popularity":[50.4,56.2],"stars":3,"favorite":"plain","studentPx":89,"thanks":true,"flavor_sold" |
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
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":50,"auto_lots":57,"premium_lots":20,"premium_sold":31,"sorted":16,"dispatch_held_ms":164250,"vent_saves":0,"upkeep":66,"kernels":106} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":54,"auto_lots":60,"premium_lots":20,"premium_sold":34,"sorted":16,"dispatch_held_ms":156800,"vent_saves":0,"upkeep":68,"kernels":113} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":50,"auto_lots":56,"premium_lots":22,"premium_sold":37,"sorted":15,"dispatch_held_ms":181450,"vent_saves":0,"upkeep":66,"kernels":104} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[19.61168856271756,19.849146479186334,19.550342130987293,19.607843137254903,19.5274360512835,19.956096591305453],"median":19.61168856271756,"heap0":20782007,"heap1":25501376,"kept_mb":4.719369,"draw_calls":[ |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":14,"small":30,"large":18,"bagger":27,"cup_feeder":15,"packed":70,"upkeep":34} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":14,"small":28,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":34} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[21.3,20,20.3,19.8,19.7,20.4],"median":20.285935088745397,"packers_running":[3,2,2,2,2,0],"draw_calls":[580,613,618,609,616,611],"objects":[967,994,1042,1003,1011,1033],"load":9.83} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":108,"cashier":56,"express":49,"routed":0,"express_jumped":10,"lanes":4,"lost":48,"upkeep":68,"revenue":1242} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":110,"cashier":65,"express":42,"routed":1,"express_jumped":8,"lanes":4,"lost":50,"upkeep":70,"revenue":1268} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":105,"cashier":54,"express":48,"routed":0,"express_jumped":9,"lanes":4,"lost":48,"upkeep":70,"revenue":1226} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":[]}; lines: {"at_pause":11,"before_kitchen_pause":10,"moved":4,"line_portions":[0,0,1 |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":52,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":["cooker"]}; lines: {"at_pause":7,"before_kitchen_pause":4,"moved":2,"line_p |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | PASSED | layout: {"smallest_place_px":21,"window":[1280,800]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"],"holding_a_lot":[]}; lines: {"at_pause":10,"before_kitchen_pause":9,"moved":4,"line_portions":[3,0,1] |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":970,"cheese":1169,"spicy":1195,"caramel":1040,"cocoa":700},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":2,"cheese":5,"cocoa":1,"spicy":3},"revenue":{"caramel":34,"cheese":67,"cocoa":34,"spicy":53},"coated":{"caramel":8,"cheese":16,"cocoa":4,"spicy":8},"ingredients":34,"minutes":3.1783333333 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2200,"cheese":2673,"spicy":2749,"caramel":2298,"cocoa":1935},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED | flavor trade: {"sold":{"caramel":5,"cheese":4,"cocoa":2,"spicy":1},"revenue":{"caramel":96,"cheese":48,"cocoa":55,"spicy":14},"coated":{"caramel":18,"cheese":16,"cocoa":12,"spicy":4},"ingredients":51,"minutes":3.4025,"so |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":1954,"cheese":1392,"spicy":1441,"caramel":1250,"cocoa":1057},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":4,"cheese":9,"cocoa":3,"spicy":1},"revenue":{"caramel":81,"cheese":107,"cocoa":70,"spicy":14},"coated":{"caramel":18,"cheese":24,"cocoa":8,"spicy":4},"ingredients":47,"minutes":3.13,"sold |
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
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | p720 | PASSED | by_hand: {"first_sale_ms":10094,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | phone | PASSED | by_hand: {"first_sale_ms":10374,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| journey46.spec.mjs | a novice journey: first sale, three stations, every category, the card, the paper, a contest, resume, restart | desktop | PASSED | by_hand: {"first_sale_ms":10080,"minute_sales":6,"revenue":60,"sign_open":true}; stations: {"sign":[0,5],"packer":[0,2],"kettle":[0,1]}; hooks: ["dev_money","dev_news","dev_contest"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | p720 | PASSED | arc: {"glow_at":[10.3291666666667,7.92272727272726,3.07456666666667],"tier":"solo"}; celebrate: {"climb":[0.0454444444444445,0.203703703703704,0.342592592592593,0.762005622895623,0.90909090909091,1,1,-1,-1,-1],"moved":0, |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | p720 | PASSED | crescendo: {"samples":[{"t":9,"running":29,"alive":16,"given":{"ambient":96,"lot":26,"sparkle":28},"low":true,"fps":13.1},{"t":19,"running":27,"alive":46,"given":{"ambient":112,"lot":30,"sparkle":42},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | low effects: {"low":true,"reduced":false,"given":46,"secs":13.102,"phase":[[48.67,48.67,48.67,14.18,0,48.67],[444.69,422.24,444.69,360.98,312.16,444.69]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start" |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | p720 | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.025,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | phone | PASSED | arc: {"glow_at":[10.8340757575757,8.45,3.55883333333333],"tier":"solo"}; celebrate: {"climb":[0.0602222222222222,0.241222222222222,0.35541975308642,0.918703703703704,1,1,1,-1,-1,-1],"moved":0,"celebrations":1,"kind":"sig |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | phone | PASSED | crescendo: {"samples":[{"t":9,"running":31,"alive":24,"given":{"ambient":91,"lot":30,"sparkle":28},"low":true,"fps":11.5},{"t":19,"running":27,"alive":29,"given":{"ambient":110,"lot":31,"sparkle":43},"low":true,"fps":11. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | low effects: {"low":true,"reduced":false,"given":50,"secs":14.03,"phase":[[58.4,58.4,58.4,16.68,0,58.4],[561.93,544.87,561.93,462.96,404.87,561.93]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | phone | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.79,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"], |
| motion42.spec.mjs | one batch lights the floors bottom to top, and a celebration never moves the ring | desktop | PASSED | arc: {"glow_at":[10.4166666666667,8.02578248148149,3.17266666666667],"tier":"solo"}; celebrate: {"climb":[0.0430495430495431,0.19334695045695,0.341180283790284,0.765271765271765,0.903318903318903,1,1,-1,-1,-1],"moved":0, |
| motion42.spec.mjs | forty-four machines: a bounded crescendo through a resize and a hidden tab | desktop | PASSED | crescendo: {"samples":[{"t":9,"running":32,"alive":18,"given":{"ambient":98,"lot":29,"sparkle":28},"low":true,"fps":11.7},{"t":19,"running":27,"alive":40,"given":{"ambient":114,"lot":31,"sparkle":41},"low":true,"fps":12. |
| motion42.spec.mjs | low effects: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | low effects: {"low":true,"reduced":false,"given":49,"secs":13.298,"phase":[[45,45,45,14.29,0,45],[419.38,398.78,419.38,343.15,298.52,419.38]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redire |
| motion42.spec.mjs | reduced motion: smaller or still effects, and a batch still travels kitchen to shop | desktop | PASSED | reduced motion: {"low":true,"reduced":true,"given":0,"secs":13.232,"phase":[[0,0,0,0,0,0],[0,0,0,0,0,0]],"kinds":["lot:start","lot:end","fill:start","fill:end","bag:start","bag:redirect","bag:end","bag:sold","bag:serve"] |
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
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1547,"unread":1,"marks":1}; hidden: {"left0":112450,"leftHidden":112400}; craze: {"row":{"asked":15,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1869,"unread":1,"marks":1}; hidden: {"left0":111450,"leftHidden":111350}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":112750,"leftHidden":112700}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2084,"heap_start":10696060,"heap_after_60s":12287349,"burst":{"fps":50.89312446773903,"draw_calls":117,"primitives":4299,"fx_peak":154,"fx_cap":400},"sleep":{"before":3236,"hidden_5s":3253,"after_wake":4 |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":179,"primitives":5343,"fx":44},"fps":[44.71383145311461,47.62377221764761,48.48125062753247,47.956838863317095,47.90419161676647,48.824232789893834],"median_fps":47.956838863317095,"heap_star |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | p720 | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | p720 | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | p720 | PASSED |  |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | phone | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | phone | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | phone | PASSED |  |
| progression07.spec.mjs | FAST-FORWARD: milestones in order through 3:00 | desktop | PASSED | mode: fast-forward with dev_advance (not real-time play) |
| progression07.spec.mjs | ten restarts in a row: each from nothing, no errors | desktop | PASSED |  |
| progression07.spec.mjs | an unusual order: A, C, B, A again, by tiles, links and the back button | desktop | PASSED |  |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | p720 | PASSED | ready47: {"ring_sat":{"ready":0.478,"waiting":0.37},"cue_after_lift":true,"refused":1} |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | phone | PASSED | ready47: {"ring_sat":{"ready":0.483,"waiting":0.37},"cue_after_lift":true,"refused":1} |
| ready47.spec.mjs | a waiting kettle dims its ring, and a refused hold shows why after the finger lifts | desktop | PASSED | ready47: {"ring_sat":{"ready":0.483,"waiting":0.378},"cue_after_lift":true,"refused":1} |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 64195 ms |
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
| save45.spec.mjs | a killed browser loses seconds, never goods: nothing sold twice, every machine there | desktop | PASSED | kill: {"pids":2,"built_clock":31658,"before_kill_clock":38708,"saved_clock":31534,"sold":[14,12,12],"from":"main"} |
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
| soak43.spec.mjs | the control: the sound off plays nothing | desktop | PASSED | serial: undefined; soak: [{"t":32,"pops":4,"blocked":8,"rms":0,"peak":0,"mean_rms":0,"buffers":0,"copies":0,"copy_mb":0,"sources":0,"heap_mb":18.4,"renderer_mb":325,"fps":15,"static_mb":0,"voices_peak":0,"beds":0,"bed_st |
| soak43.spec.mjs | the sound on: no clip, bounded voices, no buffer growth, and no memory of its own | desktop | PASSED | serial: undefined; soak: [{"t":34,"pops":4,"blocked":7,"rms":0.1694,"peak":0.498,"mean_rms":0.0189,"buffers":16,"copies":183,"copy_mb":71.2,"sources":183,"heap_mb":54.2,"renderer_mb":352,"fps":13,"static_mb":0,"voices_pe |
| sound05.spec.mjs | A: a press is heard | p720 | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | p720 | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | p720 | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | p720 | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | p720 | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | p720 | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | p720 | PASSED |  |
| sound05.spec.mjs | A: a press is heard | phone | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | phone | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.224 peak 0.761; top stand rms 0.224 peak 0.774 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.223 peak 0.774 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> calm -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | p720 | PASSED | mix: {"one":{"rms":0.04584628869169208,"peak":0.10247845947742462,"mean_rms":0.004860751705696432},"forty":{"rms":0.0495713440816065,"peak":0.13115376234054565,"mean_rms":0.01301458397624734},"hand":{"rms":0.171828909210 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | p720 | PASSED | pan: {"left":{"left":0.06205970609423083,"right":0.043596178469702374,"energy_left":19.261094348151467,"energy_right":9.53589684167719,"frames":44160,"mean_rms":0.018056934661718996},"right":{"left":0.04348397259187047," |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | p720 | PASSED | hidden: {"before":{"rms":0.03495469192510287,"peak":0.07275362312793732},"hidden":{"rms":0,"peak":0},"after":{"rms":0.050039070808913524,"peak":0.12984472513198853},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | p720 | PASSED | calm: {"loud":{"rms":0.0367022542722051,"peak":0.07945125550031662},"calmFloor":{"rms":0.023290896423191678,"peak":0.05422366037964821},"calmHand":{"rms":0.08524142055188727,"peak":0.21766850352287292},"popped":true,"bed |
| sound43.spec.mjs | one sale, one cash sound | p720 | PASSED | cash: {"sold":33,"asked":33,"played":25} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | phone | PASSED | mix: {"one":{"rms":0.045999307364686756,"peak":0.1017066091299057,"mean_rms":0.005142928245312539},"forty":{"rms":0.05556013223470019,"peak":0.15505018830299377,"mean_rms":0.012718679666365284},"hand":{"rms":0.1674987020 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | phone | PASSED | pan: {"left":{"left":0.06208426440846158,"right":0.043620344475050796,"energy_left":19.431728872540333,"energy_right":9.795832971664186,"frames":45056,"mean_rms":0.018009637843855418},"right":{"left":0.04354252071311095, |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | phone | PASSED | hidden: {"before":{"rms":0.03270129582697496,"peak":0.07534095644950867},"hidden":{"rms":0.00000497817131961347,"peak":0},"after":{"rms":0.048707481143969576,"peak":0.12510237097740173},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | phone | PASSED | calm: {"loud":{"rms":0.033042816074811215,"peak":0.05939415842294693},"calmFloor":{"rms":0.02299940244671771,"peak":0.053141482174396515},"calmHand":{"rms":0.08505667207409344,"peak":0.24272958934307098},"popped":true,"b |
| sound43.spec.mjs | one sale, one cash sound | phone | PASSED | cash: {"sold":31,"asked":31,"played":25} |
| sound43.spec.mjs | the first touch wakes the factory; one machine is quiet, forty-four are lively, and nothing clips | desktop | PASSED | mix: {"one":{"rms":0.045896070180091605,"peak":0.1024191677570343,"mean_rms":0.005138315653461235},"forty":{"rms":0.04835185469339034,"peak":0.1210574135184288,"mean_rms":0.012030457484222889},"hand":{"rms":0.17288710589 |
| sound43.spec.mjs | a sound on the left is louder on the left, on the right louder on the right | desktop | PASSED | pan: {"left":{"left":0.06205412125277698,"right":0.04358378576092654,"energy_left":19.317233328329863,"energy_right":9.602547036364996,"frames":44544,"mean_rms":0.018017224521352973},"right":{"left":0.04354272839628407," |
| sound43.spec.mjs | a hidden tab is silent, and the factory is heard again after | desktop | PASSED | hidden: {"before":{"rms":0.037659015077032676,"peak":0.08086395263671875},"hidden":{"rms":0,"peak":0},"after":{"rms":0.04918860100769575,"peak":0.12775123119354248},"paused":true,"beds":0} |
| sound43.spec.mjs | calm: no beds, the hand still heard, and the choice survives a reload | desktop | PASSED | calm: {"loud":{"rms":0.03313364539637052,"peak":0.07382352650165558},"calmFloor":{"rms":0.023143429693671586,"peak":0.05271898955106735},"calmHand":{"rms":0.08405574776413959,"peak":0.22331002354621887},"popped":true,"be |
| sound43.spec.mjs | one sale, one cash sound | desktop | PASSED | cash: {"sold":32,"asked":32,"played":23} |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1551 ms, game judged 1574 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1551 ms, game judged 1585 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1551 ms, game judged 1569 ms (perfect) |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | p720 | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | p720 | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | phone | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | phone | PASSED |  |
| stand10.spec.mjs | the stand: B first, shake by dragging, a shaker chooses, the card buys the machines | desktop | PASSED |  |
| stand10.spec.mjs | the stand fits: shakers, helper, card and machine do not overlap the bars | desktop | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | p720 | PASSED | load: 2025 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | p720 | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | p720 | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | p720 | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2201 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2036 ms to the first drawn frame |
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
