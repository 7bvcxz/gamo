extends "res://variants/perfect/perfect_rules.gd"

## The three-floor factory's one canonical model (Step 17, design/FACTORY_FLOW.md).
##
## The hand: B's hold and release (inherited -- heat by the exact millisecond,
## the stand's 40 ms edge grace). A release does not pay: it makes one real
## LOT of popcorn in the kettle's glass, its portions and quality set by the
## grade (never fewer than 1 portion).
##
## The flow, in fixed FLOW_STEP_MS steps of total play time (so how frames cut
## time never changes the result):
##   glass --lift--> bin --packer--> shelf --counter--> a customer's hands -> money
## * The glass holds its lot until the bin has room for all of it; while it
##   holds one the kettle cannot heat (backpressure is visible: popcorn in the glass).
## * The packer takes `size` portions from the bin's oldest lots (FIFO), works
##   pack_ms, and puts one sealed pack on the shelf; it starts only when the
##   portions are there and the shelf has a place for it.
## * Customers arrive by a seeded random process (expected ~15 s); the first is
##   already waiting when the shop opens. They queue (cap: others walk past),
##   order a pack, and wait (patience); the counter serves the queue's head
##   only with a pack that matches the order, and money is earned once, when
##   the pack reaches the customer. No customer: packs wait. No pack: the
##   customer waits, then leaves quietly. Nothing is ever substituted or invented.
## Every number is in data/economy.json ("factory"). Every good has an id, and
## every event names the ids it moves (the view follows them, Step 18).

const FLOW_STEP_MS := 50
const GRADE_QUALITY := {PERFECT: 100, NEAR: 80, LATE: 60, EARLY: 50, BURNT: 20}

var glass := {}            ## the lot waiting in the kettle's glass ({} when empty)
var lift: Array = []        ## lots on their way up: {lot, left_ms}
var bin: Array = []         ## lots in the raw bin, oldest first: {id, recipe, quality, portions}
var packing: Array = []     ## packs being filled together (one per head): {id, recipe, size, quality, left_ms}
var packer_tier := 0        ## Step 20: the packing station's upgrade (data: factory.packer)
var sign_tier := 0          ## Step 22: the shop's sign (data: factory.sign) -- the foot traffic
var arrival_log: Array = [] ## Step 22: when each customer came in (flow ms), for the statistics
var first_sale_ms := -1     ## flow ms of the first sale (-1: none yet)
var glass_held_ms := 0      ## Step 24: how long the glass has been holding back the kettle, now
## Step 26: every automation machine, one instance each -- {id, type, floor, slot,
## tier, state (run|idle|paused|unpaid|blocked|starved), left_ms, held (a lot or a
## pack in its hands, or {}), upkeep_ms (work not yet paid for), paid (what it cost),
## assist (lots the hand tuned)}. Processed in the fixed flow steps, in id order.
var machines: Array = []
var next_machine_id := 1
var assist_target := -1    ## the machine the player has selected (a perfect pop tunes it)
var kitchen_heat := 0.0    ## Step 29: the kitchen's heat (0 .. heat.limit)
var pack_rng_state := 0    ## Step 30: the packing floor's own generator (a filler's overfill)
var _prng := RandomNumberGenerator.new()
var overheat_left := 0     ## Step 29: ms the kettles still stop to cool
## The cookers among them (Step 25's name; the same dictionaries).
var cookers: Array:
	get:
		return machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker")
var auto_rng_state := 0
var _arng := RandomNumberGenerator.new()
var order_rng_state := 0    ## Step 23: the orders' own generator (so orders never move arrival times)
## Step 23: what each stage finished in the last minute (flow ms), for the bottleneck cues.
var recent := {"lots": [], "packs": [], "sales": []}
var _orng := RandomNumberGenerator.new()
var shelf: Array = []       ## sealed packs, oldest first: {id, recipe, size, quality}
var queue: Array = []       ## customers waiting, head first: {id, order: {recipe, size}, patience_ms}
## Step 21: the counter's lanes, each handing one pack over: {customer, pack,
## left_ms, lane}. `serving` is the first of them (the one-lane shop, Step 17).
var serves: Array = []
var paying: Array = []      ## Step 31: customers with their pack, waiting at the auto cashier: {customer, pack, left_ms, cashier}
var serving: Dictionary:
	get:
		return serves[0] if not serves.is_empty() else {}
## Step 21: every sale, once, as it was committed (the money's receipt).
var ledger: Array = []
var next_arrival_ms := 0    ## flow time of the next customer (absolute)
var flow_ms := 0            ## flow time done (a multiple of FLOW_STEP_MS)
var rng_state := 0          ## the arrival generator's state (saved)
var next_id := 1
## What happened, for the invariants, the statistics and the tests.
var stats := {"made_portions": 0, "lots": 0, "packed": 0, "sold": 0, "sold_portions": 0, "revenue": 0, "abandoned": 0,
	"passed_by": 0, "arrived": 0, "glass_wait_ms": 0, "packer_starved_ms": 0, "packer_blocked_ms": 0, "counter_empty_ms": 0,
	"visitors": 0, "upkeep_paid": 0, "auto_lots": 0, "auto_portions": 0, "auto_blocked_ms": 0, "auto_unpaid_ms": 0}
var _rng := RandomNumberGenerator.new()


func _init(p_economy: PopEconomy = null, seed_value: int = 20261116) -> void:
	super(p_economy)
	variant = "factory"
	burst_mode = true   # the crescendo is the factory's (Step 19: B -> C as real extra portions)
	_rng.seed = seed_value
	rng_state = int(_rng.state)
	_orng.seed = seed_value + 7919
	order_rng_state = int(_orng.state)
	_arng.seed = seed_value + 104729
	auto_rng_state = int(_arng.state)
	_prng.seed = seed_value + 15485863
	pack_rng_state = int(_prng.state)
	# The first customer is already waiting when the shop opens (design/FACTORY_FLOW.md 5).
	_arrive()
	var f := _t()["customers"] as Dictionary
	next_arrival_ms = _rng.randi_range(int(f["second_ms"][0]), int(f["second_ms"][1]))
	rng_state = int(_rng.state)


func _t() -> Dictionary:
	return economy.table(variant)




func _new_id() -> int:
	next_id += 1
	return next_id - 1


# -- numbers ----------------------------------------------------------------

func kettle_capacity(at_level: int = -1) -> int:
	var lv := level if at_level < 0 else at_level
	var caps: Array = _t()["kettle_portions"]
	return int(caps[clampi(lv, 0, caps.size() - 1)])


## Recovery: the kettle cools faster at some levels (an upgrade's second effect).
func _cooldown_ms() -> int:
	var r: Array = _t()["recovery_ms"]
	var ms := int(r[clampi(level, 0, r.size() - 1)])
	# Step 28, M08 the cooling fan: the hand's kettle recovers sooner.
	if _device_on("M08"):
		ms = maxi(100, ms - int(_tier_value("M08", "minus", 150)))
	return ms


# -- Step 20: the packing station -------------------------------------------

## The packer's current tier: {ms, per_cycle, cost, look} (data: factory.packer).
func packer(at_tier: int = -1) -> Dictionary:
	var tiers: Array = _t()["packer"]
	return tiers[clampi(packer_tier if at_tier < 0 else at_tier, 0, tiers.size() - 1)]


## The next tier's price, or -1 at the top.
func packer_cost() -> int:
	var tiers: Array = _t()["packer"]
	return int(tiers[packer_tier + 1]["cost"]) if packer_tier + 1 < tiers.size() else -1


## Packs a minute the station can make when it is fed and has room (the
## forecast shown before buying; the real rate is in the statistics).
func packs_per_min(at_tier: int) -> float:
	var p := packer(at_tier)
	return 60000.0 / float(p["ms"]) * float(p["per_cycle"])


## What the station is doing: run, starved (no portions), blocked (shelf full), idle.
func packer_state() -> String:
	if not packing.is_empty():
		return "run"
	if shelf.size() >= int(_t()["shelf_packs"]):
		return "blocked"
	if _next_pack().is_empty():
		return "starved"
	return "idle"


## Step 24's unlock policy (one new choice at a time, when it means something):
## the kettle from the start, the packing station once it has sealed a pack,
## the sign once a pack has been sold.
func station_open(station: String) -> bool:
	match station:
		"packer":
			return int(stats["packed"]) >= 1 or packer_tier > 0
		"sign":
			return int(stats["sold"]) >= 1 or sign_tier > 0
		"auto", "cooker":
			return sign_tier >= int(_auto().get("unlock_sign", 2)) or _count("cooker") > 0
		"M01", "M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "P01", "P02", "P04", "P05", "P06", "P07", "P08", "S01", "S02", "S03", "S04", "S05", "S06", "S08":
			var p: Dictionary = catalog(station).get("prereq", {})
			var needs_kettle := (p.get("machines", []) as Array).has("M07")
			return sign_tier >= int(p.get("sign", 0)) and packer_tier >= int(p.get("packer", 0)) and (not needs_kettle or _count("cooker") > 0) or _count(station) > 0
		"bagger", "kiosk":
			var need: Dictionary = catalog(station).get("unlock", {})
			return (packer_tier >= int(need.get("packer", 0)) and sign_tier >= int(need.get("sign", 0))) or _count(station) > 0
	return true


func _buy_packer() -> Dictionary:
	if not station_open("packer"):
		return {"ok": false, "reason": "err.locked"}
	var c := packer_cost()
	if c < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	packer_tier += 1
	_emit("station_upgrade", {"station": "packer", "tier": packer_tier, "cost": c, "money": money})
	return {"ok": true, "tier": packer_tier, "cost": c}


## What a kettle level gives (Step 19: every level changes at least one of
## these, shown now -> next before buying): a perfect pop's portions, the gold's
## width, the cooling time.
func kettle_stats(at_level: int) -> Dictionary:
	var t := _t()
	var lv := clampi(at_level, 0, max_level())
	var r: Array = t["recovery_ms"]
	return {"portions": kettle_capacity(lv),
		"gold_ms": mini(int(t["window_ms"]) + int(t["window_step_ms"]) * lv, int(t["window_max_ms"])),
		"recovery_ms": int(r[clampi(lv, 0, r.size() - 1)])}


## Expected result of ONE attempt (Step 19's balance, design/PROGRESSION.md 4):
## the hand's grade vs the basic auto cooker's odds, in portions and quality.
func hand_attempt(at_level: int, grade: String = PERFECT) -> Dictionary:
	var y := float((_t()["yield"] as Dictionary)[grade])
	return {"portions": float(maxi(1, int(floor(kettle_capacity(at_level) * y)))), "quality": float(GRADE_QUALITY[grade])}


func auto_attempt(_at_level: int = 0) -> Dictionary:
	var a := _t()["auto_cooker"] as Dictionary
	var cap := float(a.get("portions", 4)) * float(a["capacity_share"])
	var portions := 0.0
	var quality := 0.0
	for g: String in (a["grades"] as Dictionary).keys():
		var p := float(a["grades"][g])
		portions += p * maxf(1.0, floor(cap * float((_t()["yield"] as Dictionary)[g])))
		quality += p * float(GRADE_QUALITY[g])
	return {"portions": portions, "quality": quality, "cycle_ms": int(a["cycle_ms"])}


## What the upgrade card shows as '+now > +next': portions of a perfect pop.
func payout(at_level: int) -> int:
	if at_level < 0 or at_level > max_level():
		return -1
	return kettle_capacity(at_level)


func pack_size() -> int:
	return int(_t()["pack"]["size"])


func pack_price(recipe: String, size: int, quality: int) -> int:
	var base := int((_t()["price"] as Dictionary).get(recipe, 0)) * size / pack_size()
	for z: Dictionary in _t().get("sizes", []):
		if int(z["size"]) == size:   # Step 23: the bag's own price (the large one is cheaper per portion)
			base = int(z["price"]) * int((_t()["price"] as Dictionary).get(recipe, 0)) / 10
	return maxi(1, int(round(base * (0.6 + 0.4 * float(quality) / 100.0))))


func bin_portions() -> int:
	var n := 0
	for l: Dictionary in bin:
		n += int(l["portions"])
	return n


func lift_portions() -> int:
	var n := 0
	for x: Dictionary in lift:
		n += int(x["lot"]["portions"])
	return n


## Every portion made, wherever it is now (invariant 1, design/FACTORY_FLOW.md 10).
func portions_everywhere() -> int:
	var n := bin_portions() + lift_portions()
	if not glass.is_empty():
		n += int(glass["portions"])
	for p: Dictionary in packing:
		n += pack_portions(p)
	for p: Dictionary in shelf:
		n += pack_portions(p)
	for sv: Dictionary in serves:
		n += pack_portions(sv["pack"])
	for pv: Dictionary in paying:
		n += pack_portions(pv["pack"])
	for m: Dictionary in machines:
		var h: Dictionary = m["held"]
		if not h.is_empty():
			n += int(h.get("portions", h.get("size", 0)))
	return n + int(stats["sold_portions"])


## Step 30: the portions really in a pack -- its size, or one more when a volumetric
## filler overfilled it (the extra is in the bag, not paid for).
func pack_portions(p: Dictionary) -> int:
	return int(p.get("portions", p.get("size", 0)))


# -- the hand -----------------------------------------------------------------

func _act(kind: String, cmd: Dictionary) -> Dictionary:
	if kind == "buy_packer":
		return _buy_packer()
	if kind == "buy_sign":
		return _buy_sign()
	if kind == "buy_auto":
		return _buy_auto()
	match kind:   # Step 26: the machines' lifecycle
		"build":
			return _build(String(cmd.get("machine", "")), int(cmd.get("slot", -1)))
		"sell_machine":
			return _sell_machine(int(cmd.get("id", -1)))
		"upgrade_machine":
			return _upgrade_machine(int(cmd.get("id", -1)))
		"pause_machine":
			return _pause(int(cmd.get("id", -1)), bool(cmd.get("paused", true)))
		"pause_floor":
			return _pause_floor(String(cmd.get("floor", "")), bool(cmd.get("paused", true)))
		"select_machine":
			assist_target = int(cmd.get("id", -1))
			return {"ok": true}
		"refill":
			return _refill(int(cmd.get("id", -1)))
	if kind == "press" and not glass.is_empty():
		# The glass still holds a lot (the bin is full): no heat until it pours.
		return {"ok": false, "reason": "err.kettle_full"}
	return super(kind, cmd)


## A release (or the burn) makes one real lot in the glass -- no money here.
func _resolve(kind: String) -> Dictionary:
	var t := _t()
	var held := heat_ms
	var yields := t["yield"] as Dictionary
	var portions := maxi(1, int(floor(kettle_capacity() * float(yields[kind]))))
	# The crescendo: the pop that fills it makes a bigger lot -- real popcorn, counted as made.
	portions = _crescendo(portions, kind)
	heating = false
	heat_ms = 0
	cooldown_left = _cooldown_ms()
	outcomes[kind] = int(outcomes[kind]) + 1
	# Step 26, the hand's assist: a perfect pop while a cooker is selected tunes its next
	# lots (bounded: assist_lots, never more) -- a temporary edge the hand gives a line.
	if kind == PERFECT and assist_target >= 0:
		var am := machine(assist_target)
		if not am.is_empty() and String(am["type"]) == "cooker":
			am["assist"] = mini(int(_auto().get("assist_lots", 3)), int(am["assist"]) + int(_auto().get("assist_lots", 3)))
			_emit("machine_assisted", {"machine": assist_target, "lots": am["assist"]})
	var lot := {"id": _new_id(), "recipe": "plain", "quality": int(GRADE_QUALITY[kind]), "portions": portions}
	_sort_and_grade(lot, kind)   # Step 29: M09 re-pops early/late kernels, M11 sends top lots to premium
	portions = int(lot["portions"])
	glass = lot
	stats["made_portions"] = int(stats["made_portions"]) + portions
	stats["lots"] = int(stats["lots"]) + 1
	_note("lots")
	var centre := (window_start() + window_end()) / 2
	_emit("outcome", {"kind": kind, "held_ms": held, "from_centre_ms": held - centre})
	_emit("pop", {"count": portions, "level": level, "outcome": kind})
	_emit("lot_popped", {"lot": lot["id"], "grade": kind, "portions": portions, "quality": lot["quality"]})
	return {"ok": true, "outcome": kind, "pops": portions, "lot": lot["id"]}


# -- time --------------------------------------------------------------------

func _tick(ms: int) -> void:
	var start := now_ms
	super(ms)                 # the heat (and its exact-millisecond burn)
	# The flow in fixed steps of total time: from where it is to start + ms.
	var target := start + ms
	while flow_ms + FLOW_STEP_MS <= target:
		now_ms = flow_ms + FLOW_STEP_MS
		_flow_step(FLOW_STEP_MS)
		flow_ms += FLOW_STEP_MS
	now_ms = start


func _flow_step(dt: int) -> void:
	var t := _t()
	# 1. The glass pours into the lift what the bin will have room for: the whole
	# lot, or (Step 24 fix) a part of it when the lot is bigger than the room --
	# a lot bigger than the whole bin (kettle level 7+, or a burst at 6) used to
	# wait for room that could never come, and stopped the factory for good.
	if not glass.is_empty():
		var room := int(t["bin_portions"]) - bin_portions() - lift_portions()
		var want := int(glass["portions"])
		var full_bin := int(t["bin_portions"])
		if room >= want:
			lift.append({"lot": glass, "left_ms": lift_ms()})
			_emit("lot_lifted", {"lot": glass["id"]})
			glass = {}
		elif room > 0 and (want > full_bin or room >= full_bin / 2):
			var part := {"id": _new_id(), "recipe": glass["recipe"], "quality": glass["quality"], "portions": room}
			glass["portions"] = want - room
			lift.append({"lot": part, "left_ms": lift_ms()})
			_emit("lot_lifted", {"lot": part["id"], "part_of": glass["id"]})
			stats["glass_wait_ms"] = int(stats["glass_wait_ms"]) + dt
		else:
			stats["glass_wait_ms"] = int(stats["glass_wait_ms"]) + dt
	glass_held_ms = glass_held_ms + dt if not glass.is_empty() else 0
	# Step 25: sample the instant's bottleneck once a second (the shown one is the 30 s majority).
	if (flow_ms + dt) % 1000 == 0:
		bn_ring.append(instant_bottleneck())
		if bn_ring.size() > BN_SAMPLES:
			bn_ring.pop_front()
	# 1b. The machines (Steps 25-26).
	_machines_step(dt)
	# 2. The lift lands lots in the bin.
	var still: Array = []
	for x: Dictionary in lift:
		x["left_ms"] = int(x["left_ms"]) - dt
		if int(x["left_ms"]) <= 0:
			bin.append(x["lot"])
			_emit("lot_binned", {"lot": x["lot"]["id"]})
		else:
			still.append(x)
	lift = still
	# 3. The packer: every head fills one pack in the tier's time; a cycle starts
	# with as many packs as there are heads, portions in the bin and places on
	# the shelf (never more -- the shelf is never over-filled).
	if packing.is_empty():
		# Step 23: what to pack is what is wanted -- first the orders waiting (in
		# queue order) that the shelf and the heads do not already cover, then the
		# stock (a small buffer of large bags, small bags for the rest of the shelf).
		var started := 0
		for k in int(packer()["per_cycle"]):
			var want := _next_pack(station_sizes())
			if want.is_empty():
				break
			# shelf_room counts the packs being sealed, so each started pack takes its place.
			if shelf_room(pack_sku(String(want["recipe"]))) <= 0:
				break
			_start_pack(int(want["size"]), String(want["recipe"]))
			started += 1
		if started == 0:
			if shelf_room("plain") <= 0:
				stats["packer_blocked_ms"] = int(stats["packer_blocked_ms"]) + dt
			else:
				stats["packer_starved_ms"] = int(stats["packer_starved_ms"]) + dt
	else:
		var still_packing: Array = []
		for p: Dictionary in packing:
			p["left_ms"] = int(p["left_ms"]) - dt
			if int(p["left_ms"]) <= 0:
				var pack := {"id": p["id"], "recipe": p["recipe"], "size": p["size"], "quality": p["quality"], "portions": pack_portions(p)}
				shelf.append(pack)
				stats["packed"] = int(stats["packed"]) + 1
				_note("packs")
				_emit("pack_shelved", {"pack": pack["id"]})
			else:
				still_packing.append(p)
		packing = still_packing
	# 4. Customers arrive.
	if flow_ms + dt >= next_arrival_ms:
		_arrive()
		_schedule_arrival()
	# 5. Patience: everyone waiting (not the one being served) loses dt.
	var stay: Array = []
	var ticketed := _orders_being_made() if _device_on("S02") else {}
	for c: Dictionary in queue:
		# Step 31, S02 the ticket printer: a customer whose pack is being made keeps their patience.
		var key := "%s|%d" % [c["order"]["recipe"], c["order"]["size"]]
		if int(ticketed.get(key, 0)) > 0:
			ticketed[key] = int(ticketed[key]) - 1
			stats["ticket_saved_ms"] = int(stats.get("ticket_saved_ms", 0)) + dt
			stay.append(c)
			continue
		c["patience_ms"] = int(c["patience_ms"]) - dt
		if int(c["patience_ms"]) <= 0:
			stats["abandoned"] = int(stats["abandoned"]) + 1
			_emit("customer_left", {"customer": c["id"], "why": "waited"})
		else:
			stay.append(c)
	queue = stay
	# 6. The counter: every lane hands its pack over; a free lane takes the head
	# of the queue (in order -- nobody jumps it) when a matching pack is there.
	# Step 31: with the auto cashier (S03) a hand-over is shorter and the customer
	# then pays at the drawer; the router (S04) sends whoever's pack is ready to a
	# free lane; the express window (S05) serves small orders on its own lane.
	var going: Array = []
	for sv: Dictionary in serves:
		sv["left_ms"] = int(sv["left_ms"]) - dt
		if int(sv["left_ms"]) <= 0:
			if bool(sv.get("pay_at_cashier", false)):
				paying.append({"customer": sv["customer"], "pack": sv["pack"], "left_ms": 0, "cashier": -1, "lane": sv["lane"]})
				_emit("handed_over", {"customer": sv["customer"]["id"], "pack": sv["pack"]["id"], "lane": sv["lane"]})
			else:
				_sell(sv)
		else:
			going.append(sv)
	serves = going
	_cashiers_step(dt)
	if serves.is_empty() and queue.is_empty():
		stats["counter_empty_ms"] = int(stats["counter_empty_ms"]) + dt
	while _counter_serving() < lanes() and not queue.is_empty():
		var qi := _next_customer(0)
		if qi < 0:
			break
		var head: Dictionary = queue[qi]
		var idx := _matching_pack(head["order"])
		var pack: Dictionary = shelf[idx]
		shelf.remove_at(idx)
		queue.remove_at(qi)
		if qi > 0:
			stats["routed"] = int(stats.get("routed", 0)) + 1
		var lane := _free_lane()
		var cashier := _cashier_ready()
		var ms := counter_service_ms(cashier)
		serves.append({"customer": head, "pack": pack, "left_ms": ms, "lane": lane, "pay_at_cashier": cashier})
		_emit("serve_started", {"customer": head["id"], "pack": pack["id"], "lane": lane})
	# Step 26: self-serve kiosks take the next customer when the counter's lanes are busy;
	# Step 31: the express window takes the next small order.
	for m: Dictionary in machines:
		if queue.is_empty():
			break
		var kind := String(m["type"])
		if not kind in ["kiosk", "S05"] or String(m["state"]) in ["paused", "unpaid"] or _kiosk_busy(int(m["id"])):
			continue
		var cap_size := int((_t().get("counter_machines", {}) as Dictionary).get("express_max_size", 2)) if kind == "S05" else 0
		var qi := _next_customer(cap_size)
		if qi < 0:
			continue
		var head: Dictionary = queue[qi]
		var idx := _matching_pack(head["order"])
		var pack: Dictionary = shelf[idx]
		shelf.remove_at(idx)
		queue.remove_at(qi)
		if qi > 0:
			stats["routed" if kind == "kiosk" else "express_jumped"] = int(stats.get("routed" if kind == "kiosk" else "express_jumped", 0)) + 1
		var ms := int(_machine_tier(m).get("service_ms", 2500))
		var lane := (100 if kind == "kiosk" else 200) + int(m["slot"])
		serves.append({"customer": head, "pack": pack, "left_ms": ms, "lane": lane, "kiosk": int(m["id"])})
		m["state"] = "run"
		_emit("serve_started", {"customer": head["id"], "pack": pack["id"], "lane": lane, "kiosk": int(m["id"])})


## Step 31: which customer a free lane takes. Without the router only the head of the
## queue (nobody jumps it); with the router (S04, two or more counter lanes) the first
## one whose pack is on the shelf. `max_size` > 0: the express window's small orders
## (the first eligible one in queue order -- it has its own line).
func _next_customer(max_size: int) -> int:
	var look_past := max_size > 0 or (_device_on("S04") and lanes() >= 2)
	for i in queue.size():
		var o: Dictionary = queue[i]["order"]
		if max_size > 0 and int(o["size"]) > max_size:
			continue
		if _matching_pack(o) >= 0:
			return i
		if not look_past:
			return -1
	return -1


## A counter hand-over's time: the base, minus the pickup belt (S01), and only the
## handing part when an auto cashier (S03) will take the payment.
func counter_service_ms(at_cashier: bool = false) -> int:
	var ms := int(_t()["service_ms"])
	if _device_on("S01"):
		ms -= _tier_value("S01", "minus", 600)
	ms = maxi(600, ms)
	if at_cashier:
		ms = int(round(ms * (1.0 - float((_t().get("counter_machines", {}) as Dictionary).get("pay_share", 0.35)))))
	return ms


## Is an auto cashier working (not paused, not unpaid)? Then lanes hand over and the
## customer pays at its drawer.
func _cashier_ready() -> bool:
	return _device_on("S03")


## The drawers: each working cashier takes the first customer waiting to pay and
## needs its tier's time; the sale (money) happens when they have paid. A paused
## cashier's customers wait -- nobody pays nothing, nothing is sold early.
func _cashiers_step(dt: int) -> void:
	if not paying.is_empty() and not machines.any(func(x: Dictionary) -> bool: return String(x["type"]) == "S03"):
		for pv: Dictionary in paying:   # no drawer left (sold): the clerk takes the money
			_sell(pv)
		paying.clear()
		return
	for m: Dictionary in machines:
		if String(m["type"]) != "S03" or String(m["state"]) in ["paused", "unpaid"]:
			continue
		var mine: Dictionary = {}
		for pv: Dictionary in paying:
			if int(pv["cashier"]) == int(m["id"]):
				mine = pv
				break
		if mine.is_empty():
			for pv: Dictionary in paying:
				if int(pv["cashier"]) < 0:
					pv["cashier"] = int(m["id"])
					pv["left_ms"] = int(_machine_tier(m).get("pay_ms", 900))
					mine = pv
					break
		if mine.is_empty():
			continue
		mine["left_ms"] = int(mine["left_ms"]) - dt
		if int(mine["left_ms"]) <= 0:
			paying.erase(mine)
			m["done"] = int(m.get("done", 0)) + 1
			_sell(mine)


## Step 31, S02: the orders a pack is being made for right now (the station's heads,
## the fillers' and cup feeder's hands), by SKU and size.
func _orders_being_made() -> Dictionary:
	var out := {}
	var making: Array = packing.duplicate()
	for m: Dictionary in machines:
		if String(m["type"]) in ["bagger", "P01"] and not (m["held"] as Dictionary).is_empty():
			making.append(m["held"])
	for p: Dictionary in making:
		var key := "%s|%d" % [p["recipe"], p["size"]]
		out[key] = int(out.get(key, 0)) + 1
	return out


## Step 31: the storefront's devices work (and pay) while the shop has customers.
func _shop_device_step(m: Dictionary, dt: int) -> void:
	var busy := not queue.is_empty() or not serves.is_empty() or (String(m["type"]) == "S03" and paying.any(func(pv: Dictionary) -> bool: return int(pv["cashier"]) == int(m["id"])))
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## The oldest recipe in the bin with a whole pack's portions ("" = none): a
## pack is never filled from two recipes, and a lone leftover portion waits.
func packable_recipe(size: int = -1) -> String:
	var need := pack_size() if size < 0 else size
	var seen := {}
	for lot: Dictionary in bin:
		var r := String(lot["recipe"])
		if seen.has(r):
			continue
		seen[r] = true
		if bin_portions_of(r) >= need:
			return r
	return ""


# -- Step 23: orders, sizes, what to pack -------------------------------------

## The bags open now (smallest first): the small one always, the large one from its packing tier.
func sizes_open() -> Array:
	var out: Array = []
	for z: Dictionary in _t().get("sizes", [{"size": pack_size(), "price": 10, "unlock_packer": 0}]):
		if z.has("unlock_machine") and not _device_on(String(z["unlock_machine"])):
			continue   # Step 30: cups exist while a cup feeder runs
		if packer_tier >= int(z.get("unlock_packer", 0)) or (z.has("unlock_machine_early") and _device_on(String(z["unlock_machine_early"]))):
			out.append(z)
	return out


## Step 30: the sizes the station and the fillers pack (bags; cups are P01's).
func station_sizes() -> Array:
	return sizes_open().filter(func(z: Dictionary) -> bool: return not z.has("unlock_machine")).map(func(z: Dictionary) -> int: return int(z["size"]))


## Step 30, P07 the auto sealer: sealing apart from filling -- every packing cycle shorter.
func seal_factor() -> float:
	if not _device_on("P07"):
		return 1.0
	var best := 0.0
	for d: Dictionary in _devices("P07"):
		best = maxf(best, float(_machine_tier(d).get("minus", 0.25)))
	return 1.0 - best


## Step 30, P08 the diverter: premium on its own lane (its tier's places), so it never
## takes plain places; without it every SKU shares the shelf.
func premium_lane() -> int:
	var best := 0
	for d: Dictionary in _devices("P08"):
		best = maxi(best, int(_machine_tier(d).get("lane", 2)))
	return best


func shelf_cap() -> int:
	return int(_t()["shelf_packs"]) + premium_lane()


## Places left on the shelf for a pack of this SKU (sealed packs and packs being
## sealed by the station count; a filler's own pack is checked again when it is sealed).
func shelf_room(sku: String) -> int:
	var lane := premium_lane()
	var on: Array = shelf + packing
	if lane > 0 and sku == "premium":
		return lane - on.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) == "premium").size()
	var plain_on := on.size() if lane == 0 else on.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) != "premium").size()
	return int(_t()["shelf_packs"]) - plain_on


## Packs of an SKU and size on the shelf or being filled.
func on_hand(sku: String, size: int) -> int:
	var n := 0
	var bagged: Array = []
	for m: Dictionary in machines:
		if String(m["type"]) == "bagger" and not (m["held"] as Dictionary).is_empty():
			bagged.append(m["held"])
	for p: Dictionary in shelf + packing + bagged:
		if String(p["recipe"]) == sku and int(p["size"]) == size:
			n += 1
	return n


func _recipe_for(sku: String, size: int) -> String:
	for lot: Dictionary in bin:
		var r := String(lot["recipe"])
		if pack_sku(r) == sku and bin_portions_of(r) >= size:
			return r
	return ""


## The next pack to fill ({recipe, size, for}) or {} -- nothing wanted, or not
## enough popcorn of the wanted kind (then the station waits: it never packs the
## popcorn an order needs into another bag).
func _next_pack(allowed: Array = []) -> Dictionary:
	var covered := {}
	for c: Dictionary in queue:
		var o: Dictionary = c["order"]
		if not allowed.is_empty() and not allowed.has(int(o["size"])):
			continue   # Step 30: cups are the cup feeder's; the station and the fillers pack bags
		var key := "%s|%d" % [o["recipe"], o["size"]]
		var have := int(covered.get(key, on_hand(String(o["recipe"]), int(o["size"]))))
		if have > 0:
			covered[key] = have - 1
			continue
		var r := _recipe_for(String(o["recipe"]), int(o["size"]))
		return {} if r == "" else {"recipe": r, "size": int(o["size"]), "for": "order"}
	var cap := int(_t()["shelf_packs"])
	var reserved := 0
	var open := sizes_open()
	for z: Dictionary in open:
		reserved += int(z.get("stock", 0))
	for z: Dictionary in open:
		var size := int(z["size"])
		if not allowed.is_empty() and not allowed.has(size):
			continue
		var target := int(z.get("stock", 0)) if z.has("stock") else cap - reserved
		# Each SKU in the bin (oldest first) against its own target; premium keeps one
		# pack of a size in stock (only premium customers buy it: Step 29).
		var seen := {}
		for lot: Dictionary in bin:
			var r := String(lot["recipe"])
			if seen.has(r):
				continue
			seen[r] = true
			if bin_portions_of(r) < size:
				continue
			var sku := pack_sku(r)
			var t := mini(target, 1) if sku == "premium" else target
			if on_hand(sku, size) < t:
				return {"recipe": r, "size": size, "for": "stock"}
	return {}


## Customers' orders: the small bag, or once the large one is open, the large
## one by its share -- drawn from the orders' own generator.
func _draw_order() -> Dictionary:
	var size := pack_size()
	_orng.state = order_rng_state
	for z: Dictionary in sizes_open():
		if z.has("order_share") and _orng.randf() < float(z["order_share"]):
			size = int(z["size"])
	# Step 29: while premium popcorn is on hand (M11 sorts it), some customers ask for it --
	# and only they buy it (the draw happens only then, so plain-only order streams are unchanged).
	var recipe := "plain"
	var pr: Dictionary = _t().get("premium", {})
	if _device_on("M11") and (bin_portions_of("premium") >= size or on_hand("premium", size) > 0):
		if _orng.randf() < float(pr.get("order_share", 0.3)):
			recipe = "premium"
	order_rng_state = int(_orng.state)
	# Step 31, S06 the menu board: a new customer sees what is on the shelf and orders a
	# size that is there when theirs is not (no extra draw: the order stream is the same).
	if _device_on("S06") and _matching_pack({"recipe": recipe, "size": size}) < 0:
		var choices: Array = station_sizes()
		if _device_on("P01"):
			choices.append(1)
		for z: int in choices:
			if _matching_pack({"recipe": recipe, "size": z}) >= 0:
				stats["menu_switched"] = int(stats.get("menu_switched", 0)) + 1
				size = z
				break
	return {"recipe": recipe, "size": size}


func _note(stage: String) -> void:
	var a: Array = recent[stage]
	a.append(flow_ms)
	while not a.is_empty() and int(a[0]) <= flow_ms - 60000:
		a.pop_front()


## What a stage finished in the last minute (lots popped, packs sealed, sales).
func per_min(stage: String) -> int:
	var n := 0
	for t: int in recent[stage]:
		if t > flow_ms - 60000:
			n += 1
	return n


func bin_portions_of(recipe: String) -> int:
	var n := 0
	for lot: Dictionary in bin:
		if String(lot["recipe"]) == recipe:
			n += int(lot["portions"])
	return n


## The SKU a recipe's popcorn is packed as (data: factory.pack_recipes; the
## seasoning step of a later Step changes it, never the portions).
func pack_sku(recipe: String) -> String:
	return String((_t().get("pack_recipes", {}) as Dictionary).get(recipe, recipe))


## Takes `size` portions of `recipe` from the bin's oldest lots of it (FIFO)
## into a new pack; its quality is the portions' average (nothing lost).
func _start_pack(size: int, recipe: String) -> void:
	var pack := _take_pack(size, recipe)
	var ms := int(round(float(packer()["ms"]) * seal_factor()))
	pack["left_ms"] = ms
	pack["ms"] = ms
	packing.append(pack)
	_emit("pack_started", {"pack": pack["id"], "lots": pack["lots"], "size": size, "head": packing.size() - 1, "ms": ms, "recipe": pack["recipe"]})


## Takes `size` portions of `recipe` from the bin's oldest lots of it into a new
## pack (shared by the station and the baggers, Step 26).
func _take_pack(size: int, recipe: String) -> Dictionary:
	var need := size
	var q_sum := 0
	var used: Array = []
	var i := 0
	while need > 0:
		var lot: Dictionary = bin[i]
		if String(lot["recipe"]) != recipe:
			i += 1
			continue
		var take := mini(need, int(lot["portions"]))
		lot["portions"] = int(lot["portions"]) - take
		q_sum += take * int(lot["quality"])
		need -= take
		used.append(lot["id"])
		if int(lot["portions"]) <= 0:
			bin.remove_at(i)
	return {"id": _new_id(), "recipe": pack_sku(recipe), "size": size, "quality": q_sum / size, "lots": used}


func _matching_pack(order: Dictionary) -> int:
	for i in shelf.size():
		var p: Dictionary = shelf[i]
		if String(p["recipe"]) == String(order["recipe"]) and int(p["size"]) == int(order["size"]):
			return i
	return -1


## The counter's lanes (data: factory.counter.lanes; Step 24's shop tree adds more).
func lanes() -> int:
	var n := maxi(maxi(1, int((_t().get("counter", {}) as Dictionary).get("lanes", 1))), int(shop_sign().get("lanes", 1)))
	# Step 31, S08 the serving robot: more counter lanes (its best tier).
	var plus := 0
	for d: Dictionary in _devices("S08"):
		plus = maxi(plus, int(_machine_tier(d).get("plus", 2)))
	return n + plus


# -- Step 22: the sign and the foot traffic ------------------------------------

func shop_sign(at_tier: int = -1) -> Dictionary:
	var tiers: Array = _t()["sign"]
	return tiers[clampi(sign_tier if at_tier < 0 else at_tier, 0, tiers.size() - 1)]


func sign_cost() -> int:
	var tiers: Array = _t()["sign"]
	return int(tiers[sign_tier + 1]["cost"]) if sign_tier + 1 < tiers.size() else -1


func queue_cap() -> int:
	return int(shop_sign().get("queue_cap", 5))


## The expected wait between customers at a tier: the triangle's mean.
func mean_wait_ms(at_tier: int) -> int:
	var s := shop_sign(at_tier)
	return int((float(s["min_ms"]) + float(s["mode_ms"]) + float(s["max_ms"])) / 3.0)


func _buy_sign() -> Dictionary:
	if not station_open("sign"):
		return {"ok": false, "reason": "err.locked"}
	var c := sign_cost()
	if c < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	sign_tier += 1
	_emit("station_upgrade", {"station": "sign", "tier": sign_tier, "cost": c, "money": money})
	return {"ok": true, "tier": sign_tier, "cost": c}


# -- Steps 25-26: the machines --------------------------------------------------
## The catalog: `auto_cooker` is the cooker's entry (Step 25); `machines` holds the
## others; `slots` how many places each floor has.

const FLOOR_OF := {"cooker": "kitchen", "bagger": "packing", "kiosk": "shop",
	"M01": "kitchen", "M02": "kitchen", "M03": "kitchen", "M04": "kitchen", "M05": "kitchen", "M06": "kitchen", "M08": "kitchen",
	"M09": "kitchen", "M10": "kitchen", "M11": "kitchen", "M12": "kitchen", "M13": "kitchen", "M14": "kitchen", "M15": "kitchen", "M16": "kitchen",
	"P01": "packing", "P02": "packing", "P04": "packing", "P05": "packing", "P06": "packing", "P07": "packing", "P08": "packing",
	"S01": "shop", "S02": "shop", "S03": "shop", "S04": "shop", "S05": "shop", "S06": "shop", "S08": "shop"}
## Step 28: the kitchen's devices that serve the kettles (each a catalog id and its own runtime).
const KITCHEN_DEVICES := ["M01", "M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M12", "M13", "M14", "M15", "M16"]
## Step 29: what cooks lots on its own (the auto kettle and the rotary popper): kernels,
## hoppers, the heat and the dispatcher treat them alike.
const KETTLES := ["cooker", "M16"]
## Step 30: the packing floor's machines besides the bagger (P03).
const PACKING_DEVICES := ["P01", "P02", "P04", "P05", "P06", "P07", "P08"]
## Step 31: the storefront's machines besides the kiosk (S07).
const SHOP_DEVICES := ["S01", "S02", "S03", "S04", "S05", "S06", "S08"]
const CATALOG_PATH := "res://data/machines.json"
var _forty: Dictionary = {}


## Step 27: the canonical 40-machine catalog (data/machines.json), by id (read once
## per run; a static cache leaked at exit in the test runner).
func forty() -> Dictionary:
	if _forty.is_empty():
		var text := FileAccess.get_file_as_string(CATALOG_PATH)
		var doc: Variant = JSON.parse_string(text)
		if typeof(doc) == TYPE_DICTIONARY:
			for m: Dictionary in doc["machines"]:
				_forty[String(m["id"])] = m
			_forty["_systems"] = doc.get("systems_present", [])
	return _forty


## Whether a catalog machine can be built now: it runs in the model (a runtime type)
## and every system it needs exists -- otherwise it does nothing, so it is not sold.
func catalog_buildable(id: String) -> bool:
	var e: Dictionary = forty().get(id, {})
	if e.is_empty() or e.get("runtime") == null:
		return false
	var have: Array = forty()["_systems"]
	for need: String in e.get("requires", []):
		if not have.has(need):
			return false
	return true


func catalog(type: String) -> Dictionary:
	if type == "cooker":
		return _t()["auto_cooker"]
	var own: Dictionary = (_t().get("machines", {}) as Dictionary).get(type, {})
	if not own.is_empty():
		return own
	return forty().get(type, {})   # Step 28: the catalog entry itself (data/machines.json)


func _auto() -> Dictionary:
	return catalog("cooker")


func slots(floor: String) -> int:
	var n := int((_t().get("slots", {}) as Dictionary).get(floor, 0))
	if floor == "kitchen":
		n += _kitchen_plus()
	return n


## Step 29, M10 the multi-pot distributor: more kitchen places (each distributor its tier's).
func _kitchen_plus(skip_id: int = -1) -> int:
	var n := 0
	for m: Dictionary in machines:
		if String(m["type"]) == "M10" and int(m["id"]) != skip_id:
			n += int(_machine_tier(m).get("plus", 2))
	return n


func _is_kettle(m: Dictionary) -> bool:
	return KETTLES.has(String(m.get("type", "")))


func machine(id: int) -> Dictionary:
	for m: Dictionary in machines:
		if int(m["id"]) == id:
			return m
	return {}


func machine_at(floor: String, slot: int) -> Dictionary:
	for m: Dictionary in machines:
		if String(m["floor"]) == floor and int(m["slot"]) == slot:
			return m
	return {}


func _count(type: String) -> int:
	return machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == type).size()


## The next one of a type: cost x growth^(how many there are), or -1 (none left to build).
func build_cost(type: String) -> int:
	var c := catalog(type)
	if c.is_empty() or machines.size() >= int(_auto().get("max", 40)):
		return -1
	return int(round(float(c["cost"]) * pow(float(c["growth"]), _count(type))))


func auto_cost() -> int:
	return build_cost("cooker")


func _machine_tier(m: Dictionary) -> Dictionary:
	var tiers: Array = catalog(String(m["type"])).get("tiers", [{}])
	return tiers[clampi(int(m["tier"]), 0, tiers.size() - 1)]


func machine_upgrade_cost(m: Dictionary) -> int:
	var tiers: Array = catalog(String(m["type"])).get("tiers", [{}])
	return int(tiers[int(m["tier"]) + 1]["cost"]) if int(m["tier"]) + 1 < tiers.size() else -1


func _free_slot(floor: String) -> int:
	for k in slots(floor):
		if machine_at(floor, k).is_empty():
			return k
	return -1


func _build(type: String, slot: int) -> Dictionary:
	# A catalog id (Step 27): only the ones that run are built (no invented benefit).
	if forty().has(type):
		if not catalog_buildable(type):
			return {"ok": false, "reason": "err.not_yet"}
		type = String(forty()[type]["runtime"])
	var c := catalog(type)
	if c.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	if not station_open(type):
		return {"ok": false, "reason": "err.locked"}
	var floor := String(FLOOR_OF[type])
	if slot < 0:
		slot = _free_slot(floor)
	if slot < 0 or slot >= slots(floor):
		return {"ok": false, "reason": "err.no_slot"}
	if not machine_at(floor, slot).is_empty():
		return {"ok": false, "reason": "err.slot_taken"}
	var cost := build_cost(type)
	if cost < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < cost:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= cost
	var m := {"id": next_machine_id, "type": type, "floor": floor, "slot": slot, "tier": 0, "state": "idle", "kernels": int(_auto().get("kernel_buffer", 5)) if KETTLES.has(type) else 0,
		"left_ms": int(_machine_tier_of(type, 0).get("cycle_ms", c.get("cycle_ms", 6000))), "held": {}, "upkeep_ms": 0, "paid": cost, "assist": 0}
	next_machine_id += 1
	machines.append(m)
	_emit("station_upgrade", {"station": type, "tier": _count(type), "cost": cost, "money": money, "machine": m["id"], "slot": slot})
	_emit("machine_built", {"machine": m["id"], "type": type, "slot": slot})
	return {"ok": true, "machine": m["id"], "cost": cost}


func _machine_tier_of(type: String, tier: int) -> Dictionary:
	var tiers: Array = catalog(type).get("tiers", [{}])
	return tiers[clampi(tier, 0, tiers.size() - 1)]


func _buy_auto() -> Dictionary:
	return _build("cooker", -1)


## Selling gives half of what it cost back; a machine holding goods finishes
## with them first (it cannot drop popcorn on the floor).
func _sell_machine(id: int) -> Dictionary:
	var m := machine(id)
	if m.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	if not (m["held"] as Dictionary).is_empty() or _kiosk_busy(id) or paying.any(func(pv: Dictionary) -> bool: return int(pv["cashier"]) == id):
		return {"ok": false, "reason": "err.busy"}
	if String(m["type"]) == "M10":
		var left := int((_t().get("slots", {}) as Dictionary).get("kitchen", 0)) + _kitchen_plus(id)
		for x: Dictionary in machines:
			if String(x["floor"]) == "kitchen" and int(x["slot"]) >= left and int(x["id"]) != id:
				return {"ok": false, "reason": "err.slot_taken"}   # its places hold machines
	var refund := int(m["paid"]) / 2
	money += refund
	machines.erase(m)
	if assist_target == id:
		assist_target = -1
	_emit("machine_sold", {"machine": id, "refund": refund, "money": money})
	return {"ok": true, "refund": refund}


func _upgrade_machine(id: int) -> Dictionary:
	var m := machine(id)
	if m.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	var c := machine_upgrade_cost(m)
	if c < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	m["tier"] = int(m["tier"]) + 1
	m["paid"] = int(m["paid"]) + c
	_emit("machine_upgraded", {"machine": id, "tier": m["tier"], "cost": c, "money": money})
	return {"ok": true, "tier": m["tier"], "cost": c}


## Pausing keeps what it was doing (its lot, its pack, its timer); resuming continues.
func _pause(id: int, paused: bool) -> Dictionary:
	var m := machine(id)
	if m.is_empty():
		return {"ok": false, "reason": "err.unknown"}
	m["state"] = "paused" if paused else "idle"
	_emit("machine_paused", {"machine": id, "paused": paused})
	return {"ok": true}


func _pause_floor(floor: String, paused: bool) -> Dictionary:
	var n := 0
	for m: Dictionary in machines:
		if String(m["floor"]) == floor:
			_pause(int(m["id"]), paused)
			n += 1
	return {"ok": n > 0, "machines": n}


func _kiosk_busy(id: int) -> bool:
	for sv: Dictionary in serves:
		if int(sv.get("kiosk", -1)) == id:
			return true
	return false


func _counter_serving() -> int:
	var n := 0
	for sv: Dictionary in serves:
		if not sv.has("kiosk"):
			n += 1
	return n


## Upkeep for `dt` of work, a whole coin at a time; false (and the machine
## pauses as "unpaid") when a coin is due and there is none -- never a debt.
func _pay(m: Dictionary, dt: int) -> bool:
	var per_min := int(catalog(String(m["type"]))["upkeep_per_min"])
	# Step 29, M14 the heat recycler: a cooking kettle's own heat pays part of its keep (never all of it).
	if _is_kettle(m) and _device_on("M14"):
		per_min = maxi(1, per_min - _tier_value("M14", "minus", 1))
	if per_min <= 0:
		return true
	var per_coin := maxi(1, 60000 / maxi(1, per_min))
	var owed := int(m["upkeep_ms"]) + dt
	if owed >= per_coin:
		if money < 1:
			m["state"] = "unpaid"
			stats["auto_unpaid_ms"] = int(stats["auto_unpaid_ms"]) + dt
			return false
		money -= 1
		stats["upkeep_paid"] = int(stats["upkeep_paid"]) + 1
		owed -= per_coin
	m["upkeep_ms"] = owed
	return true


func _machines_step(dt: int) -> void:
	_heat_step(dt)
	for m: Dictionary in machines:
		if String(m["state"]) == "paused":
			continue
		match String(m["type"]):
			"cooker", "M16":
				_cooker_step(m, dt)
			"bagger", "P01":
				_bagger_step(m, dt)
			"P02", "P04", "P07", "P08":
				_packing_device_step(m, dt)
			"kiosk", "S05":
				_kiosk_step(m, dt)
			"S01", "S02", "S03", "S04", "S06", "S08":
				_shop_device_step(m, dt)
			"M01":
				_hopper_step(m, dt)
			"M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M13", "M14", "M15":
				_device_step(m, dt)


## A cooker finishes a lot every cycle; the lot goes up when the bin has room for it,
## else the cooker holds it (blocked, no upkeep).
func _cooker_step(m: Dictionary, dt: int) -> void:
	if not (m["held"] as Dictionary).is_empty():
		var lot: Dictionary = m["held"]
		var room := int(_t()["bin_portions"]) - bin_portions() - lift_portions()
		if room < int(lot["portions"]):
			m["state"] = "blocked"
			stats["auto_blocked_ms"] = int(stats["auto_blocked_ms"]) + dt
			return
		lift.append({"lot": lot, "left_ms": lift_ms()})
		_emit("lot_lifted", {"lot": lot["id"], "from": "auto", "machine": m["id"]})
		m["held"] = {}
	# Step 28: a kettle cooks only with kernels in its hopper (one lot's worth a cycle).
	if int(m.get("kernels", 0)) <= 0:
		m["state"] = "starved"
		return
	# Step 29: the kitchen too hot (no vent stabilizer) -- every kettle stops to cool.
	if overheat_left > 0:
		m["state"] = "overheat"
		return
	# Step 29, M15 the dispatcher: a new lot starts only when the shelf and the orders need it.
	if int(m["left_ms"]) >= _cooker_cycle(m) and _device_on("M15") and not demand_wants_lot():
		m["state"] = "waiting"
		stats["dispatch_held_ms"] = int(stats.get("dispatch_held_ms", 0)) + dt
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"
	m["left_ms"] = mini(int(m["left_ms"]), _cooker_cycle(m)) - dt
	if int(m["left_ms"]) <= 0:
		m["left_ms"] = _cooker_cycle(m)
		m["kernels"] = int(m["kernels"]) - 1
		m["held"] = _rotary_lot(m) if String(m["type"]) == "M16" else _auto_lot(m)
		m["done"] = int(m.get("done", 0)) + 1


## A bagger fills one pack at a time with what is wanted (the same rule as the
## station), from real portions in the bin; it waits (starved) with nothing to
## pack and holds a sealed pack (blocked) while the shelf is full. Step 30: the cup
## feeder (P01) is the same machine for cups; a bagger is volumetric -- it overfills
## a pack by a portion now and then unless a portion weigher (P04) runs.
func _bagger_step(m: Dictionary, dt: int) -> void:
	var cups := String(m["type"]) == "P01"
	var h: Dictionary = m["held"]
	if h.is_empty():
		var allowed: Array = [1] if cups else station_sizes()
		var want := _next_pack(allowed)
		if want.is_empty():
			m["state"] = "starved" if shelf_room("plain") > 0 else "blocked"
			return
		if shelf_room(pack_sku(String(want["recipe"]))) <= 0:
			m["state"] = "blocked"
			return
		var pack := _take_pack(int(want["size"]), String(want["recipe"]))
		var ms := float(_machine_tier(m).get("cycle_ms", 5000 if not cups else 2000))
		if not cups:
			if _device_on("P04"):
				ms += float(_tier_value("P04", "slower_ms", 500))
			elif _overfills() and bin_portions_of(String(want["recipe"])) > 0:
				_take_extra(pack, String(want["recipe"]))
		pack["left_ms"] = int(round(ms * seal_factor()))
		m["held"] = pack
		_emit("bagger_started", {"machine": m["id"], "pack": pack["id"], "size": pack["size"], "ms": pack["left_ms"]})
		return
	if int(h["left_ms"]) > 0:
		if not _pay(m, dt):
			return
		m["state"] = "run"
		h["left_ms"] = int(h["left_ms"]) - dt
		return
	if shelf_room(String(h["recipe"])) <= 0:
		m["state"] = "blocked"
		return
	shelf.append({"id": h["id"], "recipe": h["recipe"], "size": h["size"], "quality": h["quality"], "portions": pack_portions(h)})
	stats["packed"] = int(stats["packed"]) + 1
	_note("packs")
	m["held"] = {}
	m["done"] = int(m.get("done", 0)) + 1
	_emit("pack_shelved", {"pack": h["id"], "machine": m["id"]})


## Step 30: does this volumetric fill overshoot? (the packing floor's own generator)
func _overfills() -> bool:
	_prng.state = pack_rng_state
	var hit := _prng.randf() < float((_t().get("fill", {}) as Dictionary).get("overfill_chance", 0.0))
	pack_rng_state = int(_prng.state)
	return hit


## One more portion of `recipe` from the bin's oldest lot into `pack` (an overfill).
func _take_extra(pack: Dictionary, recipe: String) -> void:
	for i in bin.size():
		var lot: Dictionary = bin[i]
		if String(lot["recipe"]) == recipe and int(lot["portions"]) > 0:
			lot["portions"] = int(lot["portions"]) - 1
			if int(lot["portions"]) <= 0:
				bin.remove_at(i)
			pack["portions"] = int(pack["size"]) + 1
			stats["overfill_portions"] = int(stats.get("overfill_portions", 0)) + 1
			return


## A kiosk pays only while it hands a pack over (the counter loop gives it customers).
func _kiosk_step(m: Dictionary, dt: int) -> void:
	if _kiosk_busy(int(m["id"])):
		if not _pay(m, dt):
			# No coin: the hand-over in progress stops where it is (its time does not run).
			for sv: Dictionary in serves:
				if int(sv.get("kiosk", -1)) == int(m["id"]):
					sv["left_ms"] = int(sv["left_ms"]) + dt
			return
		m["state"] = "run"
	elif String(m["state"]) != "unpaid" or money >= 1:
		m["state"] = "idle"


func _auto_lot(m: Dictionary = {}) -> Dictionary:
	var a := _auto()
	_arng.state = auto_rng_state
	var u := _arng.randf()
	auto_rng_state = int(_arng.state)
	var grade := LATE
	var acc := 0.0
	for g: String in (a["grades"] as Dictionary).keys():
		acc += float(a["grades"][g])
		if u < acc:
			grade = g
			break
	# Step 28: the devices a kettle has -- M03 holds the heat (no burnt), M05 takes the
	# lot out in time (no late) for the kettles it covers.
	if grade == BURNT and _device_on("M03"):
		grade = NEAR
	if grade == LATE and not m.is_empty() and _covered(m, "M05"):
		grade = NEAR
	# Step 26: lots the hand tuned (a perfect pop while this cooker was selected) come out perfect.
	if not m.is_empty() and int(m.get("assist", 0)) > 0:
		grade = PERFECT
		m["assist"] = int(m["assist"]) - 1
	var cap := float(a.get("portions", kettle_capacity())) * float(a["capacity_share"])
	var portions := maxi(1, int(floor(cap * float((_t()["yield"] as Dictionary)[grade]))))
	# M04 the agitation motor: an evenly stirred lot pops more of its kernels.
	if not m.is_empty() and _covered(m, "M04"):
		portions += int(_tier_value("M04", "bonus", 1))
	var quality := int(GRADE_QUALITY[grade])
	quality = _oil(quality)
	var lot := {"id": _new_id(), "recipe": "plain", "quality": quality, "portions": portions}
	_sort_and_grade(lot, grade)
	portions = int(lot["portions"])
	stats["made_portions"] = int(stats["made_portions"]) + portions
	stats["auto_lots"] = int(stats["auto_lots"]) + 1
	stats["auto_" + grade] = int(stats.get("auto_" + grade, 0)) + 1   # Step 28: the grades the devices change
	stats["auto_portions"] = int(stats["auto_portions"]) + portions
	_note("lots")
	_emit("auto_lot", {"lot": lot["id"], "grade": grade, "portions": portions, "machine": m.get("id", -1)})
	return lot


## M02 the oil doser: a measured drop of oil (paid for) makes the lot taste better.
func _oil(quality: int) -> int:
	var oil := int(_auto().get("oil_price", 1))
	if _device_on("M02") and money >= oil:
		money -= oil
		stats["oil_paid"] = int(stats.get("oil_paid", 0)) + oil
		return mini(100, quality + 10)
	return quality


# -- Step 29: the advanced kitchen (M09-M16), the kitchen's heat, premium ------------

## M09 the kernel sorter re-pops an early or late lot's unpopped kernels: near quality,
## one portion fewer (never none). M11 the quality sensor sends a lot of quality >=
## threshold to the premium SKU -- its own packs, never mixed with plain.
func _sort_and_grade(lot: Dictionary, grade: String) -> void:
	if grade in [EARLY, LATE] and _device_on("M09"):
		lot["quality"] = maxi(int(lot["quality"]), int(GRADE_QUALITY[NEAR]))
		if int(lot["portions"]) > 1:
			lot["portions"] = int(lot["portions"]) - 1   # the kernels it lost were never popcorn (callers count what is left)
		stats["sorted_lots"] = int(stats.get("sorted_lots", 0)) + 1
	var pr: Dictionary = _t().get("premium", {})
	# The sensor's premium bin holds `bin` portions; full, it lets lots through as plain
	# (premium never clogs the plain line).
	if _device_on("M11") and int(lot["quality"]) >= int(pr.get("threshold", 90)) and premium_waiting() < int(pr.get("bin", 12)):
		lot["recipe"] = "premium"
		stats["premium_lots"] = int(stats.get("premium_lots", 0)) + 1


## Premium portions made but not yet packed (the bin, the lift, the glass).
func premium_waiting() -> int:
	var n := bin_portions_of("premium")
	for l: Dictionary in lift:
		if String((l["lot"] as Dictionary).get("recipe", "")) == "premium":
			n += int(l["lot"]["portions"])
	if String(glass.get("recipe", "")) == "premium":
		n += int(glass.get("portions", 0))
	return n


## M16 the rotary popper: a small lot (its contract's portions) every cycle, near grade
## (a drum never hits perfect -- or burns), oiled if the doser runs.
func _rotary_lot(m: Dictionary) -> Dictionary:
	var portions := int((catalog("M16").get("contract", {}) as Dictionary).get("portions", 2))
	var lot := {"id": _new_id(), "recipe": "plain", "quality": _oil(int(GRADE_QUALITY[NEAR])), "portions": portions}
	_sort_and_grade(lot, NEAR)
	stats["made_portions"] = int(stats["made_portions"]) + portions
	stats["rotary_lots"] = int(stats.get("rotary_lots", 0)) + 1
	stats["auto_portions"] = int(stats["auto_portions"]) + portions
	_note("lots")
	_emit("auto_lot", {"lot": lot["id"], "grade": NEAR, "portions": portions, "machine": m["id"]})
	return lot


## The kitchen's heat: cooking kettles warm the room, the room (and the fan) cool it.
## Too hot with three or more kettles cooking and no vent stabilizer (M13): every kettle
## stops to cool for a few seconds (the lots in them wait; nothing is lost or made).
func _heat_step(dt: int) -> void:
	var h: Dictionary = _t().get("heat", {})
	if h.is_empty():
		return
	if overheat_left > 0:
		overheat_left = maxi(0, overheat_left - dt)
		kitchen_heat = maxf(0.0, kitchen_heat - float(h["dissipate"]) * dt / 1000.0)
		return
	var cooking := machines.filter(func(x: Dictionary) -> bool: return _is_kettle(x) and String(x["state"]) == "run").size()
	var cool := float(h["dissipate"]) + (float(h["fan"]) if _device_on("M08") else 0.0)
	kitchen_heat = clampf(kitchen_heat + (cooking * float(h["per_kettle"]) - cool) * dt / 1000.0, 0.0, float(h["limit"]))
	if kitchen_heat >= float(h["limit"]) and cooking >= int(h["min_kettles"]):
		if _device_on("M13"):
			kitchen_heat = float(h["limit"]) * 0.9   # the vents carry the excess away
			stats["vent_saves"] = int(stats.get("vent_saves", 0)) + 1
		else:
			overheat_left = int(h["stop_ms"])
			kitchen_heat = float(h["limit"]) * 0.5
			stats["overheat_stops"] = int(stats.get("overheat_stops", 0)) + 1
			_emit("overheat", {"ms": overheat_left, "kettles": cooking})


## M15's question: do the shelf and the orders need another lot? The popcorn they
## want (orders not covered by packs, the shelf's stock targets) against the popcorn
## already made and on its way (bin, lift, glass, lots held in kettles).
func demand_wants_lot() -> bool:
	var want := 0
	var covered := {}
	for c: Dictionary in queue:
		var o: Dictionary = c["order"]
		var key := "%s|%d" % [o["recipe"], o["size"]]
		var have := int(covered.get(key, on_hand(String(o["recipe"]), int(o["size"]))))
		if have > 0:
			covered[key] = have - 1
		else:
			want += int(o["size"])
	var cap := int(_t()["shelf_packs"])
	var reserved := 0
	var open := sizes_open()
	for z: Dictionary in open:
		reserved += int(z.get("stock", 0))
	for z: Dictionary in open:
		var size := int(z["size"])
		var target := int(z.get("stock", 0)) if z.has("stock") else cap - reserved
		var on := on_hand("plain", size) + on_hand("premium", size)
		want += maxi(0, target - on) * size
	var supply := bin_portions() + lift_portions() + int(glass.get("portions", 0))
	for m: Dictionary in machines:
		supply += int((m["held"] as Dictionary).get("portions", 0)) if _is_kettle(m) else 0
	return want > supply


# -- Step 28: the kitchen's devices (M01-M06, M08) ---------------------------------

func _devices(type: String) -> Array:
	return machines.filter(func(x: Dictionary) -> bool: return String(x["type"]) == type and String(x["state"]) not in ["paused", "unpaid"])


## Whether a working device of that type is on the floor (paused or unpaid ones do nothing).
func _device_on(type: String) -> bool:
	return not _devices(type).is_empty()


## A device that serves one kettle each (M04, M05): kettles in id order, one per device.
func _covered(kettle: Dictionary, type: String) -> bool:
	var n := _devices(type).size()
	var k := 0
	for c: Dictionary in machines:
		if String(c["type"]) == "cooker":
			if int(c["id"]) == int(kettle["id"]):
				return k < n
			k += 1
	return false


## A device's number at its best working tier (the highest tier among its kind).
func _tier_value(type: String, key: String, fallback: int) -> int:
	var best := -1
	for d: Dictionary in _devices(type):
		best = maxi(best, int(d["tier"]))
	if best < 0:
		return fallback
	var tiers: Array = catalog(type).get("tiers", [{}])
	return int((tiers[clampi(best, 0, tiers.size() - 1)] as Dictionary).get(key, fallback))


## The lift's time, shorter with M06 the batch ejector (the hand's lots and the kettles').
func lift_ms() -> int:
	var ms := int(_t()["lift_ms"])
	if _device_on("M06"):
		ms = maxi(100, ms - int(_tier_value("M06", "minus", 600)))
	return ms


## A kettle's cycle: its tier, then M05 (covered: 15% shorter) and M08 (0.3 s shorter).
func _cooker_cycle(m: Dictionary) -> int:
	if String(m["type"]) == "M16":   # the rotary popper: its own steady cycle (M08 does not cool a drum)
		return int(_machine_tier(m).get("cycle_ms", 2500))
	var ms := int(_machine_tier(m).get("cycle_ms", _auto()["cycle_ms"]))
	if _covered(m, "M05"):
		ms = int(ms * 0.85)
	if _device_on("M08"):
		ms -= 300
	return maxi(1000, ms)


func _kitchen_busy() -> bool:
	if heating or not lift.is_empty() or cooldown_left > 0:
		return true
	return machines.any(func(x: Dictionary) -> bool: return _is_kettle(x) and String(x["state"]) == "run")


## M01 the kernel hopper: buys kernels from the wallet (kernel_price a lot) and tops
## up its four kettles (the first hopper the first four kettles, the second the next
## four, ...), the emptiest first, a lot a second; it works (and pays) only while one
## of them needs it.
func _hopper_step(m: Dictionary, dt: int) -> void:
	var a := _auto()
	var buffer := int(_tier_value("M01", "buffer", int(a.get("kernel_buffer", 5)) * 8)) / 8
	buffer = maxi(int(a.get("kernel_buffer", 5)), buffer)
	var price := int(a.get("kernel_price", 1))
	var mine := 0
	for x: Dictionary in machines:
		if String(x["type"]) == "M01":
			if int(x["id"]) == int(m["id"]):
				break
			mine += 1
	var k := 0
	var hungry: Dictionary = {}
	for c: Dictionary in machines:
		if not _is_kettle(c):
			continue
		if k >= mine * 4 and k < mine * 4 + 4 and int(c.get("kernels", 0)) < buffer:
			if hungry.is_empty() or int(c.get("kernels", 0)) < int(hungry.get("kernels", 0)):
				hungry = c
		k += 1
	if hungry.is_empty():
		m["state"] = "idle"
		return
	if money < price:
		m["state"] = "unpaid"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"
	m["left_ms"] = int(m["left_ms"]) - dt
	if int(m["left_ms"]) <= 0:
		m["left_ms"] = 1000
		money -= price
		stats["kernels_paid"] = int(stats.get("kernels_paid", 0)) + price
		hungry["kernels"] = int(hungry.get("kernels", 0)) + 1
		m["done"] = int(m.get("done", 0)) + 1
		_emit("kernels_loaded", {"machine": m["id"], "kettle": hungry["id"]})


## The other kitchen devices work (and pay) while the kitchen works; their effects
## are applied where the goods are made (_auto_lot, _cooker_cycle, lift_ms, _cooldown_ms).
func _device_step(m: Dictionary, dt: int) -> void:
	var needs_kettle := String(m["type"]) in ["M02", "M03", "M04", "M05", "M09", "M11", "M13", "M14", "M15"]
	var busy := machines.any(func(x: Dictionary) -> bool: return _is_kettle(x) and String(x["state"]) in ["run", "waiting", "overheat"]) if needs_kettle else _kitchen_busy()
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## Step 30: the packing floor's devices work (and pay) while the floor packs.
func _packing_device_step(m: Dictionary, dt: int) -> void:
	var busy := not packing.is_empty() or machines.any(func(x: Dictionary) -> bool: return String(x["type"]) in ["bagger", "P01"] and String(x["state"]) == "run")
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## Refill a kettle's kernels by hand (the card, when it has no hopper): price a lot.
func _refill(id: int) -> Dictionary:
	var m := machine(id)
	if m.is_empty() or not _is_kettle(m):
		return {"ok": false, "reason": "err.unknown"}
	var a := _auto()
	var need := int(a.get("kernel_buffer", 5)) - int(m.get("kernels", 0))
	var cost := need * int(a.get("kernel_price", 1))
	if need <= 0:
		return {"ok": false, "reason": "err.full"}
	if money < cost:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= cost
	stats["kernels_paid"] = int(stats.get("kernels_paid", 0)) + cost
	m["kernels"] = int(a.get("kernel_buffer", 5))
	_emit("kernels_loaded", {"machine": -1, "kettle": id})
	return {"ok": true, "cost": cost}


func refill_cost(m: Dictionary) -> int:
	var a := _auto()
	return maxi(0, int(a.get("kernel_buffer", 5)) - int(m.get("kernels", 0))) * int(a.get("kernel_price", 1))


## A fresh run from another seed (a measured session, ?seed=N): the same model,
## its arrivals drawn from that seed. Only before anything has happened.
func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
	_orng.seed = seed_value + 7919
	order_rng_state = int(_orng.state)
	_arng.seed = seed_value + 104729
	auto_rng_state = int(_arng.state)
	_prng.seed = seed_value + 15485863
	pack_rng_state = int(_prng.state)
	queue.clear()
	arrival_log.clear()
	stats["arrived"] = 0
	stats["visitors"] = 0
	next_id = 1
	_rng.state = int(_rng.state)
	rng_state = int(_rng.state)
	_arrive()
	var f := _t()["customers"] as Dictionary
	_rng.state = rng_state
	next_arrival_ms = flow_ms + _rng.randi_range(int(f["second_ms"][0]), int(f["second_ms"][1]))
	rng_state = int(_rng.state)


func _free_lane() -> int:
	var used := {}
	for sv: Dictionary in serves:
		used[int(sv["lane"])] = true
	for k in lanes():
		if not used.has(k):
			return k
	return 0


func _sell(sv: Dictionary) -> void:
	var c: Dictionary = sv["customer"]
	var p: Dictionary = sv["pack"]
	if sv.has("kiosk"):
		var km := machine(int(sv["kiosk"]))
		if not km.is_empty():
			km["done"] = int(km.get("done", 0)) + 1
	var coins := pack_price(String(p["recipe"]), int(p["size"]), int(p["quality"]))
	if first_sale_ms < 0:
		first_sale_ms = flow_ms
	stats["sold_size_%d" % int(p["size"])] = int(stats.get("sold_size_%d" % int(p["size"]), 0)) + 1   # Step 30: cups, bags
	if String(p["recipe"]) == "premium":
		stats["premium_sold"] = int(stats.get("premium_sold", 0)) + 1
		stats["premium_revenue"] = int(stats.get("premium_revenue", 0)) + coins
	if String(p["recipe"]) != String(c["order"]["recipe"]):
		stats["wrong_sku"] = int(stats.get("wrong_sku", 0)) + 1   # must stay 0 (tests)
	ledger.append({"t": flow_ms, "customer": c["id"], "pack": p["id"], "recipe": p["recipe"], "size": p["size"], "ordered": c["order"]["size"], "ordered_recipe": c["order"]["recipe"], "quality": p["quality"], "coins": coins})
	if ledger.size() > 500:
		ledger.pop_front()
	stats["sold"] = int(stats["sold"]) + 1
	_note("sales")
	stats["sold_portions"] = int(stats["sold_portions"]) + pack_portions(p)
	stats["revenue"] = int(stats["revenue"]) + coins
	_emit("sale", {"customer": c["id"], "pack": p["id"], "coins": coins, "quality": p["quality"]})
	_earn(coins, {"from": "sale", "customer": c["id"], "pack": p["id"]})


func _arrive() -> void:
	var f := _t()["customers"] as Dictionary
	# Every visitor is logged (Step 22): those who join the queue ("arrived")
	# and those who find it full and walk past ("passed_by").
	arrival_log.append(flow_ms)
	if arrival_log.size() > 400:
		arrival_log.pop_front()
	stats["visitors"] = int(stats.get("visitors", 0)) + 1
	if queue.size() >= queue_cap():
		stats["passed_by"] = int(stats["passed_by"]) + 1
		_emit("customer_passed", {})
		return
	var c := {"id": _new_id(), "order": _draw_order(), "patience_ms": int(f["patience_ms"])}
	queue.append(c)
	stats["arrived"] = int(stats["arrived"]) + 1
	_emit("customer_arrived", {"customer": c["id"], "order": c["order"]})


## The next customer: a triangular wait between min and max around `mode`
## (expected ~15 s; never a fixed timer), from a seeded generator so a run is
## reproducible; at least min_gap after this one, never more than `drought`.
func _schedule_arrival() -> void:
	var f := _t()["customers"] as Dictionary
	var sg := shop_sign()
	_rng.state = rng_state
	var lo := float(sg["min_ms"])
	var hi := float(sg["max_ms"])
	var mo := float(sg["mode_ms"])
	var u := _rng.randf()
	var c := (mo - lo) / (hi - lo)
	var wait := lo + sqrt(u * (hi - lo) * (mo - lo)) if u < c else hi - sqrt((1.0 - u) * (hi - lo) * (hi - mo))
	rng_state = int(_rng.state)
	wait = clampf(wait, float(f["min_gap_ms"]), float(f["drought_ms"]))
	next_arrival_ms = flow_ms + FLOW_STEP_MS + int(wait)


# -- Step 22: the save ---------------------------------------------------------
## The whole factory: every good where it is, the customers, the clocks and the
## arrival generator's state (so a resumed run continues the same draws). A heat
## in progress is not kept (as the stand's, Step 12).

const SAVE_INTS := ["now_ms", "level", "money", "earned", "presses", "crescendo", "bursts", "packer_tier", "sign_tier",
	"next_arrival_ms", "flow_ms", "next_id", "first_sale_ms"]
const SAVE_GOODS := ["glass", "lift", "bin", "packing", "shelf", "queue", "serves", "ledger", "arrival_log"]
## Step 23 fields: optional (a 0.22 save has none).
const SAVE_OPTIONAL := ["order_rng_state", "recent", "glass_held_ms", "machines", "next_machine_id", "auto_rng_state", "bn_ring"]


func to_save() -> Dictionary:
	var d := {"rng_state": str(rng_state), "stats": stats.duplicate(true), "outcomes": outcomes.duplicate(),
		"order_rng_state": str(order_rng_state), "recent": recent.duplicate(true), "glass_held_ms": glass_held_ms,
		"machines": machines.duplicate(true), "next_machine_id": next_machine_id, "auto_rng_state": str(auto_rng_state), "bn_ring": bn_ring.duplicate(), "kitchen_heat": kitchen_heat, "overheat_left": overheat_left, "pack_rng_state": str(pack_rng_state), "paying": paying.duplicate(true)}
	for k: String in SAVE_INTS:
		d[k] = get(k)
	for k: String in SAVE_GOODS:
		var v: Variant = get(k)
		d[k] = v.duplicate(true)
	return d


## JSON gives every number back as a float: whole numbers become ints again.
static func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(v) == floor(float(v)) else v
		TYPE_ARRAY:
			return (v as Array).map(func(x: Variant) -> Variant: return _ints(x))
		TYPE_DICTIONARY:
			var o := {}
			for k: Variant in (v as Dictionary).keys():
				o[k] = _ints(v[k])
			return o
	return v


## Restores only a whole, consistent factory (every portion made is somewhere,
## tiers in range, nothing negative); otherwise changes nothing and answers false.
func from_save(raw: Dictionary) -> bool:
	var d: Dictionary = _ints(raw)
	for k: String in SAVE_INTS + SAVE_GOODS + ["stats", "outcomes", "rng_state"]:
		if not d.has(k):
			return false
	for k: String in SAVE_INTS:
		if typeof(d[k]) != TYPE_INT or (int(d[k]) < 0 and k != "first_sale_ms"):
			return false
	for k: String in SAVE_GOODS:
		if typeof(d[k]) != TYPE_ARRAY and not (k == "glass" and typeof(d[k]) == TYPE_DICTIONARY):
			return false
	if typeof(d["stats"]) != TYPE_DICTIONARY or typeof(d["outcomes"]) != TYPE_DICTIONARY or not String(d["rng_state"]).is_valid_int():
		return false
	if int(d["level"]) > max_level() or int(d["packer_tier"]) >= (_t()["packer"] as Array).size() or int(d["sign_tier"]) >= (_t()["sign"] as Array).size():
		return false
	# Try it on a copy first: the goods must add up to what was made.
	var probe: PopRules = get_script().new(economy)
	probe._apply_save(d)
	if int(probe.portions_everywhere()) != int((d["stats"] as Dictionary).get("made_portions", -1)):
		return false
	_apply_save(d)
	return true


func _apply_save(d: Dictionary) -> void:
	for k: String in SAVE_INTS:
		set(k, int(d[k]))
	for k: String in SAVE_GOODS:
		set(k, d[k])
	for k: String in (d["stats"] as Dictionary).keys():
		stats[k] = d["stats"][k]
	for k: String in outcomes.keys():
		outcomes[k] = int((d["outcomes"] as Dictionary).get(k, 0))
	crescendo = clampi(crescendo, 0, crescendo_full() - 1)
	rng_state = String(d["rng_state"]).to_int()
	_rng.state = rng_state
	if String(d.get("order_rng_state", "")).is_valid_int():
		order_rng_state = String(d["order_rng_state"]).to_int()
		_orng.state = order_rng_state
	glass_held_ms = maxi(0, int(d.get("glass_held_ms", 0))) if typeof(d.get("glass_held_ms", 0)) == TYPE_INT else 0
	machines = (d.get("machines", []) as Array).duplicate(true) if typeof(d.get("machines", [])) == TYPE_ARRAY else []
	# A 0.25 save kept its cookers apart: they become cooker machines in the kitchen's slots.
	if typeof(d.get("cookers")) == TYPE_ARRAY:
		var k := 0
		for c: Dictionary in d["cookers"]:
			machines.append({"id": machines.size() + 1, "type": "cooker", "floor": "kitchen", "slot": k, "tier": 0, "state": String(c.get("state", "idle")),
				"left_ms": int(c.get("left_ms", 6000)), "held": c.get("held", {}), "upkeep_ms": int(c.get("upkeep_ms", 0)), "paid": 300, "assist": 0})
			k += 1
	# Step 29: the kitchen's heat (optional: a 0.28 save has none -- a cool kitchen).
	kitchen_heat = clampf(float(d.get("kitchen_heat", 0.0)), 0.0, 1000.0) if typeof(d.get("kitchen_heat", 0.0)) in [TYPE_INT, TYPE_FLOAT] else 0.0
	overheat_left = maxi(0, int(d.get("overheat_left", 0))) if typeof(d.get("overheat_left", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	paying = (d.get("paying", []) as Array).duplicate(true) if typeof(d.get("paying", [])) == TYPE_ARRAY else []
	if String(d.get("pack_rng_state", "")).is_valid_int():
		pack_rng_state = String(d["pack_rng_state"]).to_int()
	# Step 28: a kettle saved before kernels existed (0.25-0.27) comes back with a full
	# buffer -- the save keeps cooking; it is not starved by an update.
	for m: Dictionary in machines:
		if String(m.get("type", "")) == "cooker" and not m.has("kernels"):
			m["kernels"] = int(_auto().get("kernel_buffer", 5))
	next_machine_id = maxi(int(d.get("next_machine_id", 1)), machines.size() + 1)
	bn_ring = (d.get("bn_ring", []) as Array).duplicate() if typeof(d.get("bn_ring", [])) == TYPE_ARRAY else []
	if String(d.get("auto_rng_state", "")).is_valid_int():
		auto_rng_state = String(d["auto_rng_state"]).to_int()
		_arng.state = auto_rng_state
	if typeof(d.get("recent")) == TYPE_DICTIONARY:
		for k: String in recent.keys():
			recent[k] = (d["recent"] as Dictionary).get(k, []) if typeof((d["recent"] as Dictionary).get(k)) == TYPE_ARRAY else []


# -- reading it ---------------------------------------------------------------

func state() -> Dictionary:
	var s := super()
	s["glass"] = glass.duplicate()
	s["flow_ms"] = flow_ms
	s["lift"] = lift.size()
	s["bin_portions"] = bin_portions()
	s["bin_cap"] = int(_t()["bin_portions"])
	s["packing"] = packing.duplicate(true)
	s["packer_tier"] = packer_tier
	s["packer_max"] = (_t()["packer"] as Array).size() - 1
	s["packer_cost"] = packer_cost()
	s["packer_state"] = packer_state()
	s["packs_per_min"] = packs_per_min(packer_tier)
	s["shelf"] = shelf.size()
	s["shelf_cap"] = shelf_cap()   # Step 30: plus the premium lane while a diverter runs
	s["queue"] = queue.size()
	s["queue_cap"] = queue_cap()
	s["sign_tier"] = sign_tier
	s["cookers"] = cookers.map(func(c: Dictionary) -> String: return String(c["state"]))
	s["machines"] = machines.map(func(m: Dictionary) -> Dictionary: return {"id": m["id"], "type": m["type"], "floor": m["floor"], "slot": m["slot"],
		"tier": m["tier"], "state": m["state"], "assist": m["assist"], "done": int(m.get("done", 0)), "held": int((m["held"] as Dictionary).get("portions", (m["held"] as Dictionary).get("size", 0))), "kernels": int(m.get("kernels", 0))})
	s["build_cost"] = {"cooker": build_cost("cooker"), "bagger": build_cost("bagger"), "kiosk": build_cost("kiosk")}
	s["auto_cost"] = auto_cost()
	s["open"] = {"packer": station_open("packer"), "sign": station_open("sign"), "cooker": station_open("cooker"),
		"bagger": station_open("bagger"), "kiosk": station_open("kiosk")}
	s["sign_max"] = (_t()["sign"] as Array).size() - 1
	s["sign_cost"] = sign_cost()
	s["mean_wait_ms"] = mean_wait_ms(sign_tier)
	s["arrivals"] = arrival_log.slice(-60)
	s["first_sale_ms"] = first_sale_ms
	s["serving"] = not serves.is_empty()
	s["serves"] = serves.map(func(x: Dictionary) -> Dictionary: return {"customer": x["customer"]["id"], "pack": x["pack"]["id"], "lane": x["lane"], "left_ms": x["left_ms"]})
	s["lanes"] = lanes()
	s["ledger"] = ledger.slice(-20)
	s["sales_logged"] = ledger.size()
	s["stats"] = stats.duplicate()
	s["kettle_capacity"] = kettle_capacity()
	s["next_arrival_ms"] = next_arrival_ms
	s["bottleneck"] = bottleneck()
	s["per_min"] = {"lots": per_min("lots"), "packs": per_min("packs"), "sales": per_min("sales")}
	s["sizes_open"] = sizes_open().map(func(z: Dictionary) -> int: return int(z["size"]))
	s["orders"] = queue.map(func(c: Dictionary) -> int: return int(c["order"]["size"]))
	s["portions_everywhere"] = portions_everywhere()
	# Step 29: the kitchen's heat, its places, premium stock.
	s["kitchen_heat"] = kitchen_heat
	s["heat_limit"] = float((_t().get("heat", {}) as Dictionary).get("limit", 100))
	s["overheat_left"] = overheat_left
	s["kitchen_slots"] = slots("kitchen")
	s["premium_on_shelf"] = shelf.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) == "premium").size()
	s["premium_in_bin"] = bin_portions_of("premium")
	s["paying"] = paying.size()   # Step 31: customers at the auto cashier
	s["counter_lanes"] = lanes()
	return s


## Which stage holds the line back right now (no spreadsheet: the view turns
## it into a picture, Step 23): 'kitchen' (the packer is starved), 'packing'
## (customers wait for packs), 'shop' (packs wait for customers), or '' (flowing).
## Step 24: only a real wait names a bottleneck (a customer served a second
## after their pack is sealed is the flow working, not a shortage).
const REAL_WAIT_MS := 6000
const REAL_HOLD_MS := 3000


## Step 25: the bottleneck the player is shown is the one that held for most of
## the last 30 s (sampled each second) -- an instant's queue from a lucky burst
## of customers is not a reason to buy a station (the simulator bought on such
## instants and never earned the price back).
const BN_SAMPLES := 30
var bn_ring: Array = []


func bottleneck() -> String:
	if bn_ring.is_empty():
		return instant_bottleneck()
	# When more than half of the last 30 s had a bottleneck, show the most frequent
	# one (Step 26: two stages that both nearly bind split the samples, and a strict
	# majority of one showed nothing while customers were being lost).
	var count := {}
	var any := 0
	for b: String in bn_ring:
		if b != "":
			count[b] = int(count.get(b, 0)) + 1
			any += 1
	if any * 2 <= bn_ring.size():
		return ""
	var best := ""
	for b: String in count.keys():
		if best == "" or int(count[b]) > int(count[best]):
			best = b
	return best


func instant_bottleneck() -> String:
	# Which stage holds the next one back, in the player's terms --
	# "production" (someone has waited 6 s and the station has no popcorn for them),
	# "packaging" (someone has waited 6 s while the station works, or the kettle
	# has waited 3 s for room), "demand" (packs wait, nobody in the queue), "".
	var patience := int((_t()["customers"] as Dictionary)["patience_ms"])
	# The head of the queue has waited 6 s: why? Their pack is on the shelf but every
	# lane and kiosk is busy -> "service" (Step 26); no pack and nothing to make it
	# from -> "production"; no pack but the station is on it -> "packaging".
	if not queue.is_empty():
		var head: Dictionary = queue[0]
		if patience - int(head["patience_ms"]) >= REAL_WAIT_MS:
			if _matching_pack(head["order"]) >= 0:
				var kiosk_free := machines.any(func(m: Dictionary) -> bool: return String(m["type"]) == "kiosk" and not _kiosk_busy(int(m["id"])) and String(m["state"]) not in ["paused", "unpaid"])
				if _counter_serving() >= lanes() and not kiosk_free:
					return "service"
			elif packing.is_empty() and _next_pack().is_empty():
				return "production"
			else:
				return "packaging"
	if glass_held_ms >= REAL_HOLD_MS:
		# The kettle waits for room: the station is the cause only if it is still
		# working; a station blocked by a full shelf means packs wait for people.
		return "demand" if packer_state() == "blocked" else "packaging"
	if queue.is_empty() and shelf.size() >= int(_t()["shelf_packs"]) / 2:
		return "demand"
	return ""
