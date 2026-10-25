class_name PrestigeSystem
extends SimSystem

## Selling the settlement, and what stays when it is sold.
##
## The island is appraised from what it is -- the money paid for its farms,
## mines, lumberyards and labs (and their refits, by family), the land bought,
## what it earns a day, its Momo and their skills, the research done and the
## experience gained -- each a transparent line (balance.prestige.value).
## Selling it ends the island; a new one starts with a head start.
##
## Legacy points come from the island's net value over all sales: the total
## ever earned is floor(sqrt(lifetime / points_unit)), so each sale adds what
## its value lifts that total by -- the next point always costs more, and
## selling the same progress twice adds nothing. Net value is the appraisal
## minus the head start the island was given (seed): what a settlement is
## worth beyond what it was handed. That, and a minimum level, is what keeps
## buy-and-sell loops from paying.
##
## Points are permanent: more starting money, more starting Momo, Momo who
## work a little faster -- read from here by the systems that use them.
##
## Research is carried too (ResearchSystem.carry_over): every level researched
## this run becomes a research point for good, every unlocked node stays
## unlocked, and all levels start again at 0 -- the new island opens on the
## allocation screen (`welcome`) to place its points.

## Total legacy points earned (never spent here; special research may later).
var points := 0
## Net value of all sales so far.
var lifetime := 0
var sales := 0
## The highest single sale.
var best := 0
## Head start this island was given: not part of what it is worth.
var seed_money := 0
## [{n, value, points, rp, day}] past sales, newest last.
var history: Array = []
## A new island from a sale that has not shown its points yet.
var welcome := false


func _init() -> void:
	key = &"prestige"


func on_new_game() -> void:
	points = 0
	lifetime = 0
	sales = 0
	best = 0
	seed_money = 0
	history.clear()
	welcome = false


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["prestige.welcomed"])


func execute(command: Dictionary) -> Dictionary:
	if String(command.get("type", "")) == "prestige.welcomed":
		welcome = false
		return SimResult.ok()
	return SimResult.fail("err.unknown_command")


func _cfg(path: String, fallback: float) -> float:
	return sim.data.get_float("balance", "prestige." + path, fallback)


# --- appraisal -----------------------------------------------------------------------

## The island's value, line by line: {families {farm, mine, lumberyard,
## research}, buildings, land, productivity, momo, research, experience,
## gross, seed, net, points (gained by selling now), can_sell, reason, min_level}.
func appraise() -> Dictionary:
	var bs: BuildingSystem = sim.system(&"buildings")
	var families := {"farm": 0, "mine": 0, "lumberyard": 0, "research": 0, "special": 0}
	var share := _cfg("value.buildings", 0.6)
	for id: int in bs.ids():
		var b := bs.get_building(id)
		var fam := "special" if bs.is_special(String(b["type"])) else bs.family_of(String(b["type"]))
		families[fam] = int(families.get(fam, 0)) + int(floor(int(b.get("paid", {}).get("money", 0)) * share))
	var buildings := 0
	for f: String in families:
		buildings += int(families[f])
	var land := 0
	for p: Array in (sim.system(&"land") as LandSystem).purchases:
		land += int(p[2]) if p.size() > 2 else 0
	land = int(floor(land * _cfg("value.land", 0.8)))
	var productivity := int(floor(daily_income() * _cfg("value.income_days", 10.0)))
	var momos: MomoSystem = sim.system(&"momo")
	var momo := 0
	for id: int in momos.ids():
		var skill := 0
		for t: String in momos.get_momo(id).get("experience", {}):
			skill += momos.proficiency(id, t)
		momo += int(_cfg("value.momo_base", 30.0) + _cfg("value.momo_per_skill", 20.0) * skill)
	# Research: the money of the levels researched this run (points placed
	# from earlier runs were not paid for here and are not this island's worth).
	var research := 0
	var rs: ResearchSystem = sim.system(&"research")
	var g := sim.data.get_float("balance", "research.level_cost_growth", 1.8)
	for rid: String in rs.bought:
		var base := int(rs.node(rid).get("cost", {}).get("money", 0))
		var from := int(rs.allocated.get(rid, 0))
		for k in range(from, from + int(rs.bought[rid])):
			research += int(ceil(base * pow(g, k)))
	research = int(floor(research * _cfg("value.research", 0.5)))
	var experience := int(floor(total_exp() * _cfg("value.exp", 0.2)))
	var gross := buildings + land + productivity + momo + research + experience
	var net := maxi(gross - seed_money, 0)
	var prog: ProgressionSystem = sim.system(&"progression")
	var min_level := int(_cfg("min_level", 5.0))
	var reason := ""
	# A sale that adds no points is allowed -- it simply pays nothing.
	if prog.level < min_level:
		reason = "err.prestige_level"
	return {"families": families, "buildings": buildings, "land": land, "productivity": productivity, "momo": momo,
		"research": research, "experience": experience, "gross": gross, "seed": seed_money, "net": net,
		"points": new_points(net), "can_sell": reason == "", "reason": reason, "min_level": min_level,
		"rp_new": rs.rp_pending(), "rp_after": rs.rp_earned + rs.rp_pending()}


## Average money a day from sales and releases over the last closed days.
func daily_income() -> float:
	var book: AnalyticsSystem = sim.system(&"analytics")
	if book == null:
		return 0.0
	var ds := book.last(7)
	if ds.is_empty():
		return 0.0
	var inc := AnalyticsSystem.total(ds, "income")
	return float(int(inc.get("sale", 0)) + int(inc.get("release", 0))) / ds.size()


## All the experience this island gained (every level climbed plus the bar).
func total_exp() -> int:
	var prog: ProgressionSystem = sim.system(&"progression")
	var n := prog.experience
	for l in range(1, prog.level):
		n += prog.exp_needed_for(l)
	return n


func points_for(value: int) -> int:
	return int(floor(sqrt(float(maxi(value, 0)) / maxf(_cfg("points_unit", 100.0), 1.0))))


## Legacy points selling an island of `net` value would add now.
func new_points(net: int) -> int:
	return points_for(lifetime + net) - points_for(lifetime)


# --- what points give ------------------------------------------------------------------

func start_money_bonus(p: int = -1) -> int:
	return int(_cfg("rewards.money_per_point", 15.0) * (points if p < 0 else p))


func start_momo_bonus(p: int = -1) -> int:
	var every := maxi(int(_cfg("rewards.momo_every", 5.0)), 1)
	return mini((points if p < 0 else p) / every, int(_cfg("rewards.max_momos", 4.0)))


## Momo work time multiplier from legacy (<= 1).
func work_factor(p: int = -1) -> float:
	return 1.0 - minf(_cfg("rewards.work_per_point", 0.02) * (points if p < 0 else p), _cfg("rewards.work_cap", 0.3))


# --- selling ---------------------------------------------------------------------------

## Sells `old` and returns the new settlement: {ok, sim, appraisal, gained}
## or a failure. `old` itself is not changed -- the caller swaps worlds.
static func sell(old: Simulation) -> Dictionary:
	var me: PrestigeSystem = old.system(&"prestige")
	var a := me.appraise()
	if not a["can_sell"]:
		return SimResult.fail(String(a["reason"]), {"min_level": a["min_level"]})
	var gained := int(a["points"])
	var research := (old.system(&"research") as ResearchSystem).carry_over()
	var legacy := {"points": me.points + gained, "lifetime": me.lifetime + int(a["net"]), "sales": me.sales + 1,
		"best": maxi(me.best, int(a["net"])), "history": me.history.duplicate(true)}
	(legacy["history"] as Array).append({"n": me.sales + 1, "value": a["net"], "points": gained, "rp": research["issued"], "day": old.clock.day_number()})
	while (legacy["history"] as Array).size() > 20:
		(legacy["history"] as Array).pop_front()
	var next := Simulation.new_game(old.data)
	(next.system(&"research") as ResearchSystem).adopt(research)
	(next.system(&"prestige") as PrestigeSystem).adopt(legacy)
	next.bus.emit(&"settlement_sold", {"value": a["net"], "points": gained, "rp": research["issued"]})
	return SimResult.ok({"sim": next, "appraisal": a, "gained": gained, "rp_issued": research["issued"]})


## A new island takes over the legacy and its head start: money and Momo,
## both recorded as seed so they are not counted as this island's worth.
func adopt(legacy: Dictionary) -> void:
	points = int(legacy.get("points", 0))
	lifetime = int(legacy.get("lifetime", 0))
	sales = int(legacy.get("sales", 0))
	best = int(legacy.get("best", 0))
	history = (legacy.get("history", []) as Array).duplicate(true)
	var money := start_money_bonus()
	if money > 0:
		(sim.system(&"economy") as EconomySystem).earn(money, "legacy")
	var momos: MomoSystem = sim.system(&"momo")
	var extra := start_momo_bonus()
	var spots: Array[Vector2] = [Vector2(1.45, 1.4), Vector2(0.4, 1.5), Vector2(1.5, 0.45), Vector2(0.6, 0.6)]
	for i in extra:
		momos.add_momo(spots[i % spots.size()])
	seed_money = money + int(_cfg("value.momo_base", 30.0)) * extra
	welcome = true


func save_state() -> Dictionary:
	return {"points": points, "lifetime": lifetime, "sales": sales, "best": best, "seed_money": seed_money, "history": history.duplicate(true), "welcome": welcome}


func load_state(state: Dictionary) -> void:
	points = int(state.get("points", 0))
	lifetime = int(state.get("lifetime", 0))
	sales = int(state.get("sales", 0))
	best = int(state.get("best", 0))
	seed_money = int(state.get("seed_money", 0))
	welcome = bool(state.get("welcome", false))
	history.clear()
	for h: Dictionary in state.get("history", []):
		history.append({"n": int(h.get("n", 0)), "value": int(h.get("value", 0)), "points": int(h.get("points", 0)), "rp": int(h.get("rp", 0)), "day": int(h.get("day", 0))})
