# MACHINES — 기계 40종 카탈로그 (Step 27, 생성 문서)

`data/machines.json`이 단일 원본이다(생성: `tools/catalog/build_catalog.py`, 이 문서: `tools/catalog/catalog_doc.py`). 그림은 게임 안 `#machines`(실제 자리 크기, 다섯 묶음 × 8, 그 아래 40대가 층에 접힌 배치). 수치는 [proposal].

**가짜 효과 없음**: 모델에서 돌지 않는 기계(`runtime` 없음)나 아직 없는 체계(`requires`)가 필요한 기계는 지을 수 없고 아무것도 약속하지 않는다(`err.not_yet`, 시험 `test_no_machine_is_sold_that_would_do_nothing`). 지금 있는 체계: portions, packs, customers, sizes, lanes, upkeep, kernels, oil, heat_model, premium_sku, dispatch, cup_sku, portion_variance, multi_queue, four_lanes.

## 해금 지도 (간판 단계 → 열리는 기계)

| 간판 | 열리는 기계 |
|---|---|
| 0 | P01 ●, P02 ●, P03 ●, P04 ●, P05 ●, P06 ●, P07 ●, P08 ● |
| 2 | M06 ●, M08 ● |
| 3 | M01 ●, M02 ●, M04 ●, M07 ●, S01 ●, S07 ●, U04 |
| 4 | M03 ●, M05 ●, M09 ●, M12 ●, S02 ●, S03 ●, S06 ●, U01, U02, U03 |
| 5 | M10 ●, M11 ●, M13 ●, M14 ●, M15 ●, S04 ●, S05 ●, U05, U06 |
| 6 | M16 ●, S08 ●, U07, U08 |

● = 지금 돈다(Step 26: M07 자동 냄비, P03 부피 충전기, S07 셀프 키오스크).

## 제조 기초 (M01–M08, Step 28)

| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M01 | Kernel Hopper Loader | kitchen · 1 | kernels trickle down a funnel into the kettles | feed (resource=kernels, to=auto kettles, buffer=40) | kernels (bought by the sack) → kernels in each kettle's hopper | one hopper feeds up to 4 kettles | 간판 3 · +M07 | kernels | 250 / 1분 | buffer 40 / buffer 80 / buffer 160 | without kernels an auto kettle starves; with the hopper it never waits for a refill | 돈다 |
| M02 | Precision Oil Doser | kitchen · 1 | a drop of oil falls with each cycle | dose (resource=oil, grade_shift={'late': 'near'}, oil_per_lot=1) | oil, an auto lot starting → the lot's grade odds: late becomes near | one doser per kettle row | 간판 3 · +M07 | oil | 300 / 2분 | shift 0.5 / shift 0.75 / shift 1.0 | quality 60 -> 80 on the late share of auto lots | 돈다 |
| M03 | Heat Controller | kitchen · 1 | a needle steadies on a gauge | regulate (removes_grade=burnt, applies_to=auto kettles) | the kettles' heat → no burnt auto lots | covers the kettles on its row | 간판 4 · +M07 | heat_model | 350 / 2분 | — / — / — | burnt auto lots (yield 0.25) disappear once auto heat can vary | 돈다 |
| M04 | Agitation Motor | kitchen · 1 | a shaft turns inside the kettle | agitate (portions_bonus=1, applies_to=auto lots) | an auto lot cooking → one more portion per lot | one motor per kettle | 간판 3 · +M07 | — | 280 / 2분 | bonus 1 / bonus 1 / bonus 2 | an auto lot of ~2.1 portions makes ~3.1 (+48% from the same kernels) | 돈다 |
| M05 | Pop Detector | kitchen · 1 | an eye blinks when the popping slows | detect (removes_grade=late, applies_to=auto lots) | the popping sound → no late auto lots (they come out near) | one detector per kettle | 간판 4 · +M07 | — | 320 / 1분 | — / — / — | late share (30%) becomes near: +0.6 portion and +20 quality per such lot | 돈다 |
| M06 | Batch Ejector | kitchen · 1 | an arm tips the kettle into the tube | eject (lift_ms_minus=600, applies_to=the hand kettle and auto kettles) | a lot in a glass → the lot in the lift sooner | one per floor | 간판 2 | — | 220 / 1분 | minus 600 / minus 700 / minus 800 | the kettle's glass frees 0.6 s sooner each lot (the hand pops more often when the bin is the limit) | 돈다 |
| M07 | Dual Kettle Sequencer | kitchen · 1 | a second kettle cooks while the first pours | produce (makes=lots, portions=4 x 0.7 x grade, cycle_ms=6000) | — → a lot of popcorn (real portions) | holds its lot when the bin is full | 간판 3 | — | 300 / 4분 | cycle_ms 6000 / cycle_ms 4800 / cycle_ms 3800 | ~21 portions a minute (tier 0) | 돈다 |
| M08 | Cooling/Recovery Fan | kitchen · 1 | fan blades spin after each pop | cool (recovery_ms_minus=150, applies_to=the hand kettle and auto kettles' turnaround) | a kettle cooling → shorter cooldown | one per floor | 간판 2 | — | 200 / 1분 | minus 150 / minus 200 / minus 250 | a fast hand pops ~5% more often | 돈다 |

## 제조 고급 (M09–M16, Step 29)

| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M09 | Kernel Sorter | kitchen · 1 | a sieve shakes out unpopped kernels | sort (regrade={'early': 'near', 'late': 'near'}, portion_loss=1) | early/late lots → the same lot at near grade, one portion fewer | between the kettles and the lift | 간판 4 · +M07 | — | 600 / 3분 | — / — / — | quality 50/60 -> 80 for a portion each | 돈다 |
| M10 | Multi-Pot Distributor | kitchen · 1 | pipes branch to several pots | capacity (kitchen_slots_plus=2) | — → two more kitchen places (three, four at its tiers) | one place; its extra places must be empty to sell it | 간판 5 · +M07 | — | 1200 / 2분 | plus 2 / plus 3 / plus 4 | more kettles where the kitchen's places were the limit | 돈다 |
| M11 | Quality Sensor | kitchen · 1 | a light sorts lots left and right | grade_split (threshold=90, premium_price=1.2) | lots of quality >= 90 → premium packs (price x1.2), sold only to customers who ask for premium | premium and plain never share a pack | 간판 5 · 포장대 2 | — | 900 / 2분 | — / — / — | perfect hand lots and tuned kettle lots sell for 20% more | 돈다 |
| M12 | Flavor Base Mixer | kitchen · 1 | a whisk turns in a bowl | premix (for=flavored lots, time_saved_ms=1000) | flavor base → flavored lots without the coating wait | asleep until flavors open | 간판 4 | flavors | 700 / 2분 | — / — / — | none until flavors (Step 34) | 체계 대기: flavors |
| M13 | Vent Stabilizer | kitchen · 1 | vents breathe in turn | stabilize (prevents=overheat stops, when_kettles_at_least=3) | the kitchen's heat → no overheat stops | covers the floor | 간판 5 · +M07 | heat_model | 800 / 2분 | — / — / — | three or more kettles keep cooking instead of stopping to cool | 돈다 |
| M14 | Heat Recycler | kitchen · 1 | a coil glows while kettles run | recycle (kettle_upkeep_minus=1, only_while=a kettle is cooking) | the kettles' waste heat → 1 coin a minute less upkeep per cooking kettle (never below 1) | covers the floor | 간판 5 · +M07 | — | 900 / 0분 | minus 1 / minus 2 / minus 3 | -25% kettle upkeep at tier 0 | 돈다 |
| M15 | Smart Job Dispatcher | kitchen · 1 | a screen points kettles at jobs | dispatch (chooses=when each kettle cooks) | the shelf's counts, the orders waiting → no lots nobody needs: kernels, oil and upkeep saved | covers the floor | 간판 5 · +M07 | — | 1000 / 2분 | — / — / — | pays for itself when the kettles out-cook the shop | 돈다 |
| M16 | Rotary Popper | kitchen · 1 | a drum turns and pours a steady stream | produce (makes=lots, portions=2, cycle_ms=2500) | kernels (one lot's worth a lot) → a small lot every 2.5 s | holds when the bin is full | 간판 6 · +M07 | — | 2500 / 6분 | cycle_ms 2500 / cycle_ms 2000 / cycle_ms 1600 | ~48 portions a minute | 돈다 |

## 포장 (P01–P08, Step 30)

| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P01 | Cup Feeder | packing · 1 | a stack of cups lowers one at a time | container (container=cup, size=1) | single portions → cup packs (a new SKU, price 6) | cups only it can fill | 포장대 1 | — | 300 / 1분 | cycle_ms 2000 / cycle_ms 1600 / cycle_ms 1200 | a quarter of customers want a cup once cups exist | 돈다 |
| P02 | Bag Dispenser | packing · 1 | a flat bag opens and drops | container (container=large bag, opens_size=4) | flat large bags → the large bag on sale before the station's tier 2 | one per floor | 포장대 1 | — | 400 / 1분 | — / — / — | large-bag orders (35%) served from tier 1 | 돈다 |
| P03 | Volumetric Filler | packing · 1 | a nozzle fills a bag by volume | pack (makes=packs, cycle_ms=5000) | portions in the bin → a sealed pack on the shelf | holds a sealed pack while the shelf is full | 포장대 1 | — | 350 / 3분 | cycle_ms 5000 / cycle_ms 4000 / cycle_ms 3200 | +12 packs a minute (tier 0) | 돈다 |
| P04 | Portion Weigher | packing · 1 | a pan dips and settles under each pack | weigh (returns_overfill=True, slower_ms=500) | the fillers' packs → exact packs: the overfilled portion back in the bin, 0.5 s slower | covers the floor's fillers | 포장대 2 | — | 500 / 2분 | slower_ms 500 / slower_ms 400 / slower_ms 300 | about one pack in seven keeps its extra portion | 돈다 |
| P05 | Seasoning Sprayer | packing · 1 | a mist of seasoning falls on the portions | season (makes=flavored portions) | flavors → flavored portions | asleep until flavors open | 포장대 2 | flavors | 700 / 2분 | — / — / — | none until flavors (Step 34) | 체계 대기: flavors |
| P06 | Caramel Coater | packing · 1 | caramel cascades over a turning drum | coat (makes=caramel portions, slow=True) | flavors → caramel portions | asleep until flavors open | 포장대 2 | flavors | 900 / 3분 | — / — / — | none until flavors (Step 34) | 체계 대기: flavors |
| P07 | Auto Sealer | packing · 1 | jaws press and crimp each bag | seal (station_cycle_minus=0.25) | filled packs → the station's, the fillers' and the cup feeder's cycles 25/30/35% shorter | covers the floor | 포장대 2 | — | 600 / 2분 | minus 0.25 / minus 0.3 / minus 0.35 | a quarter more packs from the same heads | 돈다 |
| P08 | Package Conveyor Diverter | packing · 1 | an arm swings each pack to its lane | divert (shelf_lanes=per SKU) | sealed packs → premium packs on their own lane (2/3/4 places) -- they never take plain places (flavors' lanes later) | covers the shelf | 포장대 3 | — | 1200 / 2분 | lane 2 / lane 3 / lane 4 | plain keeps its whole shelf while premium waits | 돈다 |

## 가게 (S01–S08, Step 31)

| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S01 | Pickup Belt | shop · 1 | a belt carries packs from the shelf to the counter | convey (service_ms_minus=600) | sealed packs → the counter's hand-over 0.6/0.8/1.0 s shorter | covers the counter | 간판 3 | — | 400 / 1분 | minus 600 / minus 800 / minus 1000 | a quarter more hand-overs a minute | 돈다 |
| S02 | Order Ticket Printer | shop · 1 | tickets curl out and hang over the queue | ticket (patience_paused_while=their pack is being made) | the queue's orders → a customer whose pack is being made does not lose patience | covers the queue | 간판 4 | — | 500 / 1분 | — / — / — | fewer customers leave while the station packs their bag | 돈다 |
| S03 | Auto Cashier | shop · 1 | coins clink into a drawer | cashier (pay_share=0.35) | customers with their pack → counter lanes free 35% sooner; payments one at a time (0.9/0.7/0.5 s) | one drawer | 간판 4 | — | 600 / 2분 | pay_ms 900 / pay_ms 700 / pay_ms 500 | a third more counter throughput while the drawer keeps up | 돈다 |
| S04 | Queue Router | shop · 1 | a light points the next customer to a free lane | route (needs_lanes=2) | the queue, the shelf → no customer waits behind one whose pack is not ready | needs two counter lanes | 간판 5 | — | 700 / 1분 | — / — / — | mixed orders (cups, premium, large) stop blocking the line | 돈다 |
| S05 | Express Window | shop · 1 | a little window with its own bell | express (serves=orders of at most 2 portions) | small orders → an extra lane for small orders (1.5/1.2/0.9 s) | its own lane | 간판 5 | — | 800 / 2분 | service_ms 1500 / service_ms 1200 / service_ms 900 | small orders no longer wait behind large ones | 돈다 |
| S06 | Menu Display Board | shop · 1 | the board lights what is in stock | menu (substitution=a new customer orders a size that is on the shelf (later also flavors)) | the shelf → fewer orders for what is not there | covers the shop | 간판 4 | — | 500 / 1분 | — / — / — | fewer customers wait for a size that is out | 돈다 |
| S07 | Self-Service Kiosk | shop · 1 | a screen lights and a bag drops | serve (service_ms=3000) | the next customer, their pack → a sale | takes the next customer only when the lanes are busy | 간판 3 | — | 500 / 3분 | service_ms 3000 / service_ms 2400 / service_ms 1900 | +20 customers a minute when the counter is the limit | 돈다 |
| S08 | Multi-Lane Serving Robot | shop · 1 | a robot with arms slides along the counter | float_lane (lanes_plus=2) | the queue, the shelf → 2/3/4 more counter lanes | covers the counter | 간판 6 | — | 2000 / 4분 | plus 2 / plus 3 / plus 4 | up to 6 counter lanes; with kiosks and the express window, 8 | 돈다 |

## 보조 (U01–U08, Step 32)

| ID | 이름 | 층·자리 | 보이는 움직임 | 동작 계약 | 입력 → 출력 | 줄·제약 | 선행 | 필요한 체계 | 값 / 유지비 | 단계 | 한계 이익 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U01 | Maintenance Robot | support · 1 | a robot rolls to a stopped machine | repair (fixes=faults (not unpaid)) | a faulted machine → the machine running again | one per factory | 간판 4 | faults | 600 / 2분 | — / — / — | none until machines can fault (Step 32) | 체계 대기: faults |
| U02 | Lubrication Station | support · 1 | an oil can tips over a neighbour | neighbor_speed (cycle_minus=0.1, range=adjacent places) | oil → neighbours' cycles 10% shorter | affects only adjacent places | 간판 4 | oil | 500 / 1분 | — / — / — | neighbours 10% faster once oil exists | Step 32 |
| U03 | Energy Saver | support · 1 | a leaf lamp dims | upkeep (upkeep_per_coin_plus=0.25, applies_to=working machines on its floor) | coins → 25% less upkeep | one per floor | 간판 4 | — | 700 / 0분 | cut 0.25 / cut 0.35 / cut 0.45 | a floor of 4 kettles saves ~4 coins a minute | Step 32 |
| U04 | Buffer Lift | support · 1 | a crate rises between floors | buffer (bin_plus=12, shelf_plus=4) | — → bin +12 portions, shelf +4 packs | one per factory | 간판 3 | — | 500 / 1분 | bin 12, shelf 4 / bin 24, shelf 6 / bin 36, shelf 8 | fewer stalls when a stage pauses | Step 32 |
| U05 | Quality Inspector | support · 1 | a magnifier sweeps the shelf | inspect (threshold=60, for=price-minded customers) | packs below quality 60 → bargain packs | covers the shelf | 간판 5 | customer_preferences | 600 / 1분 | — / — / — | none until customers prefer price or quality (Step 36) | 체계 대기: customer_preferences |
| U06 | Sanitation Bot | support · 1 | a bot leaves a trail of bubbles | freshness (prevents=quality loss of aged stock) | stock in the bin → no aging | covers the floor | 간판 5 | aging | 600 / 2분 | — / — / — | none until stock ages | 체계 대기: aging |
| U07 | Demand Scheduler | support · 1 | a calendar flips to the next rush | schedule (reads=['news', 'preferences']) | news, preferences → the right flavor first | one per factory | 간판 6 | news, flavors | 1200 / 2분 | — / — / — | none until news and flavors (Steps 34, 37) | 체계 대기: news, flavors |
| U08 | Route Balancer | support · 1 | arrows swap between two lines | balance (needs_lines=2) | goods in a blocked line → the same goods in an idle line | needs two parallel lines | 간판 6 | parallel_lines | 1500 / 2분 | — / — / — | none until parallel lines (Step 33) | 체계 대기: parallel_lines |

## 다른 체계와의 고리 (아직 없는 것)

| 체계 | 기다리는 기계 | 생기는 Step |
|---|---|---|
| aging | U06 | 32 |
| customer_preferences | U05 | 36 |
| faults | U01 | 32 |
| flavors | M12, P05, P06, U07 | 34 |
| news | U07 | 37 |
| parallel_lines | U08 | 33 |

## 40대가 함께 (Step 33)

- 층마다 자리가 늘어난다(지금 부엌 4·가운데층 3·가게 2 → M10이 부엌 +2–4, Step 33에서 층마다 줄을 더해 40 자리). 기계 40대는 같은 크기의 작은 그림으로 층마다 줄지어 접히고(`#machines` 아래 배치), 고르면 펼쳐진다.
- 같은 종류를 여러 대 둘 수 있다(값은 대수마다 ×1.25). 40대는 실행기의 상한(`auto_cooker.max`)이고, 수요가 상한일 때 남는 기계는 막혀 쉬고 유지비를 내지 않는다(Step 25 시뮬레이션).

