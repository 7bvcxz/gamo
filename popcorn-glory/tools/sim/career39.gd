extends SceneTree
## Step 39: a whole career on the canonical model (variants/factory/factory_rules.gd) -- a fresh
## stand at minute 0 played to minute N by a simulated hand and a purchase policy that only
## uses what the game offers (the bottleneck chip, the build menu's prices and locks, the
## contests board, the news). SIMULATED TARGETS, NOT PLAYER ENJOYMENT.
##   godot --headless --path popcorn-glory --script res://tools/sim/career39.gd -- <out_dir> [minutes] [only] [seeds] [dump_min] [save_minutes]
## Step 48: save_minutes (e.g. 3,10,30) writes <out>/save_<hand>_<policy>_<seed>_<m>.json at those minutes -- the
## game's own save document (PopSaveDoc), so a browser can open the career's factory as it was then.
## Writes <out>/career.csv (one row a minute, every run), <out>/purchases.csv, <out>/career.json
## (milestones, segments, trap checks). Asserts conservation and the money identity every minute.
const Factory := preload("res://variants/factory/factory_rules.gd")
const FORTY_PLAN: Array = preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN   ## the unit test's 44-machine build order

## Hands (Step 25's, the same odds): how soon they press after the kettle frees (ms), grade odds.
## away: [ms at the kettle, ms looking away] -- a person does not press for an hour without a
## break (the skilled hand does; the idle hand presses once in thirty seconds all along).
const HANDS := {
	"skilled": {"react": 300, "odds": {"perfect": 0.85, "near": 0.12, "late": 0.03}},
	"average": {"react": 1000, "odds": {"perfect": 0.5, "near": 0.3, "late": 0.1, "early": 0.1}, "away": [180000, 60000]},
	"slow": {"react": 6000, "odds": {"perfect": 0.3, "near": 0.3, "late": 0.2, "early": 0.15, "burnt": 0.05}, "away": [120000, 120000]},
	"idle": {"react": 30000, "odds": {"perfect": 0.5, "near": 0.5}},   # mostly idle: one press in thirty seconds
}
## Devices whose effect is one for the whole shop (the rules ask `_device_on`): a second copy
## does nothing more (Step 39 refuses it; the bot never asks).
const ONE_IS_ENOUGH := ["M02", "M03", "M06", "M08", "M09", "M11", "M12", "M13", "M14", "M15", "P04", "P07", "S01", "S02", "S03", "S04", "S06", "U01", "U05", "U07"]
## The runs: [hand, policy]. Policies (what the player does with the money):
##  balanced   reads the bottleneck chip, buys the cheapest thing that answers it, opens a flavor
##             when it opens, enters contests it can play
##  early      the factory first: kettles and their helpers as soon as they open, the hand second
##  cautious   buys only for the bottleneck, only with twice the price in the wallet, no contests
##  specialist one flavor (caramel): every coater it builds coats caramel, news focus on it
##  variety    every flavor and every machine kind once, as they open
##  spikes     balanced, and a crowd of customers walks in every 6 minutes (bursts)
##  no_news    balanced with the paper off (the news baseline)
const RUNS := [
	["skilled", "balanced"], ["average", "balanced"], ["slow", "balanced"], ["idle", "balanced"],
	["average", "early"], ["average", "cautious"], ["average", "specialist"], ["average", "variety"],
	["average", "spikes"], ["average", "no_news"], ["idle", "early"],
]
const BUY_EVERY_MS := 2000
const DT := 250

## The order a reasonable player reaches for, per bottleneck (catalog ids; "sign", "packer",
## "kettle" the stations; "line:<floor>" a floor's next line).
const WANT := {
	"production": ["M07", "kettle", "M01", "M16", "M08", "M06", "M04", "M05", "M09", "M13", "M10", "M14", "M15", "M03", "M02", "U02", "U03", "U01"],
	"packaging": ["packer", "bagger", "P07", "P03", "U04", "P04", "P02", "P01", "P08", "U08", "U05"],
	"service": ["S03", "S01", "S05", "kiosk", "S02", "S04", "S07", "S08"],
	"demand": ["sign", "S06", "U07"],
}
const EARLY := ["M07", "M01", "M08", "M06", "M16", "M04", "M05", "M09", "bagger", "P07", "M13", "M10", "M14", "M15", "U02", "U03", "U01", "U04"]

var _rng := RandomNumberGenerator.new()
var dump_min := -1   ## [5th arg] print the factory's state at this minute (diagnosis)
var save_minutes: Array = []   ## [6th arg] Step 48: write the game's save at these minutes
var out_dir := "/tmp"


func _dump(f: PopRules, key: String, m: int) -> void:
	var bins := {}
	for l: Dictionary in f.bin:
		bins[String(l["recipe"])] = int(bins.get(String(l["recipe"]), 0)) + int(l["portions"])
	print("DUMP %s @%d: glass %s heating %s cooldown %d finishing %s bin %s (cap %s) shelf %d queue %d packing %d money %d bottleneck %s" % [key, m, f.glass, f.heating, f.cooldown_left, f.finishing, bins, f.state()["bin_cap"], f.shelf.size(), f.queue.size(), f.packing.size(), f.money, f.bottleneck()])
	for x: Dictionary in f.machines:
		print("   %s #%d %s slot %d state %s kernels %s held %s flavor %s" % [x["type"], x["id"], x["floor"], x["slot"], x["state"], x.get("kernels", "-"), (x["held"] as Dictionary).keys(), x.get("flavor", "")])
	print("   shelf: ", f.shelf.map(func(p: Dictionary) -> String: return "%s%d" % [p["recipe"], p["size"]]))
	print("   queue: ", f.queue.map(func(c: Dictionary) -> String: return "%s%d" % [c["order"]["recipe"], c["order"]["size"]]))


func _hold_for(f: PopRules, grade: String) -> int:
	var ws := int(f.window_start())
	var we := int(f.window_end())
	var near := int(f.near_ms())
	match grade:
		"perfect":
			return (ws + we) / 2
		"near":
			return we + near / 2 if _rng.randf() < 0.5 else ws - near / 2
		"early":
			return maxi(50, ws - near - 120)
		"late":
			return we + near + 60
	return int(f.burn_at()) + 20


func _grade(odds: Dictionary) -> String:
	var u := _rng.randf()
	var acc := 0.0
	for g: String in odds.keys():
		acc += float(odds[g])
		if u < acc:
			return g
	return "perfect"


func _runtime(f: PopRules, id: String) -> String:
	if f.forty().has(id):
		return String(f.forty()[id].get("runtime", id)) if f.forty()[id].get("runtime") != null else ""
	return id


## What a purchase costs right now (-1: not on offer -- locked, maxed, or no place and no line).
func _price(f: PopRules, what: String) -> int:
	match what:
		"sign":
			return f.sign_cost() if f.station_open("sign") else -1
		"packer":
			return f.packer_cost() if f.station_open("packer") else -1
		"kettle":
			return f.cost()
	if what.begins_with("line:"):
		var fl := what.substr(5)
		return f.line_cost(fl) if f.floor_full(fl) else -1
	if f.forty().has(what) and not f.catalog_buildable(what):
		return -1
	if ONE_IS_ENOUGH.has(what) and not f.of_type(what).is_empty():
		return -1
	var rt := _runtime(f, what)
	if rt == "" or not f.station_open(rt):
		return -1
	if rt == "U08" and not f.parallel_lines():
		return -1
	if Factory.COATERS.has(rt) and f._open_flavors_of(rt).is_empty():
		return -1
	var c := int(f.build_cost(rt))
	if c < 0:
		return -1
	var floor := String(Factory.FLOOR_OF[rt])
	if floor == "any":
		floor = _support_floor(rt)
	if f._free_slot(floor) < 0:
		var lc := int(f.line_cost(floor)) if f.floor_full(floor) else -1
		return c + lc if lc >= 0 else -1
	return c


func _support_floor(rt: String) -> String:
	return {"U04": "packing", "U05": "packing", "U08": "packing", "U07": "shop"}.get(rt, "kitchen")


func _do(f: PopRules, what: String, log: Array, t: int, run: Dictionary) -> bool:
	var m0 := int(f.money)
	var ok := false
	match what:
		"sign":
			ok = bool(f.execute({"type": "buy_sign"})["ok"])
		"packer":
			ok = bool(f.execute({"type": "buy_packer"})["ok"])
		"kettle":
			ok = bool(f.execute({"type": "buy"})["ok"])
		_:
			var rt := _runtime(f, what)
			var floor := String(Factory.FLOOR_OF[rt])
			if floor == "any":
				floor = _support_floor(rt)
			if f._free_slot(floor) < 0:
				if not bool(f.execute({"type": "buy_line", "floor": floor})["ok"]):
					return false
				log.append({"t": t, "what": "line:" + floor, "cost": m0 - int(f.money), "bottleneck": String(f.bottleneck()), "money_after": f.money})
				run["spent"] = int(run["spent"]) + m0 - int(f.money)
				m0 = int(f.money)
			var r: Dictionary = f.execute({"type": "build", "machine": what, "floor": floor})
			ok = bool(r["ok"])
			if ok and Factory.COATERS.has(rt):
				var fl := _coater_flavor(f, rt, String(run["policy"]))
				if fl != "":
					f.execute({"type": "set_flavor", "id": r["machine"], "flavor": fl})
	if ok:
		var c := m0 - int(f.money)
		run["spent"] = int(run["spent"]) + c
		log.append({"t": t, "what": what, "cost": c, "bottleneck": String(f.bottleneck()), "money_after": f.money})
	return ok


## The flavor a new coater coats: the specialist's caramel, otherwise an open flavor no coater
## serves yet (the cheapest-to-open first), else the most asked-for open one.
func _coater_flavor(f: PopRules, rt: String, policy: String) -> String:
	var open: Array = f._open_flavors_of(rt)
	if open.is_empty():
		return ""
	if policy == "specialist":
		return "caramel" if open.has("caramel") else ""
	for fl: String in open:
		if not f.machines.any(func(m: Dictionary) -> bool: return Factory.COATERS.has(String(m["type"])) and String(m.get("flavor", "")) == fl):
			return fl
	return String(open[0])


## Flavors the policy wants a coater for that none serves (in the menu's order).
func _flavor_wants(f: PopRules, policy: String) -> Array:
	var out: Array = []
	for fl: String in f.flavor_ids():
		if not f.is_flavor(fl) or not f.flavor_open(fl):
			continue
		if policy == "specialist" and fl != "caramel":
			continue
		if policy in ["balanced", "spikes", "no_news", "early"] and out.size() + _served_flavors(f).size() >= 2:
			break
		if policy == "cautious" and _served_flavors(f).size() >= 1:
			break
		if not _served_flavors(f).has(fl):
			out.append(fl)
	return out


func _served_flavors(f: PopRules) -> Array:
	var out: Array = []
	for m: Dictionary in f.machines:
		if Factory.COATERS.has(String(m["type"])) and not out.has(String(m.get("flavor", ""))):
			out.append(String(m.get("flavor", "")))
	return out


func _coater_for(f: PopRules, fl: String) -> String:
	return String(f.flavor(fl).get("machine", ""))


func _kettles(f: PopRules) -> int:
	return f.machines.filter(func(m: Dictionary) -> bool: return Factory.KETTLES.has(String(m["type"]))).size()


func _shop(f: PopRules, run: Dictionary, log: Array, t: int) -> void:
	var policy := String(run["policy"])
	var burn := float(f.upkeep_overview()["burn_per_min"])
	var factor := 2.0 if policy == "cautious" else 1.0
	var reserve := maxf(10.0, burn * (3.0 if policy == "cautious" else 1.5))
	var afford := func(what: String) -> bool:
		var p := _price(f, what)
		return p >= 0 and float(f.money) >= float(p) * factor + reserve
	# Kernels: a kettle with none and no hopper is refilled by hand from its card (5 coins).
	if f.of_type("M01").is_empty():
		for m: Dictionary in f.machines:
			if Factory.KETTLES.has(String(m["type"])) and int(m.get("kernels", 0)) <= 0 and int(f.money) >= int(f.refill_cost(m)) + 5:
				var m0 := int(f.money)
				if bool(f.execute({"type": "refill", "id": m["id"]})["ok"]):
					run["refills"] = int(run["refills"]) + 1
					run["refill_coins"] = int(run["refill_coins"]) + m0 - int(f.money)
	# A hopper for every four kettles once two run (the card says the kettles starve).
	var hop: int = f.of_type("M01").size()
	if _kettles(f) >= 2 and hop * 4 < _kettles(f) and afford.call("M01"):
		_do(f, "M01", log, t, run)
		return
	# A new flavor the policy wants: its coater.
	for fl: String in _flavor_wants(f, policy):
		var c := _coater_for(f, fl)
		if c != "" and afford.call(c):
			_do(f, c, log, t, run)
			return
		# saving for the new flavor (within five minutes of what the shop nets): nothing else first
		var p := _price(f, c) if c != "" else -1
		if p >= 0 and float(p) * factor + reserve <= float(f.money) + 5.0 * maxf(1.0, float(f.upkeep_overview()["net_per_min"])):
			return
	# The specialist adds caramel coaters while caramel is what customers wait for.
	if policy == "specialist" and _served_flavors(f).has("caramel") and f.of_type("P06").size() < 3 and int(f.stats.get("asked_recipe", {}).get("caramel", 0)) > 20 * f.of_type("P06").size() and afford.call("P06"):
		_do(f, "P06", log, t, run)
		return
	if policy == "early":
		for what: String in EARLY:
			if (what != "M07" or _kettles(f) < 10) and afford.call(what) and (what in ["M07", "M01", "bagger"] or f.of_type(_runtime(f, what)).is_empty()):
				_do(f, what, log, t, run)
				return
	var bn := String(f.bottleneck())
	if bn != "":
		var list: Array = WANT.get(bn, [])
		# The first three that are on offer: buy the first affordable; otherwise save for them.
		if bn == "demand" and policy != "cautious":
			# a flavor the player wants that the station's tier still locks: the station is the goal
			for fl: String in f.flavor_ids():
				if f.is_flavor(fl) and not f.flavor_open(fl) and (policy != "specialist" or fl == "caramel") and f.sign_tier >= int((f.flavor(fl).get("unlock", {}) as Dictionary).get("sign", 0)):
					list = ["packer"] + list
					break
		var seen := 0
		var near := false
		var net := maxf(1.0, float(f.upkeep_overview()["net_per_min"]))
		for what: String in list:
			var p := _price(f, what)
			if p < 0:
				continue
			if what == "M07" and _kettles(f) >= 24:
				continue
			seen += 1
			if afford.call(what):
				_do(f, what, log, t, run)
				return
			if float(p) * factor + reserve <= float(f.money) + 2.0 * net:
				near = true   # saving for it: two minutes away
			if seen >= 3:
				break
		if near or policy == "cautious":
			return
	if policy == "cautious":
		return
	# Nothing holds the line back: a new kind of machine (a new picture), cheapest first --
	# the variety player buys every kind; the others one in three minutes at most.
	if policy != "variety" and t - int(run["last_new"]) < 180000:
		return
	var best := ""
	var bp := 1 << 30
	for id: String in _kinds(f):
		if not f.of_type(_runtime(f, id)).is_empty() or id in ["U07", "U08"] and policy != "variety":
			continue
		var p := _price(f, id)
		if p >= 0 and p < bp:
			best = id
			bp = p
	if best != "" and afford.call(best) and float(bp) <= float(f.money) * 0.6:
		if _do(f, best, log, t, run):
			run["last_new"] = t


func _kinds(f: PopRules) -> Array:
	var out: Array = ["bagger", "kiosk"]
	for id: String in f.forty().keys():
		if not id.begins_with("_") and id != "M07":
			out.append(id)
	return out


## Contests the bot can play: the posted ones whose needs it meets, the fee a small part of the
## wallet, and a kind its hand or line can do (no cheating: it plays like before).
func _contests(f: PopRules, run: Dictionary, hand: String) -> void:
	var policy := String(run["policy"])
	if policy == "cautious" or f.contest_rules().is_empty() or not bool(f.contests["open"]) or not (f.contests["entry"] as Dictionary).is_empty():
		return
	for p: Dictionary in f.contests["posted"]:
		var id := String(p["id"])
		var fm: Dictionary = f.contest_format(id)
		var kind := String(fm.get("kind", ""))
		if kind == "streak" and hand not in ["skilled", "average"]:
			continue
		if kind == "best_batch" and not _served_flavors(f).has(String(fm.get("flavor", ""))):
			continue
		if f.contest_problem(id) != "" or float(fm.get("fee", 0)) > float(f.money) * 0.1:
			continue
		if bool(f.execute({"type": "contest_enter", "id": id})["ok"]):
			run["contests_entered"] = int(run["contests_entered"]) + 1
			return


func _running(f: PopRules) -> int:
	return f.machines.filter(func(m: Dictionary) -> bool: return String(m["state"]) == "run").size()


func _floor_count(f: PopRules, fl: String) -> int:
	return f.machines.filter(func(m: Dictionary) -> bool: return String(m["floor"]) == fl).size()


func _mark(ms: Dictionary, key: String, t: int) -> void:
	if not ms.has(key):
		ms[key] = snappedf(float(t) / 60000.0, 0.01)


func _milestones(f: PopRules, ms: Dictionary, t: int, run: Dictionary) -> void:
	if int(f.stats["sold"]) >= 1:
		_mark(ms, "first_sale", t)
	for m: Dictionary in f.machines:
		var ty := String(m["type"])
		if ty in ["bagger", "P03", "P01"] and int(m.get("done", 0)) > 0:
			_mark(ms, "first_packing_line", t)
		if Factory.KETTLES.has(ty) and int(m.get("done", 0)) > 0:
			_mark(ms, "first_auto_cooker", t)
	if _floor_count(f, "kitchen") >= 3 and _floor_count(f, "packing") >= 3 and _floor_count(f, "shop") >= 3:
		_mark(ms, "three_floors", t)
	for a: Dictionary in (f.news.get("active", []) as Array):
		if String(f.news_channel(String(a["id"]))) == "arrivals":
			_mark(ms, "first_crowd_rush", t)
	if f.queue.size() >= 6:
		_mark(ms, "first_full_queue", t)
	for fl: String in (f.stats.get("flavor_sold", {}) as Dictionary).keys():
		if f.is_flavor(fl) and int(f.stats["flavor_sold"][fl]) > 0:
			_mark(ms, "first_flavor_line", t)
	for r: Dictionary in (f.contests.get("results", []) as Array):
		if int(r.get("tier", 0)) >= 1:
			_mark(ms, "first_contest_win", t)
	var n := _running(f)
	run["peak_running"] = maxi(int(run["peak_running"]), n)
	for k in [10, 20, 40]:
		if f.machines.size() >= k:
			_mark(ms, "built_%d" % k, t)
		if n >= k:
			_mark(ms, "running_%d" % k, t)


## The cheapest thing on offer anywhere (the dead-zone measure: nothing to buy within reach).
func _cheapest(f: PopRules) -> int:
	var best := 1 << 30
	for what: String in ["sign", "packer", "kettle"] + _kinds(f) + ["M07"]:
		var p := _price(f, what)
		if p >= 0:
			best = mini(best, p)
	return best


func _run(hand: String, policy: String, minutes: int, seed_value: int, rows: Array, buys: Array) -> Dictionary:
	_rng.seed = seed_value
	var f: PopRules = Factory.new(null, seed_value)
	if policy == "no_news":
		f.economy.table("factory")["news"] = {}
	var h: Dictionary = HANDS[hand]
	var key := "%s/%s/%d" % [hand, policy, seed_value]
	var run := {"policy": policy, "spent": 0, "refills": 0, "refill_coins": 0, "contests_entered": 0, "last_new": -1000000, "peak_running": 0}
	var log: Array = []
	var ms := {}
	var t := 0
	var free_since := 0
	var next_buy := 0
	var presses := 0
	var last := {"rev": 0, "upk": 0, "inp": 0, "made": 0, "packed": 0, "sold": 0, "lost": 0, "left": 0, "presses": 0, "prize": 0, "fee": 0, "asked_fl": 0, "sold_fl": 0}
	var money0 := int(f.money)
	var dead_ms := 0
	var dead_run := 0
	var dead_max := 0
	var no_buy_max := 0
	var last_buy_t := 0
	var bursts := 0
	while t < minutes * 60000:
		var free: bool = f.glass.is_empty() and int(f.cooldown_left) <= 0 and not bool(f.heating) and f.finishing.is_empty()
		if h.has("away") and t % (int(h["away"][0]) + int(h["away"][1])) >= int(h["away"][0]):
			free = false   # looking away
		if not free:
			free_since = t
		elif t - free_since >= int(h["react"]):
			if bool(f.execute({"type": "press"})["ok"]):
				presses += 1
				var hold := _hold_for(f, _grade(h["odds"]))
				f.advance(hold)
				t += hold
				f.execute({"type": "release"})
			free_since = t
		f.advance(DT)
		t += DT
		f.drain_events()
		if policy == "spikes" and t % 360000 < DT and t > 60000:
			bursts += 1
			for k in 10:
				if f.queue.size() < int(f.queue_cap()):
					f.queue.append({"id": f._new_id(), "order": {"recipe": "plain", "size": 2}, "patience_ms": 60000})
					f.stats["visitors"] = int(f.stats["visitors"]) + 1
					f.stats["arrived"] = int(f.stats["arrived"]) + 1
		if t >= next_buy:
			next_buy = t + BUY_EVERY_MS
			var n0 := log.size()
			_shop(f, run, log, t)
			_contests(f, run, hand)
			if policy == "specialist":
				for fl: String in f._news_flavors():
					if fl == "caramel" and f.news_focus == "":
						f.execute({"type": "news_focus", "flavor": fl})
			if log.size() > n0:
				no_buy_max = maxi(no_buy_max, t - last_buy_t)
				last_buy_t = t
			_milestones(f, ms, t, run)
			# Dead zone: nothing on offer costs less than three minutes of what the shop now nets
			# (or the wallet) -- the player has nothing to look forward to.
			var c := _cheapest(f)
			var reach := float(f.money) + 3.0 * maxf(1.0, float(f.upkeep_overview()["net_per_min"]))
			if float(c) > reach:
				dead_ms += BUY_EVERY_MS
				dead_run += BUY_EVERY_MS
				dead_max = maxi(dead_max, dead_run)
			else:
				dead_run = 0
		if t / 60000 > rows.filter(func(r: Dictionary) -> bool: return r["run"] == key).size():
			var m := t / 60000
			if dump_min > 0 and m == dump_min:
				_dump(f, key, m)
			if m in save_minutes:
				var doc := PopSaveDoc.encode("factory", String(ProjectSettings.get_setting("application/config/version")), t, int(Time.get_unix_time_from_system()), f.call("to_save"))
				var fs := FileAccess.open("%s/save_%s_%d.json" % [out_dir, key.replace("/", "_"), m], FileAccess.WRITE)
				fs.store_string(doc)
				fs.close()
			var rev := int(f.stats["revenue"])
			var upk := int(f.stats["upkeep_paid"])
			var inp := int(f.stats.get("kernels_paid", 0)) + int(f.stats.get("oil_paid", 0)) + int(f.stats.get("ingredient_coins", 0))
			var prize := int(f.stats.get("contest_prizes", 0))
			var fee := int(f.stats.get("contest_fees", 0))
			assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "portions %s" % key)
			assert(int(f.money) == money0 + int(f.book()) + prize - fee - int(run["spent"]), "money identity %s at %d: %d vs %d" % [key, m, f.money, money0 + int(f.book()) + prize - fee - int(run["spent"])])
			assert(int(f.money) >= 0, "never negative %s" % key)
			var lost := int(f.stats["abandoned"]) + int(f.stats["passed_by"])
			var asked: Dictionary = f.stats.get("asked_recipe", {})
			var fls: Dictionary = f.stats.get("flavor_sold", {})
			var asked_fl := 0
			var sold_fl := 0
			for fl: String in asked.keys():
				if f.is_flavor(fl):
					asked_fl += int(asked[fl])
			for fl: String in fls.keys():
				if f.is_flavor(fl):
					sold_fl += int(fls[fl])
			var ov: Dictionary = f.upkeep_overview()
			rows.append({"run": key, "hand": hand, "policy": policy, "seed": seed_value, "min": m, "money": f.money,
				"revenue_pm": rev - int(last["rev"]), "upkeep_pm": upk - int(last["upk"]), "inputs_pm": inp - int(last["inp"]),
				"net_pm": (rev - int(last["rev"])) - (upk - int(last["upk"])) - (inp - int(last["inp"])),
				"contest_pm": (prize - int(last["prize"])) - (fee - int(last["fee"])),
				"made_pm": int(f.stats["made_portions"]) - int(last["made"]), "packed_pm": int(f.stats["packed"]) - int(last["packed"]),
				"sold_pm": int(f.stats["sold"]) - int(last["sold"]), "lost_pm": lost - int(last["lost"]), "left_pm": int(f.stats["abandoned"]) - int(last["left"]),
				"flavor_asked_pm": asked_fl - int(last["asked_fl"]), "flavor_sold_pm": sold_fl - int(last["sold_fl"]),
				"bin": f.bin_portions(), "shelf": f.shelf.size(), "queue": f.queue.size(),
				"machines": f.machines.size(), "running": _running(f), "kitchen": _floor_count(f, "kitchen"), "packing": _floor_count(f, "packing"), "shop": _floor_count(f, "shop"),
				"sign": f.sign_tier, "station": f.packer_tier, "kettle": f.level, "burn_pm": ov["burn_per_min"], "unpaid_ms": f.stats["auto_unpaid_ms"],
				"blocked_ms": f.stats["auto_blocked_ms"], "bottleneck": f.bottleneck(), "presses_pm": presses - int(last["presses"]), "purchases": log.size(),
				"popularity": snappedf(float(f.popularity), 0.1)})
			last = {"rev": rev, "upk": upk, "inp": inp, "made": f.stats["made_portions"], "packed": f.stats["packed"], "sold": f.stats["sold"], "lost": lost,
				"left": f.stats["abandoned"], "presses": presses, "prize": prize, "fee": fee, "asked_fl": asked_fl, "sold_fl": sold_fl}
	for b: Dictionary in log:
		var row := b.duplicate()
		row["run"] = key
		buys.append(row)
	var results: Array = f.contests.get("results", [])
	return {"milestones": ms, "money": f.money, "book": f.book(), "spent": run["spent"], "machines": f.machines.size(), "peak_running": run["peak_running"],
		"kinds": _kinds(f).filter(func(id: String) -> bool: return not f.of_type(_runtime(f, id)).is_empty()).size(),
		"sign": f.sign_tier, "station": f.packer_tier, "kettle": f.level, "lines": f.floor_lines.duplicate(), "presses": presses,
		"refills": run["refills"], "refill_coins": run["refill_coins"], "contests_entered": run["contests_entered"],
		"contest_results": results.map(func(r: Dictionary) -> Dictionary: return {"id": r["id"], "tier": r.get("tier", 0), "prize": r.get("prize", 0), "fee": r.get("fee", 0)}),
		"prizes": int(f.stats.get("contest_prizes", 0)), "fees": int(f.stats.get("contest_fees", 0)),
		"dead_min": snappedf(float(dead_ms) / 60000.0, 0.1), "dead_longest_min": snappedf(float(dead_max) / 60000.0, 0.1), "no_buy_longest_min": snappedf(float(maxi(no_buy_max, t - last_buy_t)) / 60000.0, 0.1),
		"flavor_sold": f.stats.get("flavor_sold", {}), "asked_recipe": f.stats.get("asked_recipe", {}), "flavor_revenue": f.stats.get("flavor_revenue", {}),
		"sold": f.stats["sold"], "abandoned": f.stats["abandoned"], "passed_by": f.stats["passed_by"], "unpaid_ms": f.stats["auto_unpaid_ms"], "bursts": bursts,
		"news_started": int(f.stats.get("news_started", 0)), "popularity": snappedf(float(f.popularity), 0.1), "max_money": 0}


## The forty-machine factory (Step 33's plan) for an hour at a sign tier, a hand popping now
## and then: does the shop bring work for its machines? Conservation and the money identity
## every minute.
func _forty(sign: int, minutes: int, seed_value: int) -> Dictionary:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = sign
	f.packer_tier = 3
	f.level = 6
	f.stats["sold"] = 1
	f.stats["packed"] = 1
	f.money = 1 << 30
	for row: Array in FORTY_PLAN:
		var floor := String(row[1])
		if f.floor_full(floor) and int(f.line_cost(floor)) >= 0:
			f.execute({"type": "buy_line", "floor": floor})
		f.execute({"type": "build", "machine": row[0], "floor": floor})
	assert(f.machines.size() >= 40, "forty built (%d)" % f.machines.size())
	f.money = 2000
	f.stats["sold"] = 0
	var money0 := int(f.money)
	var b0 := int(f.book())
	var p0 := int(f.stats.get("contest_prizes", 0)) - int(f.stats.get("contest_fees", 0))
	var run_sum := 0
	var samples := 0
	var max_money := 0
	var worked := {}
	for i in minutes * 40:
		if i % 3 == 0 and f.glass.is_empty() and int(f.cooldown_left) <= 0 and not f.heating:
			f.execute({"type": "press"})
		f.advance(1500)
		if f.heating:
			f.execute({"type": "release"})
		f.drain_events()
		run_sum += _running(f)
		samples += 1
		for m: Dictionary in f.machines:
			if String(m["state"]) == "run":
				worked[m["id"]] = true
		max_money = maxi(max_money, int(f.money))
		if i % 40 == 39:
			assert(int(f.portions_everywhere()) == int(f.stats["made_portions"]), "forty portions")
			assert(int(f.money) == money0 + int(f.book()) - b0 + int(f.stats.get("contest_prizes", 0)) - int(f.stats.get("contest_fees", 0)) - p0, "forty money")
			assert(int(f.money) >= 0, "forty never negative")
	var mins := float(f.flow_ms) / 60000.0
	return {"sign": sign, "machines": f.machines.size(), "avg_running": snappedf(float(run_sum) / float(samples), 0.1), "ever_worked": worked.size(),
		"sold_pm": snappedf(float(f.stats["sold"]) / mins, 0.1), "net_pm": snappedf(float(int(f.book()) - b0) / mins, 0.1), "lost": int(f.stats["abandoned"]) + int(f.stats["passed_by"]),
		"upkeep_pm": snappedf(float(f.stats["upkeep_paid"]) / mins, 0.1), "max_money": max_money, "money_end": f.money, "queue_end": f.queue.size()}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var minutes := int(args[1]) if args.size() > 1 else 60
	var only := args[2] if args.size() > 2 else ""
	var seeds: Array = [3901]
	if args.size() > 3:
		seeds = Array(String(args[3]).split(",")).map(func(s: String) -> int: return int(s))
	if args.size() > 4:
		dump_min = int(args[4])
	if args.size() > 5:
		save_minutes = Array(String(args[5]).split(",")).map(func(s: String) -> int: return int(s))
	out_dir = out
	var md5_0 := FileAccess.get_md5("res://data/economy.json")
	var rows: Array = []
	var buys: Array = []
	var res := {"economy_md5": md5_0, "_doc": "AUTOMATIC SIMULATION on the game's own rules (tools/sim/career39.gd) -- simulated hands and purchase policies, not players and not fun.", "minutes": minutes, "runs": {}}
	for seed_value: int in seeds:
		for r: Array in RUNS:
			var name := "%s/%s" % [r[0], r[1]]
			if only != "" and not name in only.split(","):
				continue
			var t0 := Time.get_ticks_msec()
			var key := "%s/%d" % [name, seed_value]
			res["runs"][key] = _run(r[0], r[1], minutes, seed_value, rows, buys)
			var s: Dictionary = res["runs"][key]
			print("%s: book %d, spent %d, machines %d (running peak %d), kinds %d, sign %d station %d kettle %d, dead %.1f min (longest %.1f), no buy %.1f, contests %d (prizes %d fees %d)  [%d ms]" % [key, s["book"], s["spent"], s["machines"], s["peak_running"], s["kinds"], s["sign"], s["station"], s["kettle"], s["dead_min"], s["dead_longest_min"], s["no_buy_longest_min"], s["contests_entered"], s["prizes"], s["fees"], Time.get_ticks_msec() - t0])
			print("   milestones ", s["milestones"])
	if only == "" or only == "forty":
		res["forty"] = {}
		for sign in [6, 8]:
			var t0 := Time.get_ticks_msec()
			res["forty"][str(sign)] = _forty(sign, minutes if minutes <= 60 else 60, 3940)
			print("forty sign %d: %s  [%d ms]" % [sign, res["forty"][str(sign)], Time.get_ticks_msec() - t0])
	# Every run read the same data (each factory loads economy.json when it is made).
	assert(FileAccess.get_md5("res://data/economy.json") == md5_0, "economy.json changed while the sim ran -- the runs are mixed; run again")
	var fc := FileAccess.open(out + "/career.csv", FileAccess.WRITE)
	if not rows.is_empty():
		var cols: Array = (rows[0] as Dictionary).keys()
		fc.store_line(",".join(cols))
		for row: Dictionary in rows:
			fc.store_line(",".join(cols.map(func(c: String) -> String: return str(row[c]))))
	fc.close()
	var fp := FileAccess.open(out + "/purchases.csv", FileAccess.WRITE)
	fp.store_line("run,t_s,what,cost,bottleneck,money_after")
	for b: Dictionary in buys:
		fp.store_line("%s,%d,%s,%d,%s,%d" % [b["run"], int(b["t"]) / 1000, b["what"], b["cost"], b["bottleneck"], b["money_after"]])
	fp.close()
	var fj := FileAccess.open(out + "/career.json", FileAccess.WRITE)
	fj.store_string(JSON.stringify(res, " "))
	fj.close()
	quit(0)
