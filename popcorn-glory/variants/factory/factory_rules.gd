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
var finishing := {}        ## Step 35: the hand's spoon on a coater's batch ({machine, ms}; {} when not)
var promo := {}            ## Step 35: flavor -> flow ms its surplus began (a key with "on": the board's special)
var popularity := 50.0     ## Step 36: the shop's reputation (0-100; stars on the board, foot traffic)
var cast_rng_state := 0    ## Step 36: who comes in (its own generator: orders and arrivals keep theirs)
var _crng := RandomNumberGenerator.new()
var demand_mods := {}      ## Step 36: the modifiers in force ({"arrivals": x, "flavors": {f: x}, "large": x, "ingredients": {f: x}}) -- Step 37: base_mods x the news's events
var base_mods := {}        ## Step 37: modifiers set from outside (set_demand_mods: tests, tools); the news multiplies on top
var news := {}             ## Step 37: {"next_ms", "seq", "active": [{n, id, start, end, asked, sold, saved}], "log": [...], "unread": [n...]}
var news_focus := ""       ## Step 37: the flavor put first while its event runs (the card's button, or U07)
var news_rng_state := 0    ## Step 37: the news's own generator (orders, arrivals and the cast keep theirs)
var _nrng := RandomNumberGenerator.new()
var order_log: Array = []  ## Step 36: the last orders' recipes (the board's favorite)
## Step 33: each floor's lines (1 = the first; data: factory.lines adds places per line).
## Two or more packing lines make the raw bin parallel lines: every lot that lands is
## routed to one line, and a line's fillers pack only its own goods (the station is line 1).
var floor_lines := {"kitchen": 1, "packing": 1, "shop": 1}
## The cookers among them (Step 25's name; the same dictionaries).
var cookers: Array:
	get:
		return machines.filter(func(m: Dictionary) -> bool: return String(m["type"]) == "cooker")
var auto_rng_state := 0
var _arng := RandomNumberGenerator.new()
var order_rng_state := 0    ## Step 23: the orders' own generator (so orders never move arrival times)
## Step 23: what each stage finished in the last minute (flow ms), for the bottleneck cues.
var recent := {"lots": [], "packs": [], "sales": [], "ingredients": []}   ## Step 34: a coin of ingredients a time
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
	_crng.seed = seed_value + 32452843
	cast_rng_state = int(_crng.state)
	_nrng.seed = seed_value + 49979687
	news_rng_state = int(_nrng.state)
	news = _news_fresh()
	popularity = float(_t().get("reputation", {}).get("start", 50.0))
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
	if shelf.size() >= shelf_base():
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
		"P05", "P06":   # Step 34: a coater opens with its packing tier and one of its flavors
			var pp: Dictionary = catalog(station).get("prereq", {})
			return (sign_tier >= int(pp.get("sign", 0)) and packer_tier >= int(pp.get("packer", 0)) and not _open_flavors_of(station).is_empty()) or _count(station) > 0
		"M01", "M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "P01", "P02", "P04", "P05", "P06", "P07", "P08", "S01", "S02", "S03", "S04", "S05", "S06", "S08", "U01", "U02", "U03", "U04", "U05", "U06", "U07", "U08":
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
	var unit := _unit_price(recipe)
	var base := unit * size / pack_size()
	for z: Dictionary in _t().get("sizes", []):
		if int(z["size"]) == size:   # Step 23: the bag's own price (the large one is cheaper per portion)
			base = int(z["price"]) * unit / 10
	# Step 34: a coated flavor's price leans on quality by its own weight (caramel forgives,
	# cocoa does not); plain, premium and bargain keep the 0.6 + 0.4 x quality of Step 17.
	if is_flavor(recipe) or is_mix(recipe):
		var w := float((mix(recipe) if is_mix(recipe) else flavor(recipe)).get("quality_weight", 0.4))
		return maxi(1, int(round(base * (1.0 - w + w * float(quality) / 100.0))))
	return maxi(1, int(round(base * (0.6 + 0.4 * float(quality) / 100.0))))


## A small bag's price at quality 100: the price table, or a flavor's own (Step 34).
func _unit_price(recipe: String) -> int:
	var table: Dictionary = _t()["price"]
	if table.has(recipe):
		return int(table[recipe])
	if is_mix(recipe):
		return int(mix(recipe).get("price", 0))
	return int(flavor(recipe).get("price", 0))


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
	# Step 35: portions a coater's drum lost are counted, never vanished.
	return n + int(stats["sold_portions"]) + int(stats.get("lost_portions", 0))


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
			return _build(String(cmd.get("machine", "")), int(cmd.get("slot", -1)), String(cmd.get("floor", "")))
		"buy_line":   # Step 33: a floor's next line of places
			return _buy_line(String(cmd.get("floor", "")))
		"pause_all":   # Step 32: every machine at once (the upkeep overview)
			return _pause_all(bool(cmd.get("paused", true)))
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
		"set_flavor":   # Step 34: what a coater coats from now on
			return _set_flavor(int(cmd.get("id", -1)), String(cmd.get("flavor", "")))
		"finish_press":   # Step 35: the hand's spoon on a coater's batch
			return _finish_press(int(cmd.get("id", -1)))
		"finish_release":
			return _finish_release()
		"news_read":   # Step 37: the paper opened -- what is running is read
			return _news_read()
		"news_focus":   # Step 37: put an event's flavor first (again: let go)
			return _news_set_focus(String(cmd.get("flavor", "")))
	if kind == "press" and not finishing.is_empty():
		return {"ok": false, "reason": "err.hand_busy"}   # one hand: the spoon or the kettle
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
	if not finishing.is_empty():   # Step 35: the spoon's hold, by the millisecond (a drip lets go)
		var drip: int = int(finish_window(String(finishing["flavor"]))[1]) + int(hand_rules().get("drip_ms", 1200))
		finishing["ms"] = mini(int(finishing["ms"]) + ms, drip)
		if int(finishing["ms"]) >= drip:
			_finish_release()
	# The flow in fixed steps of total time: from where it is to start + ms.
	var target := start + ms
	while flow_ms + FLOW_STEP_MS <= target:
		now_ms = flow_ms + FLOW_STEP_MS
		_flow_step(FLOW_STEP_MS)
		flow_ms += FLOW_STEP_MS
	now_ms = start


func _flow_step(dt: int) -> void:
	var t := _t()
	_news_step()   # Step 37: events start and end at their exact flow time
	# 1. The glass pours into the lift what the bin will have room for: the whole
	# lot, or (Step 24 fix) a part of it when the lot is bigger than the room --
	# a lot bigger than the whole bin (kettle level 7+, or a burst at 6) used to
	# wait for room that could never come, and stopped the factory for good.
	if not glass.is_empty():
		var room := bin_cap() - bin_portions() - lift_portions() - coating_portions()
		var want := int(glass["portions"])
		var full_bin := bin_cap()
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
	if (flow_ms + dt) % 1000 == 0 and (not promo.is_empty() or not offered_flavors().is_empty()):
		_promo_step()   # Step 35: the board's special
	if (flow_ms + dt) % 1000 == 0:
		bn_ring.append(instant_bottleneck())
		if bn_ring.size() > BN_SAMPLES:
			bn_ring.pop_front()
	# 1b. The machines (Steps 25-26), then the lines (Step 33).
	_machines_step(dt)
	_lines_step(dt)
	# 2. The lift lands lots in the bin.
	var still: Array = []
	for x: Dictionary in lift:
		x["left_ms"] = int(x["left_ms"]) - dt
		if int(x["left_ms"]) <= 0:
			_route(x["lot"])   # Step 33: to a packing line (with two or more)
			bin.append(x["lot"])
			_emit("lot_binned", {"lot": x["lot"]["id"], "line": lot_line(x["lot"])})
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
			var want := _next_pack(station_sizes(), 0)
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
				var pack := _sealed(p)
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
			if _news_spares(c["order"]):   # Step 37: they came for the news -- no blame on the shop
				stats["news_spared"] = int(stats.get("news_spared", 0)) + 1
			else:
				_reputation(float((_t().get("reputation", {}) as Dictionary).get("left", -3.0)), "left")
			_emit("customer_left", {"customer": c["id"], "why": "waited", "who": String(c.get("who", "classic"))})
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
	# The express window first: a small order goes to its faster lane when it is free.
	_self_serve(["S05"])
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
	# Step 26: self-serve kiosks take the next customer when the counter's lanes are busy.
	_self_serve(["kiosk"])


## Machines with their own lane take customers from the queue: kiosks (anyone, when
## the counter is full) and the express window (Step 31: small orders, first).
func _self_serve(kinds: Array) -> void:
	for m: Dictionary in machines:
		if queue.is_empty():
			break
		var kind := String(m["type"])
		if not kind in kinds or String(m["state"]) in ["paused", "unpaid"] or _kiosk_busy(int(m["id"])):
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
		var ms := int(round(float(_machine_tier(m).get("service_ms", 2500)) * lube_factor(m)))
		var lane := (100 if kind == "kiosk" else 200) + int(m["slot"])
		serves.append({"customer": head, "pack": pack, "left_ms": ms, "lane": lane, "kiosk": int(m["id"])})
		m["state"] = "run"
		_emit("serve_started", {"customer": head["id"], "pack": pack["id"], "lane": lane, "kiosk": int(m["id"])})


## Step 31: which customer a free lane takes. Without the router only the head of the
## queue (nobody jumps it); with the router (S04, two or more counter lanes) the first
## one whose pack is on the shelf. `max_size` > 0: the express window's small orders
## (the first eligible one in queue order -- it has its own line).
## Step 35: a customer whose flavor (or mix) is still being made waits aside -- the counter
## serves the people behind them meanwhile (their place is kept: they are served the moment
## their bag is on the shelf). A plain order still holds the queue (a plain shop is unchanged).
func _next_customer(max_size: int) -> int:
	var look_past := max_size > 0 or (_device_on("S04") and lanes() >= 2)
	var aside := false
	for i in queue.size():
		var o: Dictionary = queue[i]["order"]
		if max_size > 0 and int(o["size"]) > max_size:
			continue
		if _matching_pack(o) >= 0:
			if aside and not look_past:
				stats["served_past_aside"] = int(stats.get("served_past_aside", 0)) + 1
			return i
		if not order_flavors(o).is_empty():
			aside = true
			continue
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


## Step 32, U02 the lubricator: a working machine in the place beside it on the same
## floor runs its cycle 10/15/20% faster.
func lube_factor(m: Dictionary) -> float:
	var best := 0.0
	for d: Dictionary in _devices("U02"):
		if String(d["floor"]) == String(m.get("floor", "")) and absi(int(d["slot"]) - int(m.get("slot", -9))) == 1:
			best = maxf(best, float(_machine_tier(d).get("minus", 0.1)))
	return 1.0 - best


## Step 32, U03: the energy saver's cut on a floor (its best tier).
func _energy_cut(floor: String) -> float:
	var best := 0.0
	for d: Dictionary in _devices("U03"):
		if String(d["floor"]) == floor:
			best = maxf(best, float(_machine_tier(d).get("cut", 0.25)))
	return best


## Step 32: pause or resume every machine (the overview's one button).
func _pause_all(paused: bool) -> Dictionary:
	var n := 0
	for m: Dictionary in machines:
		if paused and String(m["state"]) != "paused":
			m["state"] = "paused"
			n += 1
		elif not paused and String(m["state"]) == "paused":
			m["state"] = "idle"
			n += 1
	_emit("machine_paused", {"machine": -1, "paused": paused, "count": n})
	return {"ok": true, "machines": n}


## Step 32: the support machines work (and pay) while what they serve works -- the
## robot while anything runs, the lubricator while a neighbour runs, the saver while its
## floor runs, the buffer lift while it holds extra goods, the inspector while lots come.
func _utility_step(m: Dictionary, dt: int) -> void:
	var busy := false
	match String(m["type"]):
		"U01":
			busy = machines.any(func(x: Dictionary) -> bool: return String(x["state"]) in ["run", "saving"] and x != m)
		"U02":
			busy = machines.any(func(x: Dictionary) -> bool: return String(x["floor"]) == String(m["floor"]) and absi(int(x["slot"]) - int(m["slot"])) == 1 and String(x["state"]) == "run")
		"U03":
			busy = machines.any(func(x: Dictionary) -> bool: return String(x["floor"]) == String(m["floor"]) and String(x["state"]) == "run" and x != m)
		"U04":
			busy = bin_portions() > int(_t()["bin_portions"]) or shelf.size() > int(_t()["shelf_packs"])
		"U05":
			busy = _kitchen_busy() or not glass.is_empty()
		"U07":   # Step 37: the demand scheduler works (and pays) while an event runs; it focuses it
			busy = not (news.get("active", []) as Array).is_empty()
			if busy and String(m["state"]) == "run" and not _news_flavors().is_empty() and not _news_flavors().has(news_focus):
				news_focus = String(_news_flavors()[0])
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## Step 32: the upkeep overview -- what the running machines burn a minute now (after
## the recycler and the saver), what is paused, the money the shop took in the last
## minute, the net, and whether the wallet covers two minutes of the burn.
func upkeep_overview() -> Dictionary:
	var burn := 0.0
	var paused_burn := 0.0
	var per_machine: Array = []
	for m: Dictionary in machines:
		var pm := float(catalog(String(m["type"]))["upkeep_per_min"]) * (1.0 - _energy_cut(String(m["floor"])))
		if _is_kettle(m) and _device_on("M14"):
			pm = maxf(1.0, pm - _tier_value("M14", "minus", 1))
		if String(m["state"]) == "paused":
			paused_burn += pm
		elif String(m["state"]) in ["run", "unpaid", "saving"]:
			burn += pm
		per_machine.append({"id": m["id"], "type": m["type"], "floor": m["floor"], "state": m["state"], "per_min": snappedf(pm, 0.01), "paid": int(m.get("upkeep_paid", 0)), "cost": int(m.get("paid", 0)), "done": int(m.get("done", 0)), "ingredients": int(m.get("ingredients_paid", 0))})
	var took := 0
	for e: Dictionary in ledger:
		if int(e["t"]) > flow_ms - 60000:
			took += int(e["coins"])
	# Step 34: the coaters' ingredients bought in the last minute are spent money too.
	var ingr := 0
	for t: int in recent.get("ingredients", []):
		if t > flow_ms - 60000:
			ingr += 1
	return {"burn_per_min": snappedf(burn, 0.1), "paused_per_min": snappedf(paused_burn, 0.1), "revenue_last_min": took, "ingredients_last_min": ingr,
		"net_per_min": snappedf(float(took) - burn - float(ingr), 0.1), "low_wallet": float(money) < burn * 2.0 and burn > 0.0,
		"paused": machines.filter(func(m: Dictionary) -> bool: return String(m["state"]) == "paused").size(), "machines": per_machine}


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


## Step 32, U04 the buffer lift: real extra room in the raw bin and on the shelf.
func bin_cap() -> int:
	var plus := 0
	for d: Dictionary in _devices("U04"):
		plus = maxi(plus, int(_machine_tier(d).get("bin", 12)))
	return int(_t()["bin_portions"]) + plus


func shelf_base() -> int:
	var plus := 0
	for d: Dictionary in _devices("U04"):
		plus = maxi(plus, int(_machine_tier(d).get("shelf", 4)))
	return int(_t()["shelf_packs"]) + plus


func shelf_cap() -> int:
	return shelf_base() + premium_lane()


## Places left on the shelf for a pack of this SKU (sealed packs and packs being
## sealed by the station count; a filler's own pack is checked again when it is sealed).
func shelf_room(sku: String) -> int:
	var lane := premium_lane()
	var on: Array = shelf + packing
	if lane > 0 and sku == "premium":
		return lane - on.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) == "premium").size()
	var plain_on := on.size() if lane == 0 else on.filter(func(p: Dictionary) -> bool: return String(p["recipe"]) != "premium").size()
	return shelf_base() - plain_on


## Packs on the shelf or being filled, by "sku|size" (what on_hand answers, all at once).
func _on_hand_counts() -> Dictionary:
	var out := {}
	for m: Dictionary in of_type("bagger"):
		var h: Dictionary = m["held"]
		if not h.is_empty():
			var k := "%s|%d" % [h["recipe"], h["size"]]
			out[k] = int(out.get(k, 0)) + 1
	for arr: Array in [shelf, packing]:
		for p: Dictionary in arr:
			var k := "%s|%d" % [p["recipe"], p["size"]]
			out[k] = int(out.get(k, 0)) + 1
	return out


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


func _recipe_for(sku: String, size: int, line: int = -1) -> String:
	for lot: Dictionary in bin:
		if not _on_line(lot, line):
			continue
		var r := String(lot["recipe"])
		if pack_sku(r) == sku and bin_portions_of(r, line) >= size:
			return r
	return ""


## The next pack to fill ({recipe, size, for}) or {} -- nothing wanted, or not
## enough popcorn of the wanted kind (then the station waits: it never packs the
## popcorn an order needs into another bag).
func _next_pack(allowed: Array = [], line: int = -1) -> Dictionary:
	var covered := {}
	var held := 0   # Step 34: shelf places kept for flavor orders being coated
	var counts := _on_hand_counts()   # Step 33: counted once (forty machines asked per order)
	# The line's recipes in the bin, oldest first, and their portions (one pass, not one a lot).
	var order: Array = []
	var portions := {}
	for lot: Dictionary in bin:
		if not _on_line(lot, line):
			continue
		var rr := String(lot["recipe"])
		if not portions.has(rr):
			order.append(rr)
			portions[rr] = 0
		portions[rr] = int(portions[rr]) + int(lot["portions"])
	for c: Dictionary in queue:
		var o: Dictionary = c["order"]
		if not allowed.is_empty() and not allowed.has(int(o["size"])):
			continue   # Step 30: cups are the cup feeder's; the station and the fillers pack bags
		var key := "%s|%d" % [o["recipe"], o["size"]]
		var have := int(covered.get(key, int(counts.get(key, 0))))
		if have > 0:
			covered[key] = have - 1
			continue
		var r := ""
		if is_mix(String(o["recipe"])):   # Step 35: half of each part, or its parts are still being coated
			var parts: Array = order_flavors(o)
			var half := int(o["size"]) / 2
			var ok := int(portions.get(String(parts[0]), 0)) >= int(o["size"]) - half * (parts.size() - 1)
			for k in range(1, parts.size()):
				ok = ok and int(portions.get(String(parts[k]), 0)) >= half
			if not ok:
				held += 1   # its place is kept (as a flavor order's)
				continue
			r = String(o["recipe"])
		for rr: String in order:
			if r != "":
				break
			if pack_sku(rr) == String(o["recipe"]) and int(portions[rr]) >= int(o["size"]):
				r = rr
				break
		# Step 34: a flavor order whose popcorn is still plain is the coater's to make -- the
		# floor packs on meanwhile (waiting for it here held every other order and the coater's
		# own plain popcorn in a full bin: found by the shared-shelf test).
		if r == "" and is_flavor(String(o["recipe"])) and int(portions.get(String(o["recipe"]), 0)) == 0:
			held += 1   # ... and its pack keeps a place: packs for the queue behind it never fill the shelf it needs
			continue
		if r != "" and held > 0 and shelf_room(pack_sku(r)) - held <= 0:
			return {}
		return {} if r == "" else {"recipe": r, "size": int(o["size"]), "for": "order"}
	var cap := shelf_base()
	var reserved := _flavor_stock_reserved()   # Step 34: the offered flavors' small stock
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
		for r: String in order:
			if int(portions[r]) < size:
				continue
			var sku := pack_sku(r)
			var t := mini(target, 1) if sku in ["premium", "bargain"] else target
			if is_flavor(sku):   # Step 34: its own stock of small bags; larger ones only for orders
				t = int(flavor(sku).get("stock", 0)) if size == pack_size() else 0
			if int(counts.get("%s|%d" % [sku, size], 0)) < t:
				if held > 0 and shelf_room(sku) - held <= 0:
					return {}
				return {"recipe": r, "size": size, "for": "stock"}
	return {}


## Customers' orders: the small bag, or once the large one is open, the large
## one by its share -- drawn from the orders' own generator.
func _draw_order(who: String = "") -> Dictionary:
	var size := pack_size()
	_orng.state = order_rng_state
	var p := person(who)
	for z: Dictionary in sizes_open():
		var share := float(z.get("order_share", 0.0))
		if z.has("order_share") and int(z["size"]) > pack_size():
			share = minf(0.95, share * float(p.get("large", 1.0)) * float(demand_mods.get("large", 1.0)))   # Step 36: who buys big (Step 37: big bag day)
		if z.has("order_share") and _orng.randf() < share:
			size = int(z["size"])
	# Step 29: while premium popcorn is on hand (M11 sorts it), some customers ask for it --
	# and only they buy it (the draw happens only then, so plain-only order streams are unchanged).
	var recipe := "plain"
	var pr: Dictionary = _t().get("premium", {})
	if _device_on("M11") and (bin_portions_of("premium") >= size or on_hand("premium", size) > 0):
		if _orng.randf() < minf(0.95, float(pr.get("order_share", 0.3)) * like(who, "premium")):
			recipe = "premium"
	var bgo: Dictionary = _t().get("bargain", {})
	if recipe == "plain" and _device_on("U05") and (bin_portions_of("bargain") >= size or on_hand("bargain", size) > 0):
		if _orng.randf() < float(bgo.get("order_share", 0.25)):
			recipe = "bargain"
	# Step 34: while flavors are offered, their customers ask for them by their shares (one
	# draw, only then -- a plain-only order stream is the same as before flavors).
	if recipe == "plain":
		var offered := offered_flavors()
		if not offered.is_empty():
			var u := _orng.randf()
			var acc := 0.0
			for f: String in offered:
				# Step 35: the board's special (a surplus) is asked for share_mult times as often.
				acc += float(flavor(f).get("order_share", 0.0)) * (float(promo_rules().get("share_mult", 1.0)) if promoted(f) else 1.0) * taste(who, f)
				if u < acc:
					recipe = f
					break
			if recipe == "plain":   # Step 35: a mixed bag (the same draw; none offered, the same stream)
				for x: String in offered_mixes():
					acc += float(mix(x).get("order_share", 0.0)) * taste(who, x)
					if u < acc:
						recipe = x
						size = int(mix(x).get("size", 4))
						break
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


func bin_portions_of(recipe: String, line: int = -1) -> int:
	var n := 0
	for lot: Dictionary in bin:
		if String(lot["recipe"]) == recipe and _on_line(lot, line):
			n += int(lot["portions"])
	return n


## The SKU a recipe's popcorn is packed as (data: factory.pack_recipes; the
## seasoning step of a later Step changes it, never the portions).
func pack_sku(recipe: String) -> String:
	return String((_t().get("pack_recipes", {}) as Dictionary).get(recipe, recipe))


# -- Step 34: flavors --------------------------------------------------------------
## Classic Butter is the base popcorn (`plain`, popped with butter in the kettle); the
## other flavors are coated on the packing floor by P05 (seasoning) and P06 (coating)
## from plain portions of their line -- the same portions, never more or fewer.

const COATERS := ["P05", "P06"]


func flavors() -> Dictionary:
	return _t().get("flavors", {})


func flavor(id: String) -> Dictionary:
	return ((flavors().get("recipes", {}) as Dictionary).get(id, {}) as Dictionary)


func flavor_ids() -> Array:
	return flavors().get("order", [])


## A coated flavor (not the base butter, not premium or bargain).
func is_flavor(recipe: String) -> bool:
	return recipe != String(flavors().get("base", "plain")) and not flavor(recipe).is_empty()


## A flavor opens by the packing and sign tiers its recipe names (one new choice at a time).
func flavor_open(id: String) -> bool:
	var r := flavor(id)
	if r.is_empty():
		return false
	var u: Dictionary = r.get("unlock", {})
	return packer_tier >= int(u.get("packer", 0)) and sign_tier >= int(u.get("sign", 0))


## What is wrong with a recipe (empty: it can be coated). A recipe that would make or lose
## portions, has no price, or names a machine that cannot coat it is refused.
func recipe_problems(id: String) -> Array:
	var r := flavor(id)
	var out: Array = []
	if r.is_empty():
		return ["unknown"]
	if not is_flavor(id):
		return ["base"]
	if int(r.get("in", 0)) <= 0 or int(r.get("out", 0)) != int(r.get("in", 0)):
		out.append("portions")   # coating adds taste, not portions
	if int(r.get("price", 0)) <= 0:
		out.append("price")
	if not COATERS.has(String(r.get("machine", ""))):
		out.append("machine")
	if int(r.get("coat_ms_per_portion", 0)) <= 0 or int(r.get("ingredient_coins", -1)) < 0:
		out.append("time")
	return out


## The flavors a coater type can make (data: the recipes' machine), in the menu's order.
func coater_flavors(type: String) -> Array:
	return flavor_ids().filter(func(f: String) -> bool: return String(flavor(f).get("machine", "")) == type)


func _open_flavors_of(type: String) -> Array:
	return coater_flavors(type).filter(func(f: String) -> bool: return flavor_open(f) and recipe_problems(f).is_empty())


## A coater's setting: one of its flavors, or AUTO (Step 35: the queue's order picks).
const AUTO := "auto"


func coater_flavor(m: Dictionary) -> String:
	var f := String(m.get("flavor", ""))
	if f == AUTO:   # the batch in the drum, else what it would pick now, else its first open flavor
		var h: Dictionary = m["held"]
		if not h.is_empty():
			return String(h["recipe"])
		var pick := _auto_pick(m)
		if pick != "":
			return pick
		var open := _open_flavors_of(String(m["type"]))
		return String(open[0]) if not open.is_empty() else ""
	return f


## Whether a coater makes this flavor (set to it, or AUTO with it open).
func coater_serves(m: Dictionary, f: String) -> bool:
	var mode := String(m.get("flavor", ""))
	if mode == AUTO:
		return _open_flavors_of(String(m["type"])).has(f)
	return mode == f and flavor_open(f)


## AUTO's pick (Step 35, recipe queue assignment): the flavor of the earliest waiting order
## it can make that is still short; else the first short one of the menu (its stock); "".
func _auto_pick(m: Dictionary) -> String:
	var open := _open_flavors_of(String(m["type"]))
	for c: Dictionary in queue:
		for f: String in order_flavors(c["order"]):
			if open.has(f) and _flavor_wanted(f):
				return f
	# Step 37: then a focused event flavor, a batch ahead of its crowd (after the customers
	# already waiting -- putting it before them cost the sim's shop more than it brought).
	if news_focus != "" and open.has(news_focus) and _flavor_wanted(news_focus):
		return news_focus
	for f: String in open:
		if _flavor_wanted(f):
			return f
	return ""


## The coated flavors an order needs: its flavor, a mix's parts, or none.
func order_flavors(o: Dictionary) -> Array:
	var r := String(o["recipe"])
	if is_mix(r):
		return mix(r).get("parts", [])
	return [r] if is_flavor(r) else []


## The flavors customers can ask for now: a coater set to it works (not paused, unpaid or
## saving), or some of it is on hand -- the order of the menu.
func offered_flavors() -> Array:
	var out: Array = []
	for f: String in flavor_ids():
		if not is_flavor(f):
			continue
		var on := false
		for x: String in COATERS:
			for m: Dictionary in _devices(x):
				if coater_serves(m, f):
					on = true
		if not on and (bin_portions_of(f) > 0 or coating_portions(f) > 0):
			on = true
		if not on:
			for p: Dictionary in shelf + packing:
				if String(p["recipe"]) == f:
					on = true
					break
		if on:
			out.append(f)
	return out


## Portions being coated (in the coaters, of one flavor or all): they belong to the bin's room.
func coating_portions(f: String = "") -> int:
	var n := 0
	for x: String in COATERS:
		for m: Dictionary in of_type(x):
			var h: Dictionary = m["held"]
			if not h.is_empty() and (f == "" or String(h["recipe"]) == f):
				n += int(h["portions"])
	return n


## The shelf places the offered flavors' small stock keeps from plain's.
func _flavor_stock_reserved() -> int:
	var n := 0
	for f: String in offered_flavors():
		n += int(flavor(f).get("stock", 0))
	return n


## Whether a flavor is short: what orders and its stock want, against what is coated,
## being coated, packed or packing (so a coater never coats what nobody wants).
func _flavor_wanted(f: String) -> bool:
	return flavor_have(f) < flavor_want(f)


## A flavor's portions on hand: coated in the bin, being coated, packed or packing.
func flavor_have(f: String) -> int:
	var have := bin_portions_of(f) + coating_portions(f)
	for p: Dictionary in shelf + packing:
		if String(p["recipe"]) == f:
			have += pack_portions(p)
	for m: Dictionary in of_type("bagger"):
		var h: Dictionary = m["held"]
		if not h.is_empty() and String(h["recipe"]) == f:
			have += pack_portions(h)
	return have


## What a flavor's orders (a mix's half included), its stock and its buffer want, in portions.
func flavor_want(f: String) -> int:
	var want := int(flavor(f).get("stock", 0)) * pack_size()
	# ... and a slow flavor's buffer coated and waiting in the bin: a large order is packed at
	# once instead of holding the queue for a whole batch (data: buffer; the Step 34 sim).
	want += int(flavor(f).get("buffer", 0))
	if f == news_focus:   # Step 37: the event's crowd is coming -- a batch (or more) ready ahead
		want += int(news_rules().get("focus_ahead", 1)) * int(flavor(f).get("in", 4))
	for c: Dictionary in queue:
		var o: Dictionary = c["order"]
		if String(o["recipe"]) == f:
			want += int(o["size"])
		elif is_mix(String(o["recipe"])) and order_flavors(o).has(f):
			want += int(o["size"]) / 2   # Step 35: half of a mixed bag
	return want


## Plain portions the waiting plain orders still need (not covered by plain packs on hand):
## a coater leaves them in the bin.
func _plain_reserved() -> int:
	var counts := _on_hand_counts()
	var need := 0
	for c: Dictionary in queue:
		var o: Dictionary = c["order"]
		if String(o["recipe"]) != "plain":
			continue
		var key := "plain|%d" % int(o["size"])
		if int(counts.get(key, 0)) > 0:
			counts[key] = int(counts[key]) - 1
		else:
			need += int(o["size"])
	return need


## A batch's coins: the recipe's ingredient coins for `in` portions, scaled to the batch.
func ingredient_cost(f: String, batch: int, full: bool = false) -> int:
	var r := flavor(f)
	var k := 1.0 if full else float((demand_mods.get("ingredients", {}) as Dictionary).get(f, 1.0))   # Step 37: a sale on it
	return int(ceil(float(r.get("ingredient_coins", 0)) * float(batch) / float(maxi(1, int(r.get("in", 4)))) * k - 0.000001))


func coater_batch(m: Dictionary) -> int:
	return int(_machine_tier(m).get("batch", flavor(coater_flavor(m)).get("in", 4)))


## Step 35: what the machine alone gives -- its tier's share of the popcorn's quality, and
## the portions its drum loses (the flavor's loss x the tier's factor, as a fraction).
func auto_quality(m: Dictionary) -> float:
	return float(_machine_tier(m).get("auto_quality", 1.0))


func loss_rate(m: Dictionary, f: String) -> float:
	return float(flavor(f).get("loss", 0.0)) * float(_machine_tier(m).get("loss_factor", 1.0))


## The same in thousandths of a portion a portion (whole numbers: the sum is exact).
func loss_mp(m: Dictionary, f: String) -> int:
	return int(round(loss_rate(m, f) * 1000.0))


## A batch's coating time: per portion x the batch x the coater's tier; the flavor base
## mixer (M12) takes its saved_ms off (never below half); a lubricator (U02) next to it helps.
func coat_ms(m: Dictionary, f: String, batch: int) -> int:
	var ms := float(flavor(f).get("coat_ms_per_portion", 1000)) * float(batch) * float(_machine_tier(m).get("ms_factor", 1.0))
	if _device_on("M12"):
		ms = maxf(ms * 0.5, ms - float(_tier_value("M12", "saved_ms", 1000)))
	return int(round(ms * lube_factor(m)))


func _set_flavor(id: int, f: String) -> Dictionary:
	var m := machine(id)
	if m.is_empty() or not COATERS.has(String(m["type"])):
		return {"ok": false, "reason": "err.unknown"}
	if f == AUTO:   # Step 35: the queue's order picks among its open flavors
		if _open_flavors_of(String(m["type"])).is_empty():
			return {"ok": false, "reason": "err.locked"}
		m["flavor"] = AUTO
		_emit("flavor_set", {"machine": id, "flavor": AUTO})
		return {"ok": true, "flavor": AUTO}
	if not coater_flavors(String(m["type"])).has(f) or not recipe_problems(f).is_empty():
		return {"ok": false, "reason": "err.bad_recipe"}
	if not flavor_open(f):
		return {"ok": false, "reason": "err.locked"}
	m["flavor"] = f   # a batch already coating keeps its own flavor; packed stock never changes
	_emit("flavor_set", {"machine": id, "flavor": f})
	return {"ok": true, "flavor": f}


## A coater: with its flavor short, it takes a batch of plain portions of its line (leaving
## what plain orders need), pays the batch's ingredients (no coins: it waits, never a debt),
## coats for its time while paying upkeep, and puts the same portions back on its line as
## the flavor. Nothing wanted: idle, no upkeep. Paused: the batch waits in the machine.
func _coater_step(m: Dictionary, dt: int) -> void:
	var h: Dictionary = m["held"]
	var line := line_of("packing", int(m["slot"]))
	if h.is_empty():
		var f := _auto_pick(m) if String(m.get("flavor", "")) == AUTO else coater_flavor(m)
		if f == "" or not flavor_open(f) or not recipe_problems(f).is_empty() or not _flavor_wanted(f):
			m["state"] = "idle"
			return
		# Step 35: a bigger drum (tier 1-2) coats what is short, from the recipe's batch up to its
		# size -- a full drum of portions nobody wants held the bin's room and stopped the kettles
		# (the Step 35 sim: tier-2 coaters 318 a minute against 391 with none).
		# ... and from the plain there is: a drum waiting for eight while four were there coated less.
		var avail := mini(bin_portions_of("plain", line), bin_portions_of("plain") - _plain_reserved())
		var batch := clampi(mini(flavor_want(f) - flavor_have(f), avail), int(flavor(f).get("in", 4)), coater_batch(m))
		# Its line's plain makes the batch; the plain orders' popcorn (on any line) stays.
		if avail < batch:
			m["state"] = "starved"
			stats["coater_starved_ms"] = int(stats.get("coater_starved_ms", 0)) + dt
			return
		var cost := ingredient_cost(f, batch)
		if money < cost:
			m["state"] = "unpaid"
			stats["ingredient_short_ms"] = int(stats.get("ingredient_short_ms", 0)) + dt
			return
		money -= cost
		_news_saved(f, ingredient_cost(f, batch, true) - cost)
		for i in cost:
			_note("ingredients")
		stats["ingredient_coins"] = int(stats.get("ingredient_coins", 0)) + cost
		m["ingredients_paid"] = int(m.get("ingredients_paid", 0)) + cost
		var taken := _take_pack(batch, "plain", line)
		var ms := coat_ms(m, f, batch)
		m["held"] = {"id": _new_id(), "recipe": f, "quality": taken["quality"], "portions": batch, "left_ms": ms, "ms": ms, "line": line, "lots": taken["lots"]}
		m["state"] = "run"
		_emit("coat_started", {"machine": m["id"], "flavor": f, "portions": batch, "ms": ms, "cost": cost, "lot": m["held"]["id"]})
		return
	if int(finishing.get("machine", -1)) == int(m["id"]):
		m["state"] = "hand"   # Step 35: the hand holds the batch (no upkeep: the hand does the work)
		return
	if int(h["left_ms"]) > 0:
		if not _pay(m, dt):
			return
		m["state"] = "run"
		h["left_ms"] = int(h["left_ms"]) - dt
		return
	var out_q := int(h["quality"])
	var lost := 0
	if String(h.get("hand", "")) == "":
		# Step 35: the machine alone -- its tier's share of the quality, and its drum's loss
		# (carried in thousandths from batch to batch: a 12% loss is three portions in 25).
		out_q = int(round(float(out_q) * auto_quality(m)))
		var acc := int(m.get("loss_mp", 0)) + loss_mp(m, String(h["recipe"])) * int(h["portions"])   # in thousandths
		lost = mini(acc / 1000, int(h["portions"]) - 1)
		m["loss_mp"] = acc - lost * 1000
		if lost > 0:
			stats["lost_portions"] = int(stats.get("lost_portions", 0)) + lost
			var lb: Dictionary = stats.get("lost", {})
			lb[String(h["recipe"])] = int(lb.get(String(h["recipe"]), 0)) + lost
			stats["lost"] = lb
			_emit("coat_lost", {"machine": m["id"], "flavor": h["recipe"], "portions": lost})
	var lot := {"id": h["id"], "recipe": h["recipe"], "quality": out_q, "portions": int(h["portions"]) - lost, "by": {str(m["id"]): int(h["portions"]) - lost}}
	if String(h.get("hand", "")) != "":
		lot["hand"] = String(h["hand"])
	if parallel_lines():
		lot["line"] = int(h["line"])
	bin.append(lot)
	m["held"] = {}
	m["done"] = int(m.get("done", 0)) + 1
	stats["coated_portions"] = int(stats.get("coated_portions", 0)) + int(lot["portions"])
	var by: Dictionary = stats.get("coated", {})
	by[String(h["recipe"])] = int(by.get(String(h["recipe"]), 0)) + int(lot["portions"])
	stats["coated"] = by
	_emit("lot_coated", {"machine": m["id"], "lot": lot["id"], "flavor": lot["recipe"], "portions": lot["portions"], "line": lot_line(lot), "quality": out_q, "hand": String(h.get("hand", "")), "lost": lost})


# -- Step 35: the hand's finish (one optional action; data: factory.flavors.hand) ----------
## Once the hand has popped unlock_presses times, a coater's batch in the drum can be
## finished by hand: hold the spoon, let go in the flavor's gold. Perfect: the batch at
## perfect_quality; near: near_quality (never below the machine's); no portion lost, the
## batch done at the release. Early or late changes nothing (the machine goes on).

func hand_rules() -> Dictionary:
	return flavors().get("hand", {})


func hand_open() -> bool:
	return not hand_rules().is_empty() and presses >= int(hand_rules().get("unlock_presses", 20))


## The spoon's gold for a flavor: [start, end] ms of the hold.
func finish_window(f: String) -> Array:
	var w: Array = flavor(f).get("hand_ms", [800, 1200])
	return [int(w[0]), int(w[1])]


## A batch the spoon can finish now: in a coater's drum, still coating, not finished yet.
func can_finish(m: Dictionary) -> bool:
	if m.is_empty() or not COATERS.has(String(m["type"])) or not hand_open():
		return false
	var h: Dictionary = m["held"]
	return not h.is_empty() and int(h["left_ms"]) > 0 and String(h.get("hand", "")) == ""


func _finish_press(id: int) -> Dictionary:
	if not finishing.is_empty() or heating:
		return {"ok": false, "reason": "err.hand_busy"}
	if not hand_open():
		return {"ok": false, "reason": "err.locked"}
	var m := machine(id)
	if not can_finish(m):
		return {"ok": false, "reason": "err.nothing_to_finish"}
	var f := String(m["held"]["recipe"])
	finishing = {"machine": id, "ms": 0, "flavor": f}
	var w := finish_window(f)
	_emit("finish_start", {"machine": id, "flavor": f, "window_start": w[0], "window_end": w[1], "drip_at": int(w[1]) + int(hand_rules().get("drip_ms", 1200))})
	return {"ok": true}


## The spoon's judge: B's shape (gold, its edge grace, near on both sides) on the flavor's gold.
func finish_judge(ms: int, f: String) -> String:
	var w := finish_window(f)
	var g := int(hand_rules().get("edge_grace_ms", 40))
	if ms >= int(w[0]) - g and ms <= int(w[1]) + g:
		return PERFECT
	var near := int(hand_rules().get("near_ms", 200))
	if ms < int(w[0]):
		return NEAR if int(w[0]) - ms <= near else EARLY
	return NEAR if ms - int(w[1]) <= near else LATE


func _finish_release() -> Dictionary:
	if finishing.is_empty():
		return {"ok": false, "reason": "err.not_finishing"}
	var id := int(finishing["machine"])
	var ms := int(finishing["ms"])
	var f := String(finishing["flavor"])
	finishing = {}
	var m := machine(id)
	if m.is_empty() or (m["held"] as Dictionary).is_empty():
		return {"ok": false, "reason": "err.nothing_to_finish"}
	var h: Dictionary = m["held"]
	var grade := finish_judge(ms, f)
	var hs: Dictionary = stats.get("hand_finish", {})
	hs[grade] = int(hs.get(grade, 0)) + 1
	stats["hand_finish"] = hs
	var q := int(round(float(h["quality"]) * auto_quality(m)))   # what the machine would give
	if grade == PERFECT or grade == NEAR:
		q = int(hand_rules().get("perfect_quality", 100)) if grade == PERFECT else maxi(q, int(hand_rules().get("near_quality", 90)))
		h["quality"] = q
		h["hand"] = grade
		h["left_ms"] = 0
		stats["hand_portions"] = int(stats.get("hand_portions", 0)) + int(h["portions"])
	_emit("finished", {"machine": id, "grade": grade, "held_ms": ms, "flavor": f, "quality": q, "portions": h["portions"]})
	return {"ok": true, "grade": grade, "quality": q}


# -- Step 35: a prepared start (?scene=flavors) for the blind first-use session --------
## The factory a player has when the flavors open: the sign at 4, the packing station at 3,
## two kettles, a hopper and the flavor base mixer in the kitchen, the sprayer on cheese and
## the coater on caramel on the packing floor -- built through the same commands a player
## uses -- and a hand that has popped 20 times (the spoon is open). A fixture for measuring
## first use, not a play: the app neither loads nor saves it.
func start_scene(name: String) -> bool:
	if name != "flavors":
		return false
	sign_tier = 4
	packer_tier = 3
	level = 3
	stats["packed"] = maxi(1, int(stats["packed"]))
	stats["sold"] = maxi(1, int(stats["sold"]))
	money = 1 << 20
	for t: String in ["cooker", "cooker", "M01", "M12"]:
		_act("build", {"machine": t, "floor": "kitchen"})
	for row: Array in [["P05", "cheese"], ["P06", "caramel"]]:
		var r := _act("build", {"machine": row[0], "floor": "packing"})
		if bool(r["ok"]):
			_set_flavor(int(r["machine"]), String(row[1]))
	presses = maxi(presses, int(hand_rules().get("unlock_presses", 20)))
	money = 1500
	drain_events()
	return true


# -- Step 35: a coater's payback (estimated before buying, measured after) -------------

## What a coater has earned so far: its share of what its coated bags sold for over the
## same bags of butter, less its ingredients and upkeep.
func coater_net(m: Dictionary) -> int:
	return int(m.get("margin", 0)) - int(m.get("ingredients_paid", 0)) - int(m.get("upkeep_paid", 0))


func _check_payback(m: Dictionary) -> void:
	if m.has("paid_back_ms") or coater_net(m) < int(m["paid"]):
		return
	m["paid_back_ms"] = flow_ms - int(m.get("built_ms", 0))
	_emit("paid_back", {"machine": m["id"], "ms": m["paid_back_ms"]})


## Before buying: what a coater of this type and tier would add a minute at this sign's foot
## traffic, coating `f` (the flavor's customers' portions, or what the machine can coat if
## fewer), each portion's price over butter's at the machine's quality, less ingredients and
## upkeep while it works -- and the minutes to earn back `cost`. An estimate (the shown "~").
func coater_estimate(type: String, f: String, tier: int = 0, cost: int = -1) -> Dictionary:
	var t := _machine_tier_of(type, tier)
	var r := flavor(f)
	if r.is_empty() or not is_flavor(f):
		return {}
	var batch := int(t.get("batch", r.get("in", 4)))
	var ms := float(r.get("coat_ms_per_portion", 1000)) * batch * float(t.get("ms_factor", 1.0))
	var cap_ppm := 60000.0 / maxf(1.0, ms) * batch * (1.0 - float(r.get("loss", 0.0)) * float(t.get("loss_factor", 1.0)))
	var cpm := 60000.0 / float(maxi(1, mean_wait_ms(sign_tier)))
	var mean_size := float(pack_size())
	for z: Dictionary in sizes_open():
		if z.has("order_share") and not z.has("unlock_machine"):
			mean_size += float(z["order_share"]) * (float(z["size"]) - float(pack_size()))
	var demand := cpm * float(r.get("order_share", 0.0)) * mean_size
	var served := minf(cap_ppm, demand)
	var plain_q := 80
	var fq := int(round(plain_q * float(t.get("auto_quality", 1.0))))
	var margin := float(pack_price(f, pack_size(), fq) - pack_price("plain", pack_size(), plain_q)) / float(pack_size())
	var ingredients := served * float(r.get("ingredient_coins", 0)) / float(maxi(1, int(r.get("in", 4))))
	var upkeep := float(catalog(type).get("upkeep_per_min", 0)) * (served / maxf(0.001, cap_ppm))
	var net := served * margin - ingredients - upkeep
	var c := build_cost(type) if cost < 0 else cost
	return {"capacity_ppm": snappedf(cap_ppm, 0.1), "demand_ppm": snappedf(demand, 0.1), "served_ppm": snappedf(served, 0.1),
		"revenue_per_min": int(round(served * margin)), "ingredients_per_min": int(round(ingredients)), "upkeep_per_min": int(round(upkeep)),
		"net_per_min": int(round(net)), "payback_min": (snappedf(float(c) / net, 0.1) if net > 0.0 else -1.0), "cost": c, "quality": fq}


# -- Step 35: the board's special (recovering from too much of a flavor) --------------

func promo_rules() -> Dictionary:
	return flavors().get("promo", {})


func promoted(f: String) -> bool:
	return typeof(promo.get(f)) == TYPE_DICTIONARY and bool((promo[f] as Dictionary).get("on", false))


## Once a second: a flavor whose surplus (on hand beyond what its orders, stock and buffer
## want) has lasted after_ms becomes the special; it ends when the surplus is gone.
func _promo_step() -> void:
	var pr := promo_rules()
	if pr.is_empty():
		return
	for f: String in flavor_ids():
		if not is_flavor(f):
			continue
		var surplus := flavor_have(f) - flavor_want(f)
		var cur: Dictionary = promo.get(f, {}) if typeof(promo.get(f)) == TYPE_DICTIONARY else {}
		# A working coater's batch overshoots what is wanted by design and sells on; a surplus
		# nobody makes any more (its coater switched away or stopped) is the special.
		var made := false
		for x: String in COATERS:
			for m: Dictionary in _devices(x):
				if coater_serves(m, f):
					made = true
		if made:
			surplus = 0
		if surplus >= int(pr.get("surplus_portions", 4)):
			if cur.is_empty():
				promo[f] = {"since": flow_ms, "on": false}
			elif not bool(cur["on"]) and flow_ms - int(cur["since"]) >= int(pr.get("after_ms", 20000)):
				cur["on"] = true
				stats["promos"] = int(stats.get("promos", 0)) + 1
				_emit("promo_on", {"flavor": f, "surplus": surplus})
		elif surplus <= 0 or not bool(cur.get("on", false)):
			if not cur.is_empty():
				if bool(cur.get("on", false)):
					_emit("promo_off", {"flavor": f, "ms": flow_ms - int(cur["since"])})
				promo.erase(f)


## M12 the flavor base mixer: it works (and pays) while a coater coats; its effect is in coat_ms.
func _premix_step(m: Dictionary, dt: int) -> void:
	var busy := false
	for x: String in COATERS:
		for c: Dictionary in of_type(x):
			if String(c["state"]) == "run":
				busy = true
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## Takes `size` portions of `recipe` from the bin's oldest lots of it (FIFO)
## into a new pack; its quality is the portions' average (nothing lost).
func _start_pack(size: int, recipe: String) -> void:
	var pack := _take_pack(size, recipe, 0)   # Step 33: the station is the first line's
	var ms := int(round(float(packer()["ms"]) * seal_factor()))
	pack["left_ms"] = ms
	pack["ms"] = ms
	packing.append(pack)
	_emit("pack_started", {"pack": pack["id"], "lots": pack["lots"], "size": size, "head": packing.size() - 1, "ms": ms, "recipe": pack["recipe"]})


## Takes `size` portions of `recipe` from the bin's oldest lots of it into a new
## pack (shared by the station and the baggers, Step 26).
func _take_pack(size: int, recipe: String, line: int = -1) -> Dictionary:
	var acc := {"q": 0, "lots": [], "by": {}, "hand": 0}
	if is_mix(recipe):   # Step 35: a mixed bag -- half of each part, for its order
		var parts: Array = mix(recipe).get("parts", [])
		var half := size / 2
		_take_portions(acc, size - half * (parts.size() - 1), String(parts[0]), line)
		for k in range(1, parts.size()):
			_take_portions(acc, half, String(parts[k]), line)
	else:
		_take_portions(acc, size, recipe, line)
	var pack := {"id": _new_id(), "recipe": pack_sku(recipe), "size": size, "quality": int(acc["q"]) / size, "lots": acc["lots"]}
	if not (acc["by"] as Dictionary).is_empty():
		pack["by"] = acc["by"]   # Step 35: the coaters whose portions are in it (their payback)
	if int(acc["hand"]) > 0:
		pack["hand"] = int(acc["hand"])   # portions the hand finished
	return pack


## `need` portions of `recipe` from the bin's oldest lots of it (FIFO) into `acc`.
func _take_portions(acc: Dictionary, need: int, recipe: String, line: int) -> void:
	var i := 0
	while need > 0:
		var lot: Dictionary = bin[i]
		if String(lot["recipe"]) != recipe or not _on_line(lot, line):
			i += 1
			continue
		var take := mini(need, int(lot["portions"]))
		lot["portions"] = int(lot["portions"]) - take
		acc["q"] = int(acc["q"]) + take * int(lot["quality"])
		need -= take
		(acc["lots"] as Array).append(lot["id"])
		if lot.has("by"):
			var by: Dictionary = acc["by"]
			for k: String in (lot["by"] as Dictionary).keys():
				by[k] = int(by.get(k, 0)) + take   # a coated lot has one coater
		if lot.has("hand"):
			acc["hand"] = int(acc["hand"]) + take
		if int(lot["portions"]) <= 0:
			bin.remove_at(i)


## A sealed pack for the shelf: what it is, and (Step 35) whose coated portions are in it.
func _sealed(p: Dictionary) -> Dictionary:
	var out := {"id": p["id"], "recipe": p["recipe"], "size": p["size"], "quality": p["quality"], "portions": pack_portions(p)}
	for k: String in ["by", "hand"]:
		if p.has(k):
			out[k] = p[k]
	return out


# -- Step 35: mixed bags ---------------------------------------------------------------
func mixes() -> Dictionary:
	return flavors().get("mixes", {})


func mix(id: String) -> Dictionary:
	if id == "order" or id == "_doc":
		return {}
	return (mixes().get(id, {}) as Dictionary) if typeof(mixes().get(id)) == TYPE_DICTIONARY else {}


func is_mix(recipe: String) -> bool:
	return not mix(recipe).is_empty()


func mix_ids() -> Array:
	return mixes().get("order", [])


## A mix is offered while its parts are, its bag is open, and its parts can meet on one
## packing line (a coater of each on it, or its portions already there).
func mix_offered(id: String) -> bool:
	var mx := mix(id)
	if mx.is_empty():
		return false
	var off := offered_flavors()
	for part: String in mx.get("parts", []):
		if not off.has(part):
			return false
	if not station_sizes().has(int(mx.get("size", 4))):
		return false
	if not parallel_lines():
		return true
	for line in packing_lines():
		var all_here := true
		for part: String in mx.get("parts", []):
			var here := bin_portions_of(part, line) > 0
			for x: String in COATERS:
				for m: Dictionary in _devices(x):
					if coater_serves(m, part) and line_of("packing", int(m["slot"])) == line:
						here = true
			if not here:
				all_here = false
		if all_here:
			return true
	return false


func offered_mixes() -> Array:
	return mix_ids().filter(func(x: String) -> bool: return mix_offered(x))


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
	"S01": "shop", "S02": "shop", "S03": "shop", "S04": "shop", "S05": "shop", "S06": "shop", "S08": "shop",
	"U01": "any", "U02": "any", "U03": "any", "U04": "packing", "U05": "packing", "U06": "any", "U07": "any", "U08": "packing"}
## Step 28: the kitchen's devices that serve the kettles (each a catalog id and its own runtime).
const KITCHEN_DEVICES := ["M01", "M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M12", "M13", "M14", "M15", "M16"]
## Step 29: what cooks lots on its own (the auto kettle and the rotary popper): kernels,
## hoppers, the heat and the dispatcher treat them alike.
const KETTLES := ["cooker", "M16"]
## Step 30: the packing floor's machines besides the bagger (P03).
const PACKING_DEVICES := ["P01", "P02", "P04", "P05", "P06", "P07", "P08"]
## Step 31: the storefront's machines besides the kiosk (S07).
const SHOP_DEVICES := ["S01", "S02", "S03", "S04", "S05", "S06", "S08"]
## Step 32: the support machines (most stand on any floor; the buffer lift and the
## inspector between the kitchen and the shelf).
const UTILITY_DEVICES := ["U01", "U02", "U03", "U04", "U05", "U06", "U07", "U08"]
## What makes or moves goods itself (paid first by the maintenance robot U01).
const PRODUCERS := ["cooker", "M16", "bagger", "P01", "kiosk", "S05", "S03"]
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
	var n := int((_t().get("slots", {}) as Dictionary).get(floor, 0)) + line_places(floor)
	if floor == "kitchen":
		n += _kitchen_plus()
	return n


# -- Step 33: lines, routing between parallel packing lines ----------------------

## The places a floor's bought lines add (the first line's places are `slots`).
func line_places(floor: String, lines_n: int = -1) -> int:
	var table: Array = (_t().get("lines", {}) as Dictionary).get(floor, [])
	var n := 0
	var bought := (int(floor_lines.get(floor, 1)) if lines_n < 0 else lines_n) - 1
	for i in mini(bought, table.size()):
		n += int((table[i] as Dictionary)["places"])
	return n


## The line a place belongs to (0 = the first). The kitchen's extra places from the
## multi-pot distributor (M10) come after its lines and stand on the first line.
func line_of(floor: String, slot: int) -> int:
	var k := int((_t().get("slots", {}) as Dictionary).get(floor, 0))
	if slot < k:
		return 0
	var table: Array = (_t().get("lines", {}) as Dictionary).get(floor, [])
	for i in mini(int(floor_lines.get(floor, 1)) - 1, table.size()):
		k += int((table[i] as Dictionary)["places"])
		if slot < k:
			return i + 1
	return 0


## What the floor's next line costs (-1: every line is built).
func line_cost(floor: String) -> int:
	var table: Array = (_t().get("lines", {}) as Dictionary).get(floor, [])
	var i := int(floor_lines.get(floor, 1)) - 1
	return int((table[i] as Dictionary)["cost"]) if i >= 0 and i < table.size() else -1


## Whether every place on the floor holds a machine (a floor grows when it is full).
func floor_full(floor: String) -> bool:
	for k in slots(floor):
		if machine_at(floor, k).is_empty():
			return false
	return true


func _buy_line(floor: String) -> Dictionary:
	if not floor_lines.has(floor):
		return {"ok": false, "reason": "err.unknown"}
	var cost := line_cost(floor)
	if cost < 0:
		return {"ok": false, "reason": "err.max_level"}
	if not floor_full(floor):
		return {"ok": false, "reason": "err.floor_not_full"}
	if money < cost:
		return {"ok": false, "reason": "err.not_enough_money"}
	# The kitchen's distributor places move behind the new line: machines keep their place
	# numbers, so a machine on a distributor place now stands on the new line's place.
	money -= cost
	floor_lines[floor] = int(floor_lines[floor]) + 1
	_emit("line_built", {"floor": floor, "lines": floor_lines[floor], "cost": cost, "money": money, "slots": slots(floor)})
	return {"ok": true, "lines": floor_lines[floor], "cost": cost}


## Two or more packing lines: the bin's lots belong to lines.
func parallel_lines() -> bool:
	return int(floor_lines.get("packing", 1)) >= 2


func packing_lines() -> int:
	return int(floor_lines.get("packing", 1))


func lot_line(lot: Dictionary) -> int:
	return int(lot.get("line", 0))


## A lot on its way between two lines (the route balancer, U08): no line packs it.
func _moving(lot: Dictionary) -> bool:
	return int(lot.get("moving_ms", 0)) > 0


## Whether a lot is packable by a packer of line `line` (-1: any line; with one
## packing line every lot is every packer's).
func _on_line(lot: Dictionary, line: int) -> bool:
	if line < 0 or not parallel_lines():
		return not _moving(lot)
	return lot_line(lot) == line and not _moving(lot)


## The fillers (P03 baggers) on a packing line; the station packs for line 0.
func line_fillers(line: int) -> Array:
	return of_type("bagger").filter(func(x: Dictionary) -> bool: return line_of("packing", int(x["slot"])) == line)


## A line that can pack now: line 0 has the station; another line needs a filler
## that is not paused, unpaid or saving.
func line_working(line: int) -> bool:
	if line == 0:
		return true
	return line_fillers(line).any(func(x: Dictionary) -> bool: return String(x["state"]) not in ["paused", "unpaid", "saving"])


func line_portions(line: int) -> int:
	var n := 0
	for lot: Dictionary in bin:
		if lot_line(lot) == line and not _moving(lot):
			n += int(lot["portions"])
	return n


## Step 34: a line's popcorn still to be worked (coated flavor stock waiting for its orders is
## not a line's load -- counted, a line holding spicy and cocoa got no plain to coat them from).
func _line_load(line: int) -> int:
	var n := 0
	for lot: Dictionary in bin:
		if lot_line(lot) == line and not _moving(lot) and not is_flavor(String(lot["recipe"])):
			n += int(lot["portions"])
	return n


## Dispatch: a landing lot goes to the working line with the least popcorn per
## packer (ties: the first line) -- deterministic, and a line that cannot pack gets nothing.
func _route(lot: Dictionary) -> void:
	if not parallel_lines():
		return
	var best := 0
	var best_load := INF
	for line in packing_lines():
		if not line_working(line):
			continue
		var heads := line_fillers(line).filter(func(x: Dictionary) -> bool: return String(x["state"]) not in ["paused", "unpaid", "saving"]).size() + (1 if line == 0 else 0)
		var load := float(_line_load(line)) / float(maxi(1, heads))
		if load < best_load:
			best_load = load
			best = line
	lot["line"] = best


func _moving_to(line: int) -> int:
	var n := 0
	for lot: Dictionary in bin:
		if _moving(lot) and int(lot["to"]) == line:
			n += int(lot["portions"])
	return n


## Each step with parallel lines: a lot on a line that has no filler at all (it was
## sold) goes back to the first line; then the route balancer (U08) moves goods.
func _lines_step(dt: int) -> void:
	if not parallel_lines():
		return
	var filled := {}
	var working := {}
	for line in packing_lines():
		var fl := line_fillers(line)
		filled[line] = not fl.is_empty()
		working[line] = line == 0 or fl.any(func(x: Dictionary) -> bool: return String(x["state"]) not in ["paused", "unpaid", "saving"])
	var stuck := false
	for lot: Dictionary in bin:
		var line := lot_line(lot)
		if line > 0 and not _moving(lot) and not bool(filled.get(line, false)):
			lot["line"] = 0
			stats["line_orphans"] = int(stats.get("line_orphans", 0)) + 1
		elif line > 0 and not _moving(lot) and not bool(working.get(line, true)):
			stuck = true
	if stuck:
		stats["line_blocked_ms"] = int(stats.get("line_blocked_ms", 0)) + dt


## U08 the route balancer: moves the oldest lots of a stopped line (its fillers all
## paused, unpaid or saving) -- or of a line holding two packs' worth more than an idle
## one -- to a line with nothing to pack; `parallel` lots at a time, each `move_ms`.
## It works (and pays) only while it moves something.
func _balancer_step(m: Dictionary, dt: int) -> void:
	if not parallel_lines():
		m["state"] = "idle"
		return
	var tier := _machine_tier(m)
	var parallel := int(tier.get("parallel", 1))
	var move_ms := int(tier.get("move_ms", 1500))
	var mine: Array = bin.filter(func(l: Dictionary) -> bool: return _moving(l) and int(l.get("mover", -1)) == int(m["id"]))
	if mine.size() < parallel:
		# An idle line: it can pack and holds (with what is on its way to it) less than
		# two packs' worth -- so a lone leftover portion never makes a line look busy.
		var idle := -1
		var enough := 2 * pack_size()
		for line in packing_lines():
			if line_working(line) and line_portions(line) + _moving_to(line) < enough:
				idle = line
				break
		if idle >= 0:
			var from := -1
			for line in packing_lines():
				if line != idle and not line_working(line) and line_portions(line) > 0:
					from = line
					break
			if from < 0:
				for line in packing_lines():
					if line != idle and line_portions(line) >= enough * 2:
						from = line
						break
			if from >= 0:
				for lot: Dictionary in bin:
					if mine.size() >= parallel:
						break
					if lot_line(lot) == from and not _moving(lot):
						lot["moving_ms"] = move_ms
						lot["to"] = idle
						lot["mover"] = m["id"]
						mine.append(lot)
						_emit("lot_moving", {"lot": lot["id"], "from": from, "to": idle, "machine": m["id"], "ms": move_ms})
						break   # one lot a step: the next step asks again (the idle line may be full by then)
	if mine.is_empty():
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"
	for lot: Dictionary in mine:
		lot["moving_ms"] = int(lot["moving_ms"]) - dt
		if int(lot["moving_ms"]) <= 0:
			lot["line"] = int(lot["to"])
			lot.erase("moving_ms")
			lot.erase("to")
			lot.erase("mover")
			stats["moved_lots"] = int(stats.get("moved_lots", 0)) + 1
			m["done"] = int(m.get("done", 0)) + 1
			_emit("lot_moved", {"lot": lot["id"], "line": lot["line"], "machine": m["id"]})


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


func _build(type: String, slot: int, on_floor: String = "") -> Dictionary:
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
	if type == "U08" and not parallel_lines():
		return {"ok": false, "reason": "err.needs_lines"}   # Step 33: it balances two lines or does nothing
	if COATERS.has(type) and _open_flavors_of(type).is_empty():
		return {"ok": false, "reason": "err.locked"}   # Step 34: none of its flavors is open yet
	var floor := String(FLOOR_OF[type])
	if floor == "any":   # Step 32: a support machine stands where it is put
		floor = on_floor if on_floor in ["kitchen", "packing", "shop"] else "kitchen"
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
	if COATERS.has(type):
		m["flavor"] = String(_open_flavors_of(type)[0])   # Step 34: changed on its card
		m["built_ms"] = flow_ms   # Step 35: its payback is timed from here
	next_machine_id += 1
	machines.append(m)
	_type_index_key = -1
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
	if bin.any(func(l: Dictionary) -> bool: return _moving(l) and int(l.get("mover", -1)) == id):
		return {"ok": false, "reason": "err.busy"}   # Step 33: a balancer finishes moving its lots first
	if String(m["type"]) == "M10":
		var left := int((_t().get("slots", {}) as Dictionary).get("kitchen", 0)) + line_places("kitchen") + _kitchen_plus(id)
		for x: Dictionary in machines:
			if String(x["floor"]) == "kitchen" and int(x["slot"]) >= left and int(x["id"]) != id:
				return {"ok": false, "reason": "err.slot_taken"}   # its places hold machines
	var refund := int(m["paid"]) / 2
	money += refund
	machines.erase(m)
	_type_index_key = -1
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
	var per_min := float(catalog(String(m["type"]))["upkeep_per_min"])
	# Step 29, M14 the heat recycler: a cooking kettle's own heat pays part of its keep (never all of it).
	if _is_kettle(m) and _device_on("M14"):
		per_min = maxf(1.0, per_min - _tier_value("M14", "minus", 1))
	if per_min <= 0.0:
		return true
	# Step 32, U03 the energy saver: working machines on its floor cost less to run.
	per_min *= 1.0 - _energy_cut(String(m["floor"]))
	# Step 32, U01 the maintenance robot: when the wallet runs low, helpers stop first so
	# the machines that make, pack and hand over goods keep their coins.
	if _device_on("U01") and money < int((_t().get("utility", {}) as Dictionary).get("low_wallet", 20)) and not PRODUCERS.has(String(m["type"])) and String(m["type"]) != "U01":
		m["state"] = "saving"
		stats["saving_ms"] = int(stats.get("saving_ms", 0)) + dt
		return false
	var per_coin := maxi(1, int(round(60000.0 / per_min)))
	var owed := int(m["upkeep_ms"]) + dt
	if owed >= per_coin:
		if money < 1:
			m["state"] = "unpaid"
			stats["auto_unpaid_ms"] = int(stats["auto_unpaid_ms"]) + dt
			return false
		money -= 1
		stats["upkeep_paid"] = int(stats["upkeep_paid"]) + 1
		m["upkeep_paid"] = int(m.get("upkeep_paid", 0)) + 1   # Step 32: the per-machine ledger
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
			"U01", "U02", "U03", "U04", "U05", "U07":
				_utility_step(m, dt)
			"U08":
				_balancer_step(m, dt)
			"P05", "P06":
				_coater_step(m, dt)
			"M12":
				_premix_step(m, dt)
			"M01":
				_hopper_step(m, dt)
			"M02", "M03", "M04", "M05", "M06", "M08", "M09", "M10", "M11", "M13", "M14", "M15":
				_device_step(m, dt)


## A cooker finishes a lot every cycle; the lot goes up when the bin has room for it,
## else the cooker holds it (blocked, no upkeep).
func _cooker_step(m: Dictionary, dt: int) -> void:
	if not (m["held"] as Dictionary).is_empty():
		var lot: Dictionary = m["held"]
		var room := bin_cap() - bin_portions() - lift_portions() - coating_portions()
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
		# Step 33: a filler packs its own line's goods; the cup feeder takes a portion from any line.
		var line := -1 if cups else line_of("packing", int(m["slot"]))
		var want := _next_pack(allowed, line)
		if want.is_empty():
			m["state"] = "starved" if shelf_room("plain") > 0 else "blocked"
			return
		if shelf_room(pack_sku(String(want["recipe"]))) <= 0:
			m["state"] = "blocked"
			return
		var pack := _take_pack(int(want["size"]), String(want["recipe"]), line)
		var ms := float(_machine_tier(m).get("cycle_ms", 5000 if not cups else 2000))
		if not cups:
			if _device_on("P04"):
				ms += float(_tier_value("P04", "slower_ms", 500))
			elif _overfills() and bin_portions_of(String(want["recipe"]), line) > 0:
				_take_extra(pack, String(want["recipe"]), line)
		pack["left_ms"] = int(round(ms * seal_factor() * lube_factor(m)))
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
	shelf.append(_sealed(h))
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
func _take_extra(pack: Dictionary, recipe: String, line: int = -1) -> void:
	for i in bin.size():
		var lot: Dictionary = bin[i]
		if String(lot["recipe"]) == recipe and int(lot["portions"]) > 0 and _on_line(lot, line):
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
	# Step 32, U05 the quality inspector: a true reject (below the threshold) becomes the
	# bargain SKU -- its own packs, sold only to customers who ask for a bargain -- so it
	# does not drag the plain packs' quality (and price) down.
	var bg: Dictionary = _t().get("bargain", {})
	if _device_on("U05") and String(lot["recipe"]) == "plain" and int(lot["quality"]) < int(bg.get("threshold", 60)) and bin_portions_of("bargain") < int(bg.get("bin", 12)):
		lot["recipe"] = "bargain"
		stats["bargain_lots"] = int(stats.get("bargain_lots", 0)) + 1


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
	var cap := shelf_base()
	var reserved := 0
	var open := sizes_open()
	for z: Dictionary in open:
		reserved += int(z.get("stock", 0))
	for z: Dictionary in open:
		var size := int(z["size"])
		var target := int(z.get("stock", 0)) if z.has("stock") else cap - reserved
		var on := on_hand("plain", size) + on_hand("premium", size)
		want += maxi(0, target - on) * size
	for f: String in offered_flavors():   # Step 34: each offered flavor's small stock
		want += maxi(0, int(flavor(f).get("stock", 0)) - on_hand(f, pack_size())) * pack_size()
	var supply := bin_portions() + lift_portions() + int(glass.get("portions", 0))
	for m: Dictionary in machines:
		supply += int((m["held"] as Dictionary).get("portions", 0)) if _is_kettle(m) or COATERS.has(String(m["type"])) else 0
	return want > supply


# -- Step 28: the kitchen's devices (M01-M06, M08) ---------------------------------

func _devices(type: String) -> Array:
	var out: Array = []
	for x: Dictionary in of_type(type):
		var st := String(x["state"])
		if st != "paused" and st != "unpaid" and st != "saving":
			out.append(x)
	return out


## Whether a working device of that type is on the floor (paused or unpaid ones do nothing).
func _device_on(type: String) -> bool:
	for x: Dictionary in of_type(type):
		var st := String(x["state"])
		if st != "paused" and st != "unpaid" and st != "saving":
			return true
	return false


## Step 33: the machines of a type, in build order -- an index kept with the machine list
## (forty machines asked a dozen questions each, every 50 ms, made filtering the whole
## list the factory's hotspot). Rebuilt when machines are built, sold or loaded.
var _type_index := {}
var _type_index_key := -1


func of_type(type: String) -> Array:
	var key := machines.size() * 100003 + (int(machines[machines.size() - 1]["id"]) if not machines.is_empty() else 0) * 7 + (int(machines[0]["id"]) if not machines.is_empty() else 0)
	if key != _type_index_key:
		_type_index = {}
		for x: Dictionary in machines:
			var t := String(x["type"])
			if not _type_index.has(t):
				_type_index[t] = []
			(_type_index[t] as Array).append(x)
		_type_index_key = key
	return _type_index.get(type, [])


func _any_kettle_in(states: Array) -> bool:
	for t: String in KETTLES:
		for x: Dictionary in of_type(t):
			if states.has(String(x["state"])):
				return true
	return false


## A device that serves one kettle each (M04, M05): kettles in id order, one per device.
func _covered(kettle: Dictionary, type: String) -> bool:
	var n := _devices(type).size()
	var k := 0
	for c: Dictionary in of_type("cooker"):
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
	ms = int(round(ms * lube_factor(m)))
	return maxi(1000, ms)


func _kitchen_busy() -> bool:
	if heating or not lift.is_empty() or cooldown_left > 0:
		return true
	return _any_kettle_in(["run"])


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
	var busy := _any_kettle_in(["run", "waiting", "overheat"]) if needs_kettle else _kitchen_busy()
	if not busy:
		m["state"] = "idle"
		return
	if not _pay(m, dt):
		return
	m["state"] = "run"


## Step 30: the packing floor's devices work (and pay) while the floor packs.
func _packing_device_step(m: Dictionary, dt: int) -> void:
	var busy := not packing.is_empty() or of_type("bagger").any(func(x: Dictionary) -> bool: return String(x["state"]) == "run") or of_type("P01").any(func(x: Dictionary) -> bool: return String(x["state"]) == "run")
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
	_crng.seed = seed_value + 32452843
	cast_rng_state = int(_crng.state)
	_nrng.seed = seed_value + 49979687
	news_rng_state = int(_nrng.state)
	news = _news_fresh()
	news_focus = ""
	base_mods = {}
	demand_mods = {}
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
	_news_count({"recipe": p["recipe"], "size": p["size"]}, "sold")   # Step 37
	if first_sale_ms < 0:
		first_sale_ms = flow_ms
	stats["sold_size_%d" % int(p["size"])] = int(stats.get("sold_size_%d" % int(p["size"]), 0)) + 1   # Step 30: cups, bags
	if String(p["recipe"]) == "premium":
		stats["premium_sold"] = int(stats.get("premium_sold", 0)) + 1
		stats["premium_revenue"] = int(stats.get("premium_revenue", 0)) + coins
	if is_flavor(String(p["recipe"])):   # Step 34: each flavor's sales and coins
		var fs: Dictionary = stats.get("flavor_sold", {})
		fs[String(p["recipe"])] = int(fs.get(String(p["recipe"]), 0)) + 1
		stats["flavor_sold"] = fs
		var fr: Dictionary = stats.get("flavor_revenue", {})
		fr[String(p["recipe"])] = int(fr.get(String(p["recipe"]), 0)) + coins
		stats["flavor_revenue"] = fr
	if is_mix(String(p["recipe"])):
		stats["mix_sold"] = int(stats.get("mix_sold", 0)) + 1
		stats["mix_revenue"] = int(stats.get("mix_revenue", 0)) + coins
	if p.has("hand"):
		stats["hand_sold_portions"] = int(stats.get("hand_sold_portions", 0)) + int(p["hand"])
		if int(p["quality"]) >= 100:
			stats["hand_perfect_bags_sold"] = int(stats.get("hand_perfect_bags_sold", 0)) + 1
	# Step 35: what the coating earned over the same bag of butter goes to the coaters whose
	# portions are in it (by portions) -- each coater's real payback.
	if p.has("by"):
		var margin := coins - pack_price("plain", int(p["size"]), int(p["quality"]))
		var by: Dictionary = p["by"]
		var total := 0
		for k: String in by.keys():
			total += int(by[k])
		var left := margin
		var keys := by.keys()
		for i in keys.size():
			var cm := machine(String(keys[i]).to_int())
			var share := left if i == keys.size() - 1 else int(round(float(margin) * float(by[keys[i]]) / float(maxi(1, total))))
			left -= share
			if not cm.is_empty():
				cm["margin"] = int(cm.get("margin", 0)) + share
				_check_payback(cm)
	if String(p["recipe"]) != String(c["order"]["recipe"]):
		stats["wrong_sku"] = int(stats.get("wrong_sku", 0)) + 1   # must stay 0 (tests)
	# Step 36: a customer served while still in good humour adds to the shop's popularity.
	var rp: Dictionary = _t().get("reputation", {})
	if float(c.get("patience_ms", 0)) >= float(c.get("patience0", c.get("patience_ms", 1))) * float(rp.get("happy_share", 0.34)):
		stats["happy_sales"] = int(stats.get("happy_sales", 0)) + 1
		_reputation(float(rp.get("happy", 1.0)), "happy")
	ledger.append({"t": flow_ms, "customer": c["id"], "pack": p["id"], "recipe": p["recipe"], "size": p["size"], "ordered": c["order"]["size"], "ordered_recipe": c["order"]["recipe"], "quality": p["quality"], "coins": coins})
	if p.has("hand"):   # Step 37: the hand's portions in this bag (a bag may mix them with the machine's)
		ledger[ledger.size() - 1]["hand"] = int(p["hand"])
	if ledger.size() > 500:
		ledger.pop_front()
	stats["sold"] = int(stats["sold"]) + 1
	_note("sales")
	stats["sold_portions"] = int(stats["sold_portions"]) + pack_portions(p)
	stats["revenue"] = int(stats["revenue"]) + coins
	_emit("sale", {"customer": c["id"], "pack": p["id"], "coins": coins, "quality": p["quality"]})
	_earn(coins, {"from": "sale", "customer": c["id"], "pack": p["id"]})


# -- Step 36: the cast, their tastes, the shop's popularity -------------------------------

func cast() -> Dictionary:
	return _t().get("cast", {})


func person(who: String) -> Dictionary:
	return ((cast().get("people", {}) as Dictionary).get(who, {}) as Dictionary)


func newcomers() -> int:
	return int(cast().get("newcomers", 0))


## Who walks in: the classic one for the first newcomers, then by weight (its own generator).
func _draw_who() -> String:
	var order: Array = cast().get("order", [])
	if order.is_empty():
		return "classic"
	if int(stats.get("visitors", 0)) <= newcomers():
		return String(order[0])
	_crng.state = cast_rng_state
	var u := _crng.randf()
	cast_rng_state = int(_crng.state)
	var total := 0.0
	for w: String in order:
		total += float(person(w).get("weight", 0.0))
	var acc := 0.0
	for w: String in order:
		acc += float(person(w).get("weight", 0.0)) / maxf(0.0001, total)
		if u < acc:
			return w
	return String(order[order.size() - 1])


## How much someone likes a recipe (1 when the cast has nothing to say).
func like(who: String, recipe: String) -> float:
	return float((person(who).get("likes", {}) as Dictionary).get(recipe, 1.0))


## A flavor's (or mix's) weight for someone: their like, put off by its price over butter's by
## their price sensitivity, times an event's modifier.
func taste(who: String, recipe: String) -> float:
	var t := like(who, recipe)
	var sens := float(person(who).get("price_sens", 0.0))
	var price := float(_unit_price(recipe))
	if sens > 0.0 and price > 0.0:
		t *= pow(float(_unit_price("plain")) / price, sens)
	return t * float((demand_mods.get("flavors", {}) as Dictionary).get(recipe, 1.0))


## The reputation's one consequence (and an event's): how much sooner the next customer comes.
func arrival_factor() -> float:
	var r: Dictionary = _t().get("reputation", {})
	var k := 1.0 + float(r.get("arrival_effect", 0.0)) * (popularity - 50.0) / 50.0
	return maxf(0.1, k * float(demand_mods.get("arrivals", 1.0)))


func _reputation(delta: float, why: String) -> void:
	var before := stars()
	popularity = float(roundi(clampf(popularity + delta, 0.0, 100.0) * 100.0)) / 100.0   # in hundredths (exact through a save)
	if stars() != before:
		_emit("stars", {"stars": stars(), "why": why})


## Stars on the board: one per 20 points (0-5).
func stars() -> int:
	return clampi(int(floor(popularity / 20.0 + 0.5)), 0, 5)


## The recipe asked for most among the last orders (ties: the menu's order).
func favorite() -> String:
	var n := {}
	for r: String in order_log:
		n[r] = int(n.get(r, 0)) + 1
	var best := ""
	for r: String in n.keys():
		if best == "" or int(n[r]) > int(n[best]):
			best = r
	return best


## Customers a minute now: the sign's foot traffic with the popularity and events.
func customers_per_min() -> float:
	return 60000.0 / float(maxi(1, mean_wait_ms(sign_tier))) * arrival_factor()


# -- Step 37: the news --------------------------------------------------------------
## Timed market events from a seeded schedule (data: factory.news). Each changes one real
## thing -- what customers ask for, how many come, an ingredient's price -- never the money or
## the goods: demand nobody serves earns nothing. demand_mods is recomputed from base_mods and
## the running events on every start and end, so an event is applied exactly once.

func news_rules() -> Dictionary:
	return _t().get("news", {})


func news_event(id: String) -> Dictionary:
	var e: Variant = (news_rules().get("events", {}) as Dictionary).get(id)
	return e if typeof(e) == TYPE_DICTIONARY else {}


func news_ids() -> Array:
	return news_rules().get("order", [])


func _news_fresh() -> Dictionary:
	return {"next_ms": -1, "seq": 0, "active": [], "log": [], "unread": []}


## The channel an event changes ("flavor", "size", "arrivals", "cost").
func news_channel(id: String) -> String:
	return String(news_event(id).get("channel", ""))


## Can the shop answer this event now? Never a flavor it cannot offer (not yet open, no
## coater, no stock), never big bags before a larger bag is open.
func news_eligible(id: String) -> bool:
	var e := news_event(id)
	if e.is_empty() or not station_open("sign"):
		return false
	match String(e.get("channel", "")):
		"flavor", "cost":
			return offered_flavors().has(String(e.get("flavor", "")))
		"size":
			return sizes_open().any(func(z: Dictionary) -> bool: return int(z["size"]) > pack_size())
		"arrivals":
			return true
	return false


func _nrand(range_ms: Array) -> int:
	_nrng.state = news_rng_state
	var v := _nrng.randi_range(int(range_ms[0]), int(range_ms[1]))
	news_rng_state = int(_nrng.state)
	return v


## Every flow step: the schedule starts when the sign first opens; events end at their end
## time; one starts at each scheduled time (start to start).
func _news_step() -> void:
	if news_rules().is_empty() or not station_open("sign"):
		return
	var t := flow_ms
	if int(news["next_ms"]) < 0:
		news["next_ms"] = t + _nrand(news_rules().get("first_ms", [180000, 300000]))
		return
	var ended := false
	for a: Dictionary in (news["active"] as Array).duplicate():
		if t >= int(a["end"]):
			_news_end(a)
			ended = true
	if ended:
		_news_apply()
	if t >= int(news["next_ms"]):
		news["next_ms"] = int(news["next_ms"]) + _nrand(news_rules().get("gap_ms", [100000, 300000]))
		_news_start("")


## Starts an event: `id`, or one drawn (by weight) among those the shop can answer and
## whose channel is free -- not the one that ran last, when there is another.
func _news_start(id: String) -> Dictionary:
	var busy := {}
	for a: Dictionary in news["active"]:
		busy[news_channel(String(a["id"]))] = true
	var pick := id
	if pick == "":
		var last := String((news["log"] as Array).back()["id"]) if not (news["log"] as Array).is_empty() else ""
		var cands: Array = news_ids().filter(func(x: String) -> bool: return news_eligible(x) and not busy.has(news_channel(x)))
		if cands.size() > 1:
			cands = cands.filter(func(x: String) -> bool: return x != last)
		if cands.is_empty():
			stats["news_skipped"] = int(stats.get("news_skipped", 0)) + 1
			return {"ok": false, "reason": "err.no_news"}
		var total := 0.0
		for x: String in cands:
			total += float(news_event(x).get("weight", 1.0))
		_nrng.state = news_rng_state
		var u := _nrng.randf() * total
		news_rng_state = int(_nrng.state)
		pick = String(cands.back())
		for x: String in cands:
			u -= float(news_event(x).get("weight", 1.0))
			if u < 0.0:
				pick = x
				break
	elif not news_eligible(pick) or busy.has(news_channel(pick)):
		return {"ok": false, "reason": "err.no_news"}
	news["seq"] = int(news["seq"]) + 1
	var a := {"n": news["seq"], "id": pick, "start": flow_ms, "end": flow_ms + int(news_event(pick).get("ms", 120000)), "asked": 0, "sold": 0, "saved": 0}
	(news["active"] as Array).append(a)
	(news["unread"] as Array).append(news["seq"])
	stats["news_started"] = int(stats.get("news_started", 0)) + 1
	_news_apply()
	_emit("news_start", {"n": a["n"], "id": pick})
	return {"ok": true, "n": a["n"], "id": pick}


## For tests and the dev hook only: an event now (still only one the shop can answer).
func news_force(id: String) -> Dictionary:
	return _news_start(id)


func _news_end(a: Dictionary) -> void:
	news["active"] = (news["active"] as Array).filter(func(x: Dictionary) -> bool: return int(x["n"]) != int(a["n"]))
	# An unread event that is over is no longer news: the badge does not count it (no stale call).
	news["unread"] = (news["unread"] as Array).filter(func(n: Variant) -> bool: return int(n) != int(a["n"]))
	var row := a.duplicate()
	row["end"] = mini(int(a["end"]), flow_ms)
	(news["log"] as Array).append(row)
	while (news["log"] as Array).size() > 8:
		(news["log"] as Array).pop_front()
	stats["news_ended"] = int(stats.get("news_ended", 0)) + 1
	var subj := String(news_event(String(a["id"])).get("flavor", ""))
	if subj != "" and news_focus == subj and not _news_flavors().has(subj):
		news_focus = ""   # its crowd has gone home
	_emit("news_end", {"n": a["n"], "id": a["id"], "asked": a["asked"], "sold": a["sold"]})


## demand_mods = base_mods x every running event (recomputed, never accumulated).
func _news_apply() -> void:
	var m := base_mods.duplicate(true)
	for a: Dictionary in news.get("active", []):
		var e := news_event(String(a["id"]))
		match String(e.get("channel", "")):
			"flavor":
				var fl: Dictionary = m.get("flavors", {})
				fl[String(e["flavor"])] = float(fl.get(String(e["flavor"]), 1.0)) * float(e.get("demand", 1.0))
				m["flavors"] = fl
			"cost":
				var ing: Dictionary = m.get("ingredients", {})
				ing[String(e["flavor"])] = float(ing.get(String(e["flavor"]), 1.0)) * float(e.get("ingredients", 1.0))
				m["ingredients"] = ing
			"size":
				m["large"] = float(m.get("large", 1.0)) * float(e.get("large", 1.0))
			"arrivals":
				m["arrivals"] = float(m.get("arrivals", 1.0)) * float(e.get("arrivals", 1.0))
	demand_mods = m
	if _device_on("U07"):   # Step 37: the demand scheduler puts the news's flavor first by itself
		var fl := _news_flavors()
		if not fl.is_empty() and not fl.has(news_focus):
			news_focus = String(fl[0])


## The flavors running events are about (demand or a sale), in their order.
func _news_flavors() -> Array:
	var out: Array = []
	for a: Dictionary in news.get("active", []):
		var f := String(news_event(String(a["id"])).get("flavor", ""))
		if f != "" and not out.has(f):
			out.append(f)
	return out


## Does this order answer a running event? (what it brought: asked; what it sold: sold)
func _news_hits(e: Dictionary, o: Dictionary) -> bool:
	match String(e.get("channel", "")):
		"flavor", "cost":
			return order_flavors(o).has(String(e.get("flavor", "")))
		"size":
			return int(o["size"]) > pack_size()
		"arrivals":
			return true
	return false


func _news_count(o: Dictionary, key: String) -> void:
	for a: Dictionary in news.get("active", []):
		if _news_hits(news_event(String(a["id"])), o):
			a[key] = int(a[key]) + 1


func _news_saved(f: String, coins: int) -> void:
	if coins <= 0:
		return
	stats["news_saved_coins"] = int(stats.get("news_saved_coins", 0)) + coins
	for a: Dictionary in news.get("active", []):
		var e := news_event(String(a["id"]))
		if String(e.get("channel", "")) == "cost" and String(e.get("flavor", "")) == f:
			a["saved"] = int(a["saved"]) + coins


## A customer who gives up waiting for a running flavor event's flavor costs no popularity.
func _news_spares(o: Dictionary) -> bool:
	if not bool(news_rules().get("spare_left", true)):
		return false
	for a: Dictionary in news.get("active", []):
		var e := news_event(String(a["id"]))
		if String(e.get("channel", "")) == "flavor" and order_flavors(o).has(String(e.get("flavor", ""))):
			return true
	return false


func _news_read() -> Dictionary:
	var n := (news["unread"] as Array).size()
	news["unread"] = []
	return {"ok": true, "read": n}


## The card's button: put a running event's flavor first (the same flavor again lets go).
func _news_set_focus(f: String) -> Dictionary:
	if f == "" or f == news_focus:
		news_focus = ""
		return {"ok": true, "focus": ""}
	if not _news_flavors().has(f):
		return {"ok": false, "reason": "err.no_news"}
	news_focus = f
	return {"ok": true, "focus": f}


func news_state() -> Dictionary:
	var act: Array = []
	for a: Dictionary in news.get("active", []):
		act.append(_news_row(a, true))
	var past: Array = []
	for a: Dictionary in (news.get("log", []) as Array).slice(-3):
		past.append(_news_row(a, false))
	return {"active": act, "log": past, "unread": (news.get("unread", []) as Array).size(), "focus": news_focus,
		"next_in_ms": maxi(0, int(news.get("next_ms", -1)) - flow_ms) if int(news.get("next_ms", -1)) >= 0 else -1,
		"scheduler": _device_on("U07")}


func _news_row(a: Dictionary, running: bool) -> Dictionary:
	var e := news_event(String(a["id"]))
	var r := {"n": a["n"], "id": a["id"], "name": String(e.get("name", a["id"])), "channel": String(e.get("channel", "")), "flavor": String(e.get("flavor", "")),
		"mult": float(e.get({"flavor": "demand", "size": "large", "arrivals": "arrivals", "cost": "ingredients"}.get(String(e.get("channel", "")), "demand"), 1.0)),
		"ms": int(a["end"]) - int(a["start"]), "asked": a["asked"], "sold": a["sold"], "saved": a.get("saved", 0)}
	r["left_ms"] = maxi(0, int(a["end"]) - flow_ms) if running else 0
	return r


func set_demand_mods(mods: Dictionary) -> void:
	base_mods = mods.duplicate(true)
	_news_apply()


func _arrive() -> void:
	var f := _t()["customers"] as Dictionary
	# Every visitor is logged (Step 22): those who join the queue ("arrived")
	# and those who find it full and walk past ("passed_by").
	arrival_log.append(flow_ms)
	if arrival_log.size() > 400:
		arrival_log.pop_front()
	stats["visitors"] = int(stats.get("visitors", 0)) + 1
	var who := _draw_who()
	# Step 36: each walks past a queue longer than they will wait in (never a penalty).
	if queue.size() >= mini(queue_cap(), int(person(who).get("tolerance", 99))):
		stats["passed_by"] = int(stats["passed_by"]) + 1
		var pb: Dictionary = stats.get("passed_by_who", {})
		pb[who] = int(pb.get(who, 0)) + 1
		stats["passed_by_who"] = pb
		_emit("customer_passed", {"who": who})
		return
	# Step 36: the first customers are classic ones asking for a small Classic Butter.
	var order := {"recipe": "plain", "size": pack_size()} if int(stats.get("arrived", 0)) < newcomers() else _draw_order(who)
	# Step 34: a flavor's customers wait by its willingness (spicy fans wait longest).
	var patience := int(f["patience_ms"])
	if is_flavor(String(order["recipe"])):
		patience = int(round(patience * float(flavor(String(order["recipe"])).get("patience", 1.0))))
	elif is_mix(String(order["recipe"])):
		patience = int(round(patience * float(mix(String(order["recipe"])).get("patience", 1.0))))
	patience = int(round(patience * float(person(who).get("patience", 1.0))))   # Step 36: their temper
	var c := {"id": _new_id(), "order": order, "patience_ms": patience, "patience0": patience, "who": who}
	queue.append(c)
	stats["arrived"] = int(stats["arrived"]) + 1
	var by: Dictionary = stats.get("arrived_who", {})
	by[who] = int(by.get(who, 0)) + 1
	stats["arrived_who"] = by
	_news_count(order, "asked")   # Step 37: what each running event brought
	var ak: Dictionary = stats.get("asked_recipe", {})
	ak[String(order["recipe"])] = int(ak.get(String(order["recipe"]), 0)) + 1
	stats["asked_recipe"] = ak
	order_log.append(String(order["recipe"]))
	if order_log.size() > 30:
		order_log.pop_front()
	_emit("customer_arrived", {"customer": c["id"], "order": c["order"], "who": who})


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
	wait /= arrival_factor()   # Step 36: popularity and events bring people in sooner (or later)
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
const SAVE_OPTIONAL := ["order_rng_state", "recent", "glass_held_ms", "machines", "next_machine_id", "auto_rng_state", "bn_ring", "promo", "popularity", "popularity_c", "cast_rng_state", "demand_mods", "order_log", "news", "news_focus", "news_rng_state"]


func to_save() -> Dictionary:
	var d := {"rng_state": str(rng_state), "stats": stats.duplicate(true), "outcomes": outcomes.duplicate(),
		"order_rng_state": str(order_rng_state), "recent": recent.duplicate(true), "glass_held_ms": glass_held_ms,
		"machines": machines.duplicate(true), "next_machine_id": next_machine_id, "auto_rng_state": str(auto_rng_state), "bn_ring": bn_ring.duplicate(), "kitchen_heat": kitchen_heat, "overheat_left": overheat_left, "pack_rng_state": str(pack_rng_state), "paying": paying.duplicate(true), "floor_lines": floor_lines.duplicate(), "promo": promo.duplicate(true),
		"popularity": popularity, "popularity_c": roundi(popularity * 100.0), "cast_rng_state": str(cast_rng_state), "demand_mods": base_mods.duplicate(true), "order_log": order_log.duplicate(),
		"news": news.duplicate(true), "news_focus": news_focus, "news_rng_state": str(news_rng_state)}
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
	_type_index_key = -1
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
	# Step 33: the floors' lines (optional: a 0.32 save has one line a floor).
	floor_lines = {"kitchen": 1, "packing": 1, "shop": 1}
	if typeof(d.get("floor_lines")) == TYPE_DICTIONARY:
		for f: String in floor_lines.keys():
			var max_n := ((_t().get("lines", {}) as Dictionary).get(f, []) as Array).size() + 1
			if typeof((d["floor_lines"] as Dictionary).get(f)) == TYPE_INT:
				floor_lines[f] = clampi(int(d["floor_lines"][f]), 1, max_n)
	# Step 28: a kettle saved before kernels existed (0.25-0.27) comes back with a full
	# buffer -- the save keeps cooking; it is not starved by an update.
	for m: Dictionary in machines:
		if String(m.get("type", "")) == "cooker" and not m.has("kernels"):
			m["kernels"] = int(_auto().get("kernel_buffer", 5))
	# Step 34: a coater's flavor is one of its own (a hand-edited or older save gets its first).
	for m: Dictionary in machines:
		if COATERS.has(String(m.get("type", ""))) and not coater_flavors(String(m["type"])).has(String(m.get("flavor", ""))) and String(m.get("flavor", "")) != AUTO:
			m["flavor"] = String(coater_flavors(String(m["type"]))[0])
	next_machine_id = maxi(int(d.get("next_machine_id", 1)), machines.size() + 1)
	promo = (d.get("promo", {}) as Dictionary).duplicate(true) if typeof(d.get("promo", {})) == TYPE_DICTIONARY else {}   # Step 35
	finishing = {}   # a hold does not outlive the page
	# Step 36 (optional: a 0.35 save has none -- a shop of average popularity, its cast from here).
	popularity = clampf(float(d.get("popularity", _t().get("reputation", {}).get("start", 50.0))), 0.0, 100.0) if typeof(d.get("popularity", 0)) in [TYPE_INT, TYPE_FLOAT] else 50.0
	if typeof(d.get("popularity_c")) == TYPE_INT:
		popularity = float(clampi(int(d["popularity_c"]), 0, 10000)) / 100.0
	if String(d.get("cast_rng_state", "")).is_valid_int():
		cast_rng_state = String(d["cast_rng_state"]).to_int()
	base_mods = (d.get("demand_mods", {}) as Dictionary).duplicate(true) if typeof(d.get("demand_mods", {})) == TYPE_DICTIONARY else {}
	# Step 37 (optional: a 0.36 save has no news -- its schedule starts from here).
	news = _news_fresh()
	if typeof(d.get("news")) == TYPE_DICTIONARY:
		var dn: Dictionary = d["news"]
		for k: String in news.keys():
			if dn.has(k) and typeof(dn[k]) == typeof(news[k]):
				news[k] = dn[k].duplicate(true) if typeof(dn[k]) in [TYPE_ARRAY, TYPE_DICTIONARY] else dn[k]
		news["active"] = (news["active"] as Array).filter(func(a: Variant) -> bool: return typeof(a) == TYPE_DICTIONARY and not news_event(String(a.get("id", ""))).is_empty())
	news_focus = String(d.get("news_focus", "")) if typeof(d.get("news_focus", "")) == TYPE_STRING else ""
	if String(d.get("news_rng_state", "")).is_valid_int():
		news_rng_state = String(d["news_rng_state"]).to_int()
	_news_apply()
	order_log = (d.get("order_log", []) as Array).duplicate() if typeof(d.get("order_log", [])) == TYPE_ARRAY else []
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
	s["bin_cap"] = bin_cap()
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
		"tier": m["tier"], "state": m["state"], "assist": m["assist"], "done": int(m.get("done", 0)), "held": int((m["held"] as Dictionary).get("portions", (m["held"] as Dictionary).get("size", 0))), "kernels": int(m.get("kernels", 0)), "line": line_of(String(m["floor"]), int(m["slot"]))})
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
	s["overview"] = upkeep_overview()   # Step 32
	s["paying_ids"] = paying.map(func(pv: Dictionary) -> int: return int(pv["customer"]["id"]))
	s["counter_lanes"] = lanes()
	# Step 33: the lines, their places and costs, the parallel packing lines' goods.
	s["lines"] = floor_lines.duplicate()
	s["line_cost"] = {"kitchen": line_cost("kitchen"), "packing": line_cost("packing"), "shop": line_cost("shop")}
	s["slots"] = {"kitchen": slots("kitchen"), "packing": slots("packing"), "shop": slots("shop")}
	s["parallel"] = parallel_lines()
	var lp: Array = []
	for line in packing_lines():
		lp.append(line_portions(line))
	s["line_portions"] = lp
	s["moving_lots"] = bin.filter(func(l: Dictionary) -> bool: return _moving(l)).size()
	# Step 34: the flavors -- open, offered, their stock and portions, each coater's flavor.
	var fl: Array = []
	for f: String in flavor_ids():
		var on_shelf := 0
		for p: Dictionary in shelf:
			if String(p["recipe"]) == f:
				on_shelf += 1
		fl.append({"id": f, "name": String(flavor(f).get("name", f)), "open": flavor_open(f), "offered": f == "plain" or offered_flavors().has(f),
			"price": pack_price(f, pack_size(), 100), "shelf": on_shelf, "bin": bin_portions_of(f), "coating": coating_portions(f),
			"waiting": queue.filter(func(c: Dictionary) -> bool: return String(c["order"]["recipe"]) == f).size()})
	s["flavors"] = fl
	s["coaters"] = machines.filter(func(m: Dictionary) -> bool: return COATERS.has(String(m["type"]))).map(func(m: Dictionary) -> Dictionary: return {"id": m["id"], "type": m["type"],
		"flavor": String(m.get("flavor", "")), "state": m["state"], "held": String((m["held"] as Dictionary).get("recipe", "")), "line": line_of("packing", int(m["slot"])),
		"left_ms": int((m["held"] as Dictionary).get("left_ms", 0)), "ms": int((m["held"] as Dictionary).get("ms", 0)), "batches": int(m.get("done", 0)), "ingredients": int(m.get("ingredients_paid", 0))})
	s["orders_recipe"] = queue.map(func(c: Dictionary) -> String: return String(c["order"]["recipe"]))
	# Step 35: the hand's finish, the mixes, the special, each coater's payback.
	s["hand_open"] = hand_open()
	s["finishing"] = finishing.duplicate()
	s["mixes"] = mix_ids().map(func(x: String) -> Dictionary: return {"id": x, "name": String(mix(x).get("name", x)), "offered": mix_offered(x), "parts": mix(x).get("parts", []),
		"waiting": queue.filter(func(c: Dictionary) -> bool: return String(c["order"]["recipe"]) == x).size()})
	s["promo"] = flavor_ids().filter(func(f: String) -> bool: return promoted(f))
	# Step 36: the cast in the queue, the shop's popularity and what it does, the favorite.
	s["popularity"] = snappedf(popularity, 0.1)
	s["stars"] = stars()
	s["customers_per_min"] = snappedf(customers_per_min(), 0.1)
	s["favorite"] = favorite()
	s["queue_who"] = queue.map(func(c: Dictionary) -> String: return String(c.get("who", "classic")))
	s["news"] = news_state()   # Step 37
	s["demand_mods"] = demand_mods.duplicate(true)
	for cs: Dictionary in s["coaters"]:
		var cm := machine(int(cs["id"]))
		cs["mode"] = String(cm.get("flavor", ""))
		cs["can_finish"] = can_finish(cm)
		cs["margin"] = int(cm.get("margin", 0))
		cs["net"] = coater_net(cm)
		cs["upkeep"] = int(cm.get("upkeep_paid", 0))
		cs["paid"] = int(cm["paid"])
		cs["paid_back_ms"] = int(cm.get("paid_back_ms", -1))
		cs["since_ms"] = flow_ms - int(cm.get("built_ms", 0))
		cs["quality"] = int((cm["held"] as Dictionary).get("quality", 0))
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
	if queue.is_empty() and shelf.size() >= shelf_base() / 2:
		return "demand"
	return ""
