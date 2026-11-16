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
var packing := {}           ## the pack being filled: {id, recipe, size, quality, left_ms} ({} = idle)
var shelf: Array = []       ## sealed packs, oldest first: {id, recipe, size, quality}
var queue: Array = []       ## customers waiting, head first: {id, order: {recipe, size}, patience_ms}
var serving := {}           ## {customer, pack, left_ms} while a pack is being handed over
var next_arrival_ms := 0    ## flow time of the next customer (absolute)
var flow_ms := 0            ## flow time done (a multiple of FLOW_STEP_MS)
var rng_state := 0          ## the arrival generator's state (saved)
var next_id := 1
## What happened, for the invariants, the statistics and the tests.
var stats := {"made_portions": 0, "lots": 0, "packed": 0, "sold": 0, "sold_portions": 0, "revenue": 0, "abandoned": 0,
	"passed_by": 0, "arrived": 0, "glass_wait_ms": 0, "packer_starved_ms": 0, "packer_blocked_ms": 0, "counter_empty_ms": 0}
var _rng := RandomNumberGenerator.new()


func _init(p_economy: PopEconomy = null, seed_value: int = 20261116) -> void:
	super(p_economy)
	variant = "factory"
	_rng.seed = seed_value
	rng_state = int(_rng.state)
	# The first customer is already waiting when the shop opens (design/FACTORY_FLOW.md 5).
	_arrive()
	var f := _t()["customers"] as Dictionary
	next_arrival_ms = _rng.randi_range(int(f["second_ms"][0]), int(f["second_ms"][1]))
	rng_state = int(_rng.state)


func _t() -> Dictionary:
	return economy.table(variant)


func _judge(ms: int) -> String:
	var g := int(_t().get("edge_grace_ms", 0))
	if ms >= window_start() - g and ms <= window_end() + g:
		return PERFECT
	return super(ms)


func _new_id() -> int:
	next_id += 1
	return next_id - 1


# -- numbers ----------------------------------------------------------------

func kettle_capacity(at_level: int = -1) -> int:
	var lv := level if at_level < 0 else at_level
	var caps: Array = _t()["kettle_portions"]
	return int(caps[clampi(lv, 0, caps.size() - 1)])


## What the upgrade card shows as '+now > +next': portions of a perfect pop.
func payout(at_level: int) -> int:
	if at_level < 0 or at_level > max_level():
		return -1
	return kettle_capacity(at_level)


func pack_size() -> int:
	return int(_t()["pack"]["size"])


func pack_price(recipe: String, size: int, quality: int) -> int:
	var base := int((_t()["price"] as Dictionary).get(recipe, 0)) * size / pack_size()
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
	if not packing.is_empty():
		n += int(packing["size"])
	for p: Dictionary in shelf:
		n += int(p["size"])
	if not serving.is_empty():
		n += int(serving["pack"]["size"])
	return n + int(stats["sold_portions"])


# -- the hand -----------------------------------------------------------------

func _act(kind: String, cmd: Dictionary) -> Dictionary:
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
	heating = false
	heat_ms = 0
	cooldown_left = _cooldown_ms()
	outcomes[kind] = int(outcomes[kind]) + 1
	var lot := {"id": _new_id(), "recipe": "plain", "quality": int(GRADE_QUALITY[kind]), "portions": portions}
	glass = lot
	stats["made_portions"] = int(stats["made_portions"]) + portions
	stats["lots"] = int(stats["lots"]) + 1
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
	# 1. The glass pours into the lift when the bin will have room for the lot.
	if not glass.is_empty():
		var room := int(t["bin_portions"]) - bin_portions() - lift_portions()
		if room >= int(glass["portions"]):
			lift.append({"lot": glass, "left_ms": int(t["lift_ms"])})
			_emit("lot_lifted", {"lot": glass["id"]})
			glass = {}
		else:
			stats["glass_wait_ms"] = int(stats["glass_wait_ms"]) + dt
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
	# 3. The packer.
	if packing.is_empty():
		var size := pack_size()
		if bin_portions() < size:
			stats["packer_starved_ms"] = int(stats["packer_starved_ms"]) + dt
		elif shelf.size() >= int(t["shelf_packs"]):
			stats["packer_blocked_ms"] = int(stats["packer_blocked_ms"]) + dt
		else:
			_start_pack(size)
	else:
		packing["left_ms"] = int(packing["left_ms"]) - dt
		if int(packing["left_ms"]) <= 0:
			var pack := {"id": packing["id"], "recipe": packing["recipe"], "size": packing["size"], "quality": packing["quality"]}
			shelf.append(pack)
			packing = {}
			stats["packed"] = int(stats["packed"]) + 1
			_emit("pack_shelved", {"pack": pack["id"]})
	# 4. Customers arrive.
	if flow_ms + dt >= next_arrival_ms:
		_arrive()
		_schedule_arrival()
	# 5. Patience: everyone waiting (not the one being served) loses dt.
	var stay: Array = []
	for c: Dictionary in queue:
		c["patience_ms"] = int(c["patience_ms"]) - dt
		if int(c["patience_ms"]) <= 0:
			stats["abandoned"] = int(stats["abandoned"]) + 1
			_emit("customer_left", {"customer": c["id"], "why": "waited"})
		else:
			stay.append(c)
	queue = stay
	# 6. The counter: the head of the queue, with a pack that matches.
	if serving.is_empty():
		if queue.is_empty():
			stats["counter_empty_ms"] = int(stats["counter_empty_ms"]) + dt
		else:
			var head: Dictionary = queue[0]
			var idx := _matching_pack(head["order"])
			if idx >= 0:
				var pack: Dictionary = shelf[idx]
				shelf.remove_at(idx)
				queue.remove_at(0)
				serving = {"customer": head, "pack": pack, "left_ms": int(t["service_ms"])}
				_emit("serve_started", {"customer": head["id"], "pack": pack["id"]})
	else:
		serving["left_ms"] = int(serving["left_ms"]) - dt
		if int(serving["left_ms"]) <= 0:
			_sell()


func _start_pack(size: int) -> void:
	var need := size
	var q_sum := 0
	var used: Array = []
	while need > 0:
		var lot: Dictionary = bin[0]
		var take := mini(need, int(lot["portions"]))
		lot["portions"] = int(lot["portions"]) - take
		q_sum += take * int(lot["quality"])
		need -= take
		used.append(lot["id"])
		if int(lot["portions"]) <= 0:
			bin.remove_at(0)
	packing = {"id": _new_id(), "recipe": "plain", "size": size, "quality": q_sum / size, "left_ms": int(_t()["pack"]["ms"])}
	_emit("pack_started", {"pack": packing["id"], "lots": used, "size": size})


func _matching_pack(order: Dictionary) -> int:
	for i in shelf.size():
		var p: Dictionary = shelf[i]
		if String(p["recipe"]) == String(order["recipe"]) and int(p["size"]) == int(order["size"]):
			return i
	return -1


func _sell() -> void:
	var c: Dictionary = serving["customer"]
	var p: Dictionary = serving["pack"]
	var coins := pack_price(String(p["recipe"]), int(p["size"]), int(p["quality"]))
	serving = {}
	stats["sold"] = int(stats["sold"]) + 1
	stats["sold_portions"] = int(stats["sold_portions"]) + int(p["size"])
	stats["revenue"] = int(stats["revenue"]) + coins
	_emit("sale", {"customer": c["id"], "pack": p["id"], "coins": coins, "quality": p["quality"]})
	_earn(coins, {"from": "sale", "customer": c["id"], "pack": p["id"]})


func _arrive() -> void:
	var f := _t()["customers"] as Dictionary
	if queue.size() >= int(f["queue_cap"]):
		stats["passed_by"] = int(stats["passed_by"]) + 1
		_emit("customer_passed", {})
		return
	var c := {"id": _new_id(), "order": {"recipe": "plain", "size": pack_size()}, "patience_ms": int(f["patience_ms"])}
	queue.append(c)
	stats["arrived"] = int(stats["arrived"]) + 1
	_emit("customer_arrived", {"customer": c["id"], "order": c["order"]})


## The next customer: a triangular wait between min and max around `mode`
## (expected ~15 s; never a fixed timer), from a seeded generator so a run is
## reproducible; at least min_gap after this one, never more than `drought`.
func _schedule_arrival() -> void:
	var f := _t()["customers"] as Dictionary
	_rng.state = rng_state
	var lo := float(f["min_ms"])
	var hi := float(f["max_ms"])
	var mo := float(f["mode_ms"])
	var u := _rng.randf()
	var c := (mo - lo) / (hi - lo)
	var wait := lo + sqrt(u * (hi - lo) * (mo - lo)) if u < c else hi - sqrt((1.0 - u) * (hi - lo) * (hi - mo))
	rng_state = int(_rng.state)
	wait = clampf(wait, float(f["min_gap_ms"]), float(f["drought_ms"]))
	next_arrival_ms = flow_ms + FLOW_STEP_MS + int(wait)


# -- reading it ---------------------------------------------------------------

func state() -> Dictionary:
	var s := super()
	s["glass"] = glass.duplicate()
	s["lift"] = lift.size()
	s["bin_portions"] = bin_portions()
	s["bin_cap"] = int(_t()["bin_portions"])
	s["packing"] = packing.duplicate()
	s["shelf"] = shelf.size()
	s["shelf_cap"] = int(_t()["shelf_packs"])
	s["queue"] = queue.size()
	s["queue_cap"] = int((_t()["customers"] as Dictionary)["queue_cap"])
	s["serving"] = not serving.is_empty()
	s["stats"] = stats.duplicate()
	s["kettle_capacity"] = kettle_capacity()
	s["next_arrival_ms"] = next_arrival_ms
	s["bottleneck"] = bottleneck()
	s["portions_everywhere"] = portions_everywhere()
	return s


## Which stage holds the line back right now (no spreadsheet: the view turns
## it into a picture, Step 23): 'kitchen' (the packer is starved), 'packing'
## (customers wait for packs), 'shop' (packs wait for customers), or '' (flowing).
func bottleneck() -> String:
	if not queue.is_empty() and shelf.is_empty() and serving.is_empty():
		return "kitchen" if packing.is_empty() and bin_portions() < pack_size() else "packing"
	if queue.is_empty() and shelf.size() >= int(_t()["shelf_packs"]):
		return "shop"
	if not glass.is_empty():
		return "shop" if shelf.size() >= int(_t()["shelf_packs"]) else "packing"
	return ""
