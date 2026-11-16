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
var shelf: Array = []       ## sealed packs, oldest first: {id, recipe, size, quality}
var queue: Array = []       ## customers waiting, head first: {id, order: {recipe, size}, patience_ms}
## Step 21: the counter's lanes, each handing one pack over: {customer, pack,
## left_ms, lane}. `serving` is the first of them (the one-lane shop, Step 17).
var serves: Array = []
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
	"passed_by": 0, "arrived": 0, "glass_wait_ms": 0, "packer_starved_ms": 0, "packer_blocked_ms": 0, "counter_empty_ms": 0}
var _rng := RandomNumberGenerator.new()


func _init(p_economy: PopEconomy = null, seed_value: int = 20261116) -> void:
	super(p_economy)
	variant = "factory"
	burst_mode = true   # the crescendo is the factory's (Step 19: B -> C as real extra portions)
	_rng.seed = seed_value
	rng_state = int(_rng.state)
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
	return int(r[clampi(level, 0, r.size() - 1)])


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
	if packable_recipe() == "":
		return "starved"
	if shelf.size() >= int(_t()["shelf_packs"]):
		return "blocked"
	return "idle"


func _buy_packer() -> Dictionary:
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


func auto_attempt(at_level: int) -> Dictionary:
	var a := _t()["auto_cooker"] as Dictionary
	var cap := kettle_capacity(at_level) * float(a["capacity_share"])
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
		n += int(p["size"])
	for p: Dictionary in shelf:
		n += int(p["size"])
	for sv: Dictionary in serves:
		n += int(sv["pack"]["size"])
	return n + int(stats["sold_portions"])


# -- the hand -----------------------------------------------------------------

func _act(kind: String, cmd: Dictionary) -> Dictionary:
	if kind == "buy_packer":
		return _buy_packer()
	if kind == "buy_sign":
		return _buy_sign()
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
	# 3. The packer: every head fills one pack in the tier's time; a cycle starts
	# with as many packs as there are heads, portions in the bin and places on
	# the shelf (never more -- the shelf is never over-filled).
	if packing.is_empty():
		var size := pack_size()
		var room := int(t["shelf_packs"]) - shelf.size()
		if packable_recipe() == "":
			stats["packer_starved_ms"] = int(stats["packer_starved_ms"]) + dt
		elif room <= 0:
			stats["packer_blocked_ms"] = int(stats["packer_blocked_ms"]) + dt
		else:
			for k in int(packer()["per_cycle"]):
				var r := packable_recipe()
				if r == "" or room <= 0:
					break
				_start_pack(size, r)
				room -= 1
	else:
		var still_packing: Array = []
		for p: Dictionary in packing:
			p["left_ms"] = int(p["left_ms"]) - dt
			if int(p["left_ms"]) <= 0:
				var pack := {"id": p["id"], "recipe": p["recipe"], "size": p["size"], "quality": p["quality"]}
				shelf.append(pack)
				stats["packed"] = int(stats["packed"]) + 1
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
	for c: Dictionary in queue:
		c["patience_ms"] = int(c["patience_ms"]) - dt
		if int(c["patience_ms"]) <= 0:
			stats["abandoned"] = int(stats["abandoned"]) + 1
			_emit("customer_left", {"customer": c["id"], "why": "waited"})
		else:
			stay.append(c)
	queue = stay
	# 6. The counter: every lane hands its pack over; a free lane takes the head
	# of the queue (in order -- nobody jumps it) when a matching pack is there.
	var going: Array = []
	for sv: Dictionary in serves:
		sv["left_ms"] = int(sv["left_ms"]) - dt
		if int(sv["left_ms"]) <= 0:
			_sell(sv)
		else:
			going.append(sv)
	serves = going
	if serves.is_empty() and queue.is_empty():
		stats["counter_empty_ms"] = int(stats["counter_empty_ms"]) + dt
	while serves.size() < lanes() and not queue.is_empty():
		var head: Dictionary = queue[0]
		var idx := _matching_pack(head["order"])
		if idx < 0:
			break
		var pack: Dictionary = shelf[idx]
		shelf.remove_at(idx)
		queue.remove_at(0)
		var lane := _free_lane()
		serves.append({"customer": head, "pack": pack, "left_ms": int(t["service_ms"]), "lane": lane})
		_emit("serve_started", {"customer": head["id"], "pack": pack["id"], "lane": lane})


## The oldest recipe in the bin with a whole pack's portions ("" = none): a
## pack is never filled from two recipes, and a lone leftover portion waits.
func packable_recipe() -> String:
	var seen := {}
	for lot: Dictionary in bin:
		var r := String(lot["recipe"])
		if seen.has(r):
			continue
		seen[r] = true
		if bin_portions_of(r) >= pack_size():
			return r
	return ""


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
	var ms := int(packer()["ms"])
	var pack := {"id": _new_id(), "recipe": pack_sku(recipe), "size": size, "quality": q_sum / size, "left_ms": ms, "ms": ms}
	packing.append(pack)
	_emit("pack_started", {"pack": pack["id"], "lots": used, "size": size, "head": packing.size() - 1, "ms": ms, "recipe": pack["recipe"]})


func _matching_pack(order: Dictionary) -> int:
	for i in shelf.size():
		var p: Dictionary = shelf[i]
		if String(p["recipe"]) == String(order["recipe"]) and int(p["size"]) == int(order["size"]):
			return i
	return -1


## The counter's lanes (data: factory.counter.lanes; Step 24's shop tree adds more).
func lanes() -> int:
	return maxi(maxi(1, int((_t().get("counter", {}) as Dictionary).get("lanes", 1))), int(shop_sign().get("lanes", 1)))


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
	var c := sign_cost()
	if c < 0:
		return {"ok": false, "reason": "err.max_level"}
	if money < c:
		return {"ok": false, "reason": "err.not_enough_money"}
	money -= c
	sign_tier += 1
	_emit("station_upgrade", {"station": "sign", "tier": sign_tier, "cost": c, "money": money})
	return {"ok": true, "tier": sign_tier, "cost": c}


## A fresh run from another seed (a measured session, ?seed=N): the same model,
## its arrivals drawn from that seed. Only before anything has happened.
func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
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
	var coins := pack_price(String(p["recipe"]), int(p["size"]), int(p["quality"]))
	if first_sale_ms < 0:
		first_sale_ms = flow_ms
	ledger.append({"t": flow_ms, "customer": c["id"], "pack": p["id"], "recipe": p["recipe"], "size": p["size"], "quality": p["quality"], "coins": coins})
	if ledger.size() > 500:
		ledger.pop_front()
	stats["sold"] = int(stats["sold"]) + 1
	stats["sold_portions"] = int(stats["sold_portions"]) + int(p["size"])
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
	var c := {"id": _new_id(), "order": {"recipe": "plain", "size": pack_size()}, "patience_ms": int(f["patience_ms"])}
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


func to_save() -> Dictionary:
	var d := {"rng_state": str(rng_state), "stats": stats.duplicate(true), "outcomes": outcomes.duplicate()}
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
	s["shelf_cap"] = int(_t()["shelf_packs"])
	s["queue"] = queue.size()
	s["queue_cap"] = queue_cap()
	s["sign_tier"] = sign_tier
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
	s["portions_everywhere"] = portions_everywhere()
	return s


## Which stage holds the line back right now (no spreadsheet: the view turns
## it into a picture, Step 23): 'kitchen' (the packer is starved), 'packing'
## (customers wait for packs), 'shop' (packs wait for customers), or '' (flowing).
func bottleneck() -> String:
	if not queue.is_empty() and shelf.is_empty() and serves.is_empty():
		return "kitchen" if packing.is_empty() and packable_recipe() == "" else "packing"
	if queue.is_empty() and shelf.size() >= int(_t()["shelf_packs"]):
		return "shop"
	if not glass.is_empty():
		return "shop" if shelf.size() >= int(_t()["shelf_packs"]) else "packing"
	return ""
