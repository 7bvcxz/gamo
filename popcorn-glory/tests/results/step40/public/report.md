# Popcorn test report (AUTOMATED)

- git 91765f34c7ac (uncommitted changes) · build 0.40.0 game-8fcad55697e7.pck
- 2026-11-18T13:05:58.790Z
- target: https://7bvcxz.github.io/gamo/popcorn-glory/
- headless: **PASSED** (297 passed, 0 failed, 21268 checks, 18 files, 264.5s)
- deploy: **SKIPPED (--public: testing the published build)**
- browser: **PASSED** — passed 229 (on retry 1), failed 0, skipped 35

| spec | check | project | status | cause / notes |
|---|---|---|---|---|
| art15.spec.mjs | the artboard preview draws on this screen | p720 | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | p720 | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | phone | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | phone | PASSED |  |
| art15.spec.mjs | the artboard preview draws on this screen | desktop | PASSED |  |
| art15.spec.mjs | the chooser does not list the artboard | desktop | PASSED |  |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | p720 | PASSED | art: {"kettle":{"sat":0.32,"lumStd":54.98,"skyShare":0.086,"vivid":0.327},"wall":{"sat":0.338,"lumStd":7.49,"skyShare":0,"vivid":0},"shop_window":{"sat":0.232,"lumStd":34.06,"skyShare":0.63,"vivid":0},"tiles":{"sat":0.03 |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | p720 | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.4,"skyShare":0,"vivid":0},"rich":{"sat":0.73,"lumStd":38.17,"skyShare":0.014,"vivid":0.874}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | phone | PASSED | art: {"kettle":{"sat":0.327,"lumStd":55.61,"skyShare":0.084,"vivid":0.337},"wall":{"sat":0.345,"lumStd":7.3,"skyShare":0,"vivid":0},"shop_window":{"sat":0.223,"lumStd":33.12,"skyShare":0.617,"vivid":0.006},"tiles":{"sat" |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | phone | PASSED | card: {"poor":{"sat":0.055,"lumStd":31.23,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":38.36,"skyShare":0.014,"vivid":0.872}} |
| art40.spec.mjs | the three rooms are drawn behind the machines, and the hand's kettle stays the vivid thing in the kitchen | desktop | PASSED | art: {"kettle":{"sat":0.324,"lumStd":54.61,"skyShare":0.085,"vivid":0.329},"wall":{"sat":0.331,"lumStd":7.32,"skyShare":0,"vivid":0},"shop_window":{"sat":0.219,"lumStd":30.58,"skyShare":0.662,"vivid":0.001},"tiles":{"sat |
| art40.spec.mjs | the upgrade card: a silhouette out of reach, the next machine in its colours once affordable | desktop | PASSED | card: {"poor":{"sat":0.052,"lumStd":31.47,"skyShare":0,"vivid":0},"rich":{"sat":0.729,"lumStd":38.81,"skyShare":0.014,"vivid":0.872}} |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | p720 | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | p720 | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | p720 | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | phone | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | phone | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | phone | SKIPPED | desktop measures the sound |
| burst14.spec.mjs | burst mode: perfect pops fill the crescendo, the filling pop is one 1.5x burst | desktop | PASSED |  |
| burst14.spec.mjs | without ?burst=1 the stand has no crescendo | desktop | PASSED |  |
| burst14.spec.mjs | the fountain is heard and does not clip | desktop | PASSED | mix: fountain rms 0.223 peak 0.759 |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | p720 | PASSED | real3min: {"firstSale":9262,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | p720 | PASSED | sign: [{"tier":6,"warm":0,"px":8784},{"tier":7,"warm":661,"px":8784},{"tier":8,"warm":1303,"px":8784}]; money: {"rect":[120,34,390,76],"outside_one":114,"outside_seven":114} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | phone | SKIPPED | p720 is the portrait touch run; three real minutes each |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | phone | PASSED | sign: [{"tier":6,"warm":0,"px":17680},{"tier":7,"warm":1109,"px":17680},{"tier":8,"warm":1722,"px":17680}]; money: {"rect":[65,18.4184856414795,211.25,41.1707305908203],"outside_one":2474,"outside_seven":2420} |
| career39.spec.mjs | real clock: a fresh factory's first three minutes against the sim | desktop | PASSED | real3min: {"firstSale":9289,"marks":{"60":{"money":10,"sign":1,"sold":5,"spent":40},"120":{"money":70,"sign":1,"sold":11,"spent":40},"180":{"money":40,"sign":2,"sold":18,"spent":140}},"pops":18,"ratio":1,"revenue":180,"s |
| career39.spec.mjs | a rich factory: the sign's new tiers draw more, and a twelve-digit wallet fits the counter | desktop | PASSED | sign: [{"tier":6,"warm":0,"px":5143},{"tier":7,"warm":313,"px":5143},{"tier":8,"warm":599,"px":5143}]; money: {"rect":[477.5,21.125,325,58.5],"outside_one":0,"outside_seven":0} |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | p720 | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | phone | PASSED |  |
| catalog27.spec.mjs | the machine catalog sheet draws on this screen | desktop | PASSED |  |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | p720 | PASSED | dot: {"dot":191,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":135800,"leftHidden":135750}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | p720 | PASSED | lean: {"score":1.1,"packs":137,"tier":2,"prize":120,"overfill":5,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | phone | PASSED | dot: {"dot":221,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":134850,"leftHidden":134800}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | phone | PASSED | lean: {"score":0.8,"packs":136,"tier":3,"prize":240,"overfill":3,"lost":0} |
| contests38.spec.mjs | contests: a plain stand opens them, enters, wins by real pops, repeats, cancels, collides and resumes | desktop | PASSED | dot: {"dot":137,"posted":["perfect_streak"]}; live: {"pops":4,"score":4,"cur":4,"tiers":[3,5,8],"outcomes":{"burnt":0,"early":0,"late":0,"near":0,"perfect":20}}; hidden: {"left0":136250,"leftHidden":136200}; result: {"ab |
| contests38.spec.mjs | contests: an advanced factory enters lean packing and its score comes from the counters | desktop | PASSED | lean: {"score":0.8,"packs":137,"tier":3,"prize":240,"overfill":3,"lost":0} |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | p720 | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3759,"goldPre":3264,"turned":987,"area":[448.5599975585934,301.07031860351617,145.08004760 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | phone | PASSED | spoon: {"flavor":"cocoa","gold":[900,1300],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":4629,"goldPre":4006,"turned":891,"area":[485.9400024414065,378.80126953125017,157.17004394 |
| craft35.spec.mjs | the spoon finishes a batch by hand; the machine, the mix and the payback stay honest | desktop | PASSED | spoon: {"flavor":"caramel","gold":[1100,1450],"graded":"perfect","hand_finish":{"perfect":1},"hand_portions":4}; flourish: {"goldPx":3038,"goldPre":2373,"turned":1128,"area":[477.9150390625,221.80137939453132,170.0324707 |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | p720 | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":9,"student":13},"passed_by_who":{"kid":6,"rush":13},"sold":31,"happy":30,"popularity":[50.4,56],"stars":3,"favorite":"plain","studentPx":203,"thanks":true,"flavor_sold": |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | phone | PASSED | cast: {"arrived_who":{"classic":15,"elder":2,"kid":8,"student":12},"passed_by_who":{"kid":7,"rush":13,"student":1},"sold":31,"happy":31,"popularity":[50.4,55.2],"stars":3,"favorite":"plain","studentPx":668,"thanks":true, |
| customers36.spec.mjs | a classic first customer, then a cast with their own tastes, faces and stars | desktop | PASSED | cast: {"arrived_who":{"classic":12,"elder":2,"kid":8,"student":13},"passed_by_who":{"kid":6,"rush":12},"sold":30,"happy":27,"popularity":[50.4,55.4],"stars":3,"favorite":"plain","studentPx":239,"thanks":true,"flavor_sold |
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
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | p720 | PASSED | kitchen: {"rotary":49,"auto_lots":57,"premium_lots":22,"premium_sold":37,"sorted":16,"dispatch_held_ms":181950,"vent_saves":0,"upkeep":67,"kernels":104} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | p720 | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | p720 | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | phone | PASSED | kitchen: {"rotary":51,"auto_lots":58,"premium_lots":22,"premium_sold":36,"sorted":16,"dispatch_held_ms":194750,"vent_saves":0,"upkeep":67,"kernels":107} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | phone | SKIPPED | desktop runs the heat |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | phone | SKIPPED | desktop measures |
| factory29.spec.mjs | the advanced kitchen: picker, rotary popper, premium SKU sold only to premium orders, vents | desktop | PASSED | kitchen: {"rotary":50,"auto_lots":54,"premium_lots":23,"premium_sold":37,"sorted":15,"dispatch_held_ms":196700,"vent_saves":0,"upkeep":65,"kernels":102} |
| factory29.spec.mjs | without vents five kettles overheat; with them the kitchen keeps cooking | desktop | PASSED |  |
| factory29.spec.mjs | a minute of a busy advanced factory: frame rate and kept memory | desktop | PASSED | perf: {"fps":[21.176244092677695,19.76284584980237,19.9381916173948,19.550342130987293,20.68761699520988,19.563728843068095],"median":19.9381916173948,"heap0":16172323,"heap1":21614743,"kept_mb":5.44242,"draw_calls":[854 |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | p720 | PASSED | packing: {"cups_sold":14,"small":27,"large":20,"bagger":25,"cup_feeder":15,"packed":68,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | p720 | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | p720 | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | phone | PASSED | packing: {"cups_sold":14,"small":29,"large":20,"bagger":26,"cup_feeder":15,"packed":70,"upkeep":37} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | phone | SKIPPED | desktop runs the details |
| factory30.spec.mjs | frame rate with several packers working at once | phone | SKIPPED | desktop measures |
| factory30.spec.mjs | the packing floor: cups, the weigher, the sealer, honest SKUs | desktop | PASSED | packing: {"cups_sold":14,"small":27,"large":19,"bagger":25,"cup_feeder":15,"packed":68,"upkeep":35} |
| factory30.spec.mjs | the dispenser sells large bags at tier 1; an empty floor stops and pays nothing | desktop | PASSED |  |
| factory30.spec.mjs | frame rate with several packers working at once | desktop | PASSED | perf: {"fps":[21.5,20.9,20.5,20.6,20.4,19.7],"median":20.580164629776494,"packers_running":[3,2,0,3,2,2],"draw_calls":[652,715,777,797,841,843],"objects":[1031,1100,1172,1168,1221,1223],"load":10.68} |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | p720 | PASSED | shop: {"sold":106,"cashier":54,"express":49,"routed":3,"express_jumped":11,"lanes":4,"lost":46,"upkeep":69,"revenue":1228} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | p720 | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | phone | PASSED | shop: {"sold":109,"cashier":57,"express":49,"routed":3,"express_jumped":9,"lanes":4,"lost":49,"upkeep":70,"revenue":1268} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | phone | SKIPPED | desktop runs the details |
| factory31.spec.mjs | the storefront: cashier, express window, robot lanes, router -- honest sales | desktop | PASSED | shop: {"sold":107,"cashier":55,"express":50,"routed":2,"express_jumped":6,"lanes":4,"lost":44,"upkeep":69,"revenue":1230} |
| factory31.spec.mjs | a paused cashier holds its customers sales until it is resumed | desktop | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | p720 | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | phone | PASSED |  |
| factory32.spec.mjs | support machines on their floors, the upkeep overview, pause and resume everything | desktop | PASSED |  |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | p720 | PASSED | layout: {"smallest_place_px":30,"window":[720,1280]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":8,"moved":4,"line_portions":[1,0,2]}; hidden: |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | phone | PASSED | layout: {"smallest_place_px":45,"window":[780,1688]}; ran: {"ran":38,"never":["cooker","kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":10,"before_kitchen_pause":8,"moved":3,"line_portions":[1,0,2]}; hidden: |
| factory33.spec.mjs | forty-four machines at once: built by hand, readable, routed, recovering, measured | desktop | PASSED | layout: {"smallest_place_px":21,"window":[1280,800]}; ran: {"ran":39,"never":["kiosk","U08","kiosk","bagger","bagger"]}; lines: {"at_pause":11,"before_kitchen_pause":10,"moved":4,"line_portions":[0,0,1]}; hidden: {"befor |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | p720 | PASSED | flavor pixels: {"counts":{"plain":1093,"cheese":1207,"spicy":1210,"caramel":1187,"cocoa":774},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | p720 | PASSED | flavor trade: {"sold":{"caramel":3,"cheese":12,"cocoa":1,"spicy":4},"revenue":{"caramel":51,"cheese":157,"cocoa":17,"spicy":82},"coated":{"caramel":25,"cheese":44,"cocoa":4,"spicy":16},"ingredients":68,"minutes":5.070833 |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | phone | PASSED | flavor pixels: {"counts":{"plain":2847,"cheese":2747,"spicy":2770,"caramel":2754,"cocoa":2426},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | phone | PASSED (on retry) |  |
| flavors34.spec.mjs | the flavors sheet draws five distinct flavors on this screen | desktop | PASSED | flavor pixels: {"counts":{"plain":2089,"cheese":1437,"spicy":1456,"caramel":1441,"cocoa":1274},"scale":1} |
| flavors34.spec.mjs | five flavors are coated, packed, asked for and sold in the browser | desktop | PASSED | flavor trade: {"sold":{"caramel":8,"cheese":19,"cocoa":1,"spicy":5},"revenue":{"caramel":136,"cheese":289,"cocoa":20,"spicy":72},"coated":{"caramel":22,"cheese":64,"cocoa":4,"spicy":12},"ingredients":81,"minutes":6.40083 |
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
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | p720 | PASSED | still: {"badge":318,"strip":1578,"unread":1,"marks":1}; hidden: {"left0":113150,"leftHidden":113100}; craze: {"row":{"asked":14,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | phone | PASSED | still: {"badge":377,"strip":1869,"unread":1,"marks":1}; hidden: {"left0":112650,"leftHidden":112550}; craze: {"row":{"asked":17,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| news37.spec.mjs | the news: quiet at opening, a craze that brings real customers, readable, never in the way | desktop | PASSED | still: {"badge":215,"strip":1015,"unread":1,"marks":1}; hidden: {"left0":113150,"leftHidden":113050}; craze: {"row":{"asked":16,"channel":"flavor","flavor":"caramel","id":"caramel_craze","left_ms":0,"ms":120000,"mult":2, |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | p720 | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | phone | SKIPPED | one project measures (desktop) |
| perf07.spec.mjs | load, heap over a minute, worst burst, sleep and wake | desktop | PASSED | perf: {"load_ms":2051,"heap_start":10362797,"heap_after_60s":12296565,"burst":{"fps":38.75583821187311,"draw_calls":117,"primitives":4301,"fx_peak":153,"fx_cap":400},"sleep":{"before":3431,"hidden_5s":3456,"after_wake":4 |
| perf07.spec.mjs | stand: peak load for a minute, hidden tab, restart | desktop | PASSED | perf: {"worst":{"draw_calls":179,"primitives":5347,"fx":43},"fps":[46.08746812238626,47.77070067321472,46.49782349735976,39.65107057140876,38.45395386248719,44.67831613236866],"median_fps":46.08746812238626,"heap_start": |
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
| release12.spec.mjs | first load on a slow connection (recorded) | desktop | PASSED | slow_load: Fast 3G emulation: first drawn frame after 62931 ms |
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
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | phone | PASSED | mix: fresh perfect rms 0.223 peak 0.759; top stand rms 0.224 peak 0.761 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | phone | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | phone | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | phone | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | phone | PASSED |  |
| sound05.spec.mjs | A: a press is heard | desktop | PASSED |  |
| sound05.spec.mjs | B: the sizzle while held, and a perfect pop | desktop | PASSED |  |
| sound05.spec.mjs | stand: a perfect pop, and the busy top stand, do not clip | desktop | PASSED | mix: fresh perfect rms 0.226 peak 0.759; top stand rms 0.223 peak 0.759 |
| sound05.spec.mjs | stand: the shake clinks and the helper pops on its own | desktop | PASSED |  |
| sound05.spec.mjs | C: kernels clink and the eruption booms | desktop | PASSED |  |
| sound05.spec.mjs | the speaker button steps loud -> soft -> off, and back on | desktop | PASSED |  |
| sound05.spec.mjs | ?sound=off starts muted | desktop | PASSED |  |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | p720 | PASSED | hold: finger 1551 ms, game judged 1577 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | phone | PASSED | hold: finger 1551 ms, game judged 1596 ms (perfect) |
| stall09.spec.mjs | B: a 0.8 s stall during a hold still counts toward the heat | desktop | PASSED | hold: finger 1553 ms, game judged 1557 ms (perfect) |
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
| stub03.spec.mjs | the stub: press, upgrade, restart, back | phone | PASSED | load: 2208 ms to the first drawn frame |
| stub03.spec.mjs | a direct link opens the stub, and the browser back button returns | phone | PASSED |  |
| stub03.spec.mjs | a hidden tab stops the play clock | phone | PASSED |  |
| stub03.spec.mjs | three minutes shows the clock and is logged | phone | PASSED |  |
| stub03.spec.mjs | the stub: press, upgrade, restart, back | desktop | PASSED | load: 2055 ms to the first drawn frame |
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
