extends RefCounted

## A playtester that plays Momonium's whole loop the way an attentive person
## would, through the same commands the screen sends -- never by writing into
## the world: one action a second at most (a tap and a look), the farm worked
## by hand first, then more farms, a lab and a lumberyard as levels open them,
## land when the island is full, Momo hired and given tiles to watch, research
## started and Momo letters accepted, the settlement promoted, and the island
## sold when it pays legacy points -- after which the stronger second island
## is played the same way.
##
## It keeps the clock three ways: `active_ms` (the game open and played),
## `offline_ms` (time away the island caught up on), and wall time (both,
## plus away time a catch-up did not count). Every visible reward the player
## would see is logged with its active time; firsts are milestones.
##
## Used by tools/playtest/run.gd (the report) and tests/unit/sim/test_balance.gd
## (the targets as tests).

## A decision every this many simulated milliseconds while playing.
const STEP_MS := 1000
## What a person sees as "something happened" (feedback): a reward, or a
## stage done -- the crop grows a step, a Momo sparkles.
const FEEDBACK := [&"exp_gained", &"sold", &"level_up", &"building_built", &"land_bought", &"momo_hired",
	&"research_completed", &"letter_written", &"tier_promoted", &"mastery_up", &"momo_skilled", &"settlement_sold", &"released",
	&"task_completed"]

var sim: Simulation
var island := 1
var active_ms := 0
var offline_ms := 0
var away_ms := 0
var actions := 0
## [{"active_ms", "island", "kind", "detail"}] -- every feedback event.
var events: Array[Dictionary] = []
## key -> {"active_ms", "wall_ms", "offline_ms", "island"} -- the first time.
var milestones: Dictionary = {}
## Actions by kind, and refused commands (a dead end shows as many of these).
var counts: Dictionary = {}
## Seconds of play with nothing the bot could do and nothing working.
var stuck_seconds := 0
var longest_stuck := 0
var _stuck := 0
## Sim time the current second of play began at (events inside it are dated
## exactly), or -1 between steps.
var _step_from := -1
## When the island was sold: [{"island", "active_ms", "points", "level"}].
var sales: Array[Dictionary] = []
## Sell once this many legacy points are on offer (and the level allows it).
var sell_at_points := 2

## How this player plays (Step 50, tools/balance_optimizer/): "human" -- the
## attentive person above, a decision a second, hands first; "blind" -- a
## first-time player taking about ten seconds a decision, as the blind AI
## playtests of Step 45 did (their taps came 9-11 s apart), who follows the
## tutorial's ring, then reacts to what the screen offers (a badge, a new
## building, an affordable hire or tile) and taps by hand what is left, and
## now and then spends a decision just looking around.
var profile := "human"
## Milliseconds between decisions.
var step_ms := STEP_MS
## No decision before this much play (the first look at the screen).
var first_ms := 0
## Every this many decisions one goes on looking around (0: never).
var explore_every := 0
## Sensitivity switches: "no_land", "no_hire", "no_research", "no_letters",
## "hands_only" (never puts a Momo to work) -- each true to leave that out.
var strategy := {}
## Stages the tutorial has the player do by hand before it turns to the Momo.
var tutorial_taps := 3
## A sample after every decision: {"t" (active ms), "island", "money",
## "income" (production money this island: sales and releases), "income_all"
## (every island), "level", "land", "buildings", "momos", "research",
## "jobs" {hand, momo, auto}}.
var series: Array[Dictionary] = []
## Stages finished, by whom: "hand" (the player), "momo", "auto" (a drip line).
var jobs := {"hand": 0, "momo": 0, "auto": 0}
var _income_before := 0
var _decisions := 0
var _tutorial_ui := 0


func _init(p_sim: Simulation = null) -> void:
	attach(p_sim if p_sim != null else Simulation.new_game())


func attach(p_sim: Simulation) -> void:
	sim = p_sim
	sim.bus.emitted.connect(_on_event)
	# Swapped mid-step (a sale): the new island's clock starts here.
	if _step_from >= 0:
		_step_from = sim.now_ms()


func wall_ms() -> int:
	return _now() + away_ms


## Active time now, to the millisecond (inside a step too).
func _now() -> int:
	return active_ms + (sim.now_ms() - _step_from if _step_from >= 0 else 0)


# --- time ----------------------------------------------------------------------------

## Plays for `seconds` with the game open.
func play(seconds: float) -> void:
	var end := active_ms + int(seconds * 1000.0)
	while active_ms < end:
		var step := mini(step_ms, end - active_ms)
		_step_from = sim.now_ms()
		var acted := false
		if active_ms >= first_ms:
			_decisions += 1
			acted = false if explore_every > 0 and _decisions % explore_every == 0 else act()
		sim.advance_ms(step)
		active_ms += step
		_step_from = -1
		_sample()
		if acted:
			_stuck = 0
		elif _nothing_working():
			_stuck += step / 1000
			stuck_seconds += step / 1000
			longest_stuck = maxi(longest_stuck, _stuck)


## Production money so far on this island: crops and goods sold, releases.
func production_income() -> int:
	var lt: Dictionary = (sim.system(&"economy") as EconomySystem).lifetime
	return int(lt.get("sale", 0)) + int(lt.get("release", 0))


func _sample() -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	var rs: ResearchSystem = sim.system(&"research")
	var done := 0
	for id: String in rs.bought:
		done += int(rs.bought[id])
	series.append({"t": active_ms, "island": island, "money": (sim.system(&"economy") as EconomySystem).money,
		"income": production_income(), "income_all": _income_before + production_income(), "level": prog.level,
		"exp": prog.experience, "land": (sim.system(&"land") as LandSystem).purchases.size(),
		"buildings": (sim.system(&"buildings") as BuildingSystem).ids().size(), "momos": (sim.system(&"momo") as MomoSystem).ids().size(),
		"research": done, "jobs": jobs.duplicate()})


## Closes the game for `seconds`: the island catches up as it does on return.
func away(seconds: float) -> Dictionary:
	var ms := int(seconds * 1000.0)
	var rep := OfflineProgress.catch_up(sim, ms)
	away_ms += ms
	offline_ms += int(rep["counted_ms"])
	return rep


# --- the player --------------------------------------------------------------------------

## One decision; true when it did something.
func act() -> bool:
	if profile == "blind":
		return _act_blind()
	# Early the hands do the work; once a Momo has been hired the player
	# manages first and taps what is left.
	var managing := int((sim.system(&"momo") as MomoSystem).hired) > 0
	var order: Array[Callable] = [_claim_letter, _promote, _sell, _work_by_hand, _research, _special, _refit, _hire, _give_tiles, _build, _buy_land]
	if managing:
		order = [_claim_letter, _promote, _sell, _research, _special, _refit, _hire, _give_tiles, _build, _buy_land, _work_by_hand]
	for try: Callable in order:
		if bool(try.call()):
			actions += 1
			return true
	return false


## The blind-like player: the tutorial's ring first, then whatever the screen
## offers (a letter's badge, research, a hire it can afford, a new kind of
## building, a free tile, the sea when the island is full), then the hands.
## A decision spent on the screen only (opening a panel, the pencil) is a
## decision all the same.
func _act_blind() -> bool:
	var t := _tutorial()
	if t >= 0:
		return t > 0
	if _pending_assign != 0:
		return _assign_new()
	var order: Array[Callable] = []
	if not strategy.get("no_letters", false):
		order.append(_claim_letter)
	if not strategy.get("no_research", false):
		order.append(_research)
	order.append_array([_promote, _sell])
	if not strategy.get("no_hire", false) and not strategy.get("hands_only", false):
		order.append(_hire_blind)
	order.append_array([_build_blind])
	if not strategy.get("no_land", false):
		order.append(_buy_land)
	order.append_array([_special, _work_by_hand])
	for try: Callable in order:
		if bool(try.call()):
			actions += 1
			return true
	return false


## -1 when the tutorial is over; 1 when a decision went on it; 0 when it
## waits (the farm building, a stage running).
func _tutorial() -> int:
	if _tutorial_over:
		return -1
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := 0
	for id: int in bs.ids():
		if String(bs.get_building(id)["type"]) == "farm":
			farm = id
			break
	if farm == 0:
		if _tutorial_ui == 0:
			_tutorial_ui = 1
			counts["look: tile"] = int(counts.get("look: tile", 0)) + 1
			return 1
		_tutorial_ui = 0
		var free := (sim.system(&"world") as WorldSystem).buildable_cells()
		return 1 if not free.is_empty() and _do("build farm", {"type": "building.place", "building": "farm", "anchor": [free[0].x, free[0].y]}) else 0
	var b := bs.get_building(farm)
	if int(b["completed"]) < tutorial_taps:
		if b["state"] == BuildingSystem.IDLE and bs.can_start(farm)["ok"]:
			return 1 if _do("tap", {"type": "building.tap", "id": farm}) else 0
		return 0
	var momos: MomoSystem = sim.system(&"momo")
	if not strategy.get("hands_only", false) and not momos.ids().is_empty() and momos.watched(momos.ids()[0]).is_empty():
		if _tutorial_ui < 2:
			_tutorial_ui += 1
			counts["look: momo"] = int(counts.get("look: momo", 0)) + 1
			return 1
		_tutorial_ui = 0
		var c: Vector2i = bs.cells_of(b)[0]
		_do("give tiles", {"type": "momo.watch", "momo": momos.ids()[0], "cells": [[c.x, c.y]], "op": "add"})
		return 1
	_tutorial_over = true
	return -1


var _tutorial_over := false
## A Momo just hired that watches nothing yet: select it, the pencil, tiles.
var _pending_assign := 0


func _hire_blind() -> bool:
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	var economy: EconomySystem = sim.system(&"economy")
	if momos.ids().size() * 2 >= bs.ids().size() or not economy.can_afford(momos.hire_cost()):
		return false
	if not _do("hire Momo", {"type": "momo.hire"}):
		return false
	var id: int = momos.ids()[-1]
	if momos.watched(id).is_empty():
		_pending_assign = id
		_tutorial_ui = 0
	return true


func _assign_new() -> bool:
	var momos: MomoSystem = sim.system(&"momo")
	if not momos.ids().has(_pending_assign) or not momos.watched(_pending_assign).is_empty():
		_pending_assign = 0
		return false
	if _tutorial_ui < 2:
		_tutorial_ui += 1
		counts["look: momo"] = int(counts.get("look: momo", 0)) + 1
		return true
	_tutorial_ui = 0
	var m := _pending_assign
	_pending_assign = 0
	var bs: BuildingSystem = sim.system(&"buildings")
	var here := momos.position_of(m)
	var free: Array = []
	for id: int in bs.ids():
		if momos.watchers_of(id).is_empty() and momos.slots_of(id) > 0:
			free.append(id)
	free.sort_custom(func(a: int, b: int) -> bool: return here.distance_to(momos.work_spot(a)) < here.distance_to(momos.work_spot(b)) or (here.distance_to(momos.work_spot(a)) == here.distance_to(momos.work_spot(b)) and a < b))
	var cells: Array = []
	for id: int in free:
		for c: Vector2i in bs.cells_of(bs.get_building(id)):
			if cells.size() < momos.watch_capacity(m):
				cells.append([c.x, c.y])
	return not cells.is_empty() and _do("give tiles", {"type": "momo.watch", "momo": m, "cells": cells, "op": "add"})


## A kind of building the player has not got yet (the lab, then the
## lumberyard, then the mine) as soon as it is open and affordable; otherwise
## a farm on a free tile.
func _build_blind() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var free := (sim.system(&"world") as WorldSystem).buildable_cells()
	if free.is_empty():
		return false
	var have := {}
	for id: int in bs.ids():
		var fam := bs.family_of(String(bs.get_building(id)["type"]))
		have[fam] = int(have.get(fam, 0)) + 1
	for fam: String in ["research", "lumberyard", "mine"]:
		if not have.has(fam) and bs.is_unlocked(fam):
			if _affords(fam):
				return _do("build " + fam, {"type": "building.place", "building": fam, "anchor": [free[0].x, free[0].y]})
			# Saving for it: a farm only on a tile it can spare.
			if free.size() < 2:
				return false
	if not _affords("farm"):
		return false
	return _do("build farm", {"type": "building.place", "building": "farm", "anchor": [free[0].x, free[0].y]})


func _do(kind: String, command: Dictionary) -> bool:
	var r := sim.execute(command)
	var key := kind if r["ok"] else kind + " refused (" + String(r.get("reason", "")) + ")"
	counts[key] = int(counts.get(key, 0)) + 1
	return bool(r["ok"])


func _claim_letter() -> bool:
	var mail: MailSystem = sim.system(&"mail")
	for l: Dictionary in mail.letters:
		if int(l["claimed_ms"]) < 0:
			return _do("accept letter", {"type": "mail.claim", "id": l["id"]})
	return false


func _promote() -> bool:
	var tiers: TierSystem = sim.system(&"tiers")
	return tiers.can_promote() and _do("promote", {"type": "tier.promote"})


func _sell() -> bool:
	var ps: PrestigeSystem = sim.system(&"prestige")
	var a := ps.appraise()
	if a["can_sell"] and int(a["points"]) >= 1:
		_mark("prestige ready")
	if not a["can_sell"] or int(a["points"]) < sell_at_points:
		return false
	var lv := (sim.system(&"progression") as ProgressionSystem).level
	var r := PrestigeSystem.sell(sim)
	if not r["ok"]:
		return false
	counts["sell island"] = int(counts.get("sell island", 0)) + 1
	sales.append({"island": island, "active_ms": active_ms, "points": a["points"], "level": lv, "rp": r["rp_issued"]})
	_mark("sold island %d" % island)
	_income_before += production_income()
	attach(r["sim"])
	island += 1
	_place_points()
	return true


## On a new island: every research point placed again, Momo first.
func _place_points() -> void:
	var rs: ResearchSystem = sim.system(&"research")
	var left := rs.rp_unspent()
	var plan := {}
	var ids: Array = []
	for n: Dictionary in rs.nodes():
		if rs.is_unlocked_node(String(n["id"])):
			ids.append(String(n["id"]))
	ids.sort_custom(func(a: String, b: String) -> bool: return _research_rank(a) < _research_rank(b) or (_research_rank(a) == _research_rank(b) and a < b))
	while left > 0 and not ids.is_empty():
		var placed := false
		for id: String in ids:
			if left <= 0:
				break
			if int(plan.get(id, 0)) < rs.max_level(id):
				plan[id] = int(plan.get(id, 0)) + 1
				left -= 1
				placed = true
		if not placed:
			break
	if not plan.is_empty():
		_do("place points", {"type": "research.allocate", "levels": plan})
	sim.execute({"type": "prestige.welcomed"})


## A building whose next stage the player can do now, tapped -- farms first.
func _work_by_hand() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var best := 0
	var best_rank := 99
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if b["state"] != BuildingSystem.IDLE or not bs.can_start(id)["ok"]:
			continue
		# A Momo standing there takes it; the player taps the rest.
		var staffed := false
		for m: int in momos.workers_at(id):
			staffed = staffed or momos.at_work(m)
		if staffed:
			continue
		var rank := ["farm", "research", "lumberyard", "mine"].find(bs.family_of(String(b["type"])))
		rank = 9 if rank < 0 else rank
		if rank < best_rank:
			best = id
			best_rank = rank
	return best != 0 and _do("tap", {"type": "building.tap", "id": best})


func _research() -> bool:
	var rs: ResearchSystem = sim.system(&"research")
	if not rs.active.is_empty() or not rs.has_lab():
		return false
	var best := ""
	for n: Dictionary in rs.nodes():
		var id := String(n["id"])
		if not rs.can_start(id)["ok"]:
			continue
		if best == "" or _research_rank(id) < _research_rank(best) or (_research_rank(id) == _research_rank(best) and int(rs.cost_of(id)["money"]) < int(rs.cost_of(best)["money"])):
			best = id
	return best != "" and _do("research", {"type": "research.start", "id": best})


## Momo first (faster, reach), then the farm, then the rest.
func _research_rank(id: String) -> int:
	var rs: ResearchSystem = sim.system(&"research")
	var n := rs.node(id)
	var kinds := []
	for e: Dictionary in n.get("effects", []):
		kinds.append(String(e.get("kind", "")))
	if kinds.has("momo_work") or kinds.has("watch_tiles") or kinds.has("walk_speed"):
		return 0
	if String(n.get("industry", "")) == "farm" or kinds.has("sale_price"):
		return 1
	return 2


## A landmark when a slot is free and it is affordable.
func _special() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var free := (sim.system(&"world") as WorldSystem).buildable_cells()
	if free.is_empty():
		return false
	for e: Dictionary in bs.special_catalog():
		if not bool(e["unlocked"]) or not bool(e["slot_free"]) or int(e["cooldown_ms"]) > 0:
			continue
		if _affords(String(e["type"])):
			return _do("build " + String(e["type"]), {"type": "building.place", "building": e["type"], "anchor": [free[0].x, free[0].y]})
	return false


## Facilities the island does not have yet, refitted from a spare building
## of their family -- what they make (ingots, releases, cars, power, homes)
## is what the later research and landmarks ask for. One at a time.
const REFITS := ["smelter", "game_studio", "car_factory", "solar_panel", "wind_turbine", "steam_engine", "water_wheel",
	"villa", "park", "office", "pub", "apartment", "community_center"]
const KEEP := {"farm": 3, "research": 1, "lumberyard": 1, "mine": 1}


func _refit() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var have := {}
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if b["state"] == BuildingSystem.CONSTRUCTING:
			return false
		have[String(b["type"])] = int(have.get(String(b["type"]), 0)) + 1
	for type: String in REFITS:
		if have.has(type):
			continue
		var fam := bs.family_of(type)
		if int(have.get(fam, 0)) <= int(KEEP.get(fam, 1)):
			continue
		for id: int in bs.ids():
			if String(bs.get_building(id)["type"]) == fam and bs.can_refit(id, type)["ok"]:
				return _do("refit to " + type, {"type": "building.refit", "id": id, "building": type})
	return false


## Hire while there is more to do than Momo to do it.
func _hire() -> bool:
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	var economy: EconomySystem = sim.system(&"economy")
	var cost := momos.hire_cost()
	if momos.ids().size() * 3 >= bs.ids().size() or not economy.can_afford(cost):
		return false
	# Keep enough for the next farm.
	if economy.money - cost < 10:
		return false
	return _do("hire Momo", {"type": "momo.hire"})


## A Momo with spare room watches the nearest buildings nobody watches --
## from the first harvest on, as the tutorial teaches it (before that the
## player is learning the farm by hand).
func _give_tiles() -> bool:
	if not milestones.has(_k("first harvest")):
		return false
	var momos: MomoSystem = sim.system(&"momo")
	var bs: BuildingSystem = sim.system(&"buildings")
	for m: int in momos.ids():
		var room := momos.watch_capacity(m) - momos.watched(m).size()
		if room <= 0:
			continue
		var cells: Array = []
		var here := momos.position_of(m)
		var free: Array = []
		for id: int in bs.ids():
			if momos.watchers_of(id).is_empty() and momos.slots_of(id) > 0:
				free.append(id)
		free.sort_custom(func(a: int, b: int) -> bool: return here.distance_to(momos.work_spot(a)) < here.distance_to(momos.work_spot(b)) or (here.distance_to(momos.work_spot(a)) == here.distance_to(momos.work_spot(b)) and a < b))
		for id: int in free:
			for c: Vector2i in bs.cells_of(bs.get_building(id)):
				if cells.size() < room:
					cells.append([c.x, c.y])
		if not cells.is_empty():
			return _do("give tiles", {"type": "momo.watch", "momo": m, "cells": cells, "op": "add"})
	return false


## What to build next: farms while two or more tiles are free (cheap, and
## they pay for everything else), keeping the last free tile for the next
## kind a level opens (a lab first, then a lumberyard, then a mine); once
## each kind stands, two farms for every other building.
func _build() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	var world: WorldSystem = sim.system(&"world")
	var free := world.buildable_cells()
	if free.is_empty():
		return false
	var have := {"farm": 0, "research": 0, "lumberyard": 0, "mine": 0}
	for id: int in bs.ids():
		var fam := bs.family_of(String(bs.get_building(id)["type"]))
		have[fam] = int(have.get(fam, 0)) + 1
	var missing := ""
	for fam: String in ["research", "lumberyard", "mine"]:
		if int(have[fam]) == 0 and bs.is_unlocked(fam):
			missing = fam
			break
	var want := "farm"
	if missing != "" and int(have["farm"]) >= 2 and (free.size() == 1 or _affords(missing)):
		want = missing
	elif missing == "" and free.size() >= 1:
		var others := int(have["research"]) + int(have["lumberyard"]) + int(have["mine"])
		if int(have["farm"]) >= 2 * (others + 1):
			for fam: String in ["research", "lumberyard", "mine"]:
				if bs.is_unlocked(fam) and (want == "farm" or int(have[fam]) < int(have[want])):
					want = fam
	elif free.size() < 2 and missing != "":
		return false
	if not _affords(want):
		return false
	return _do("build " + want, {"type": "building.place", "building": want, "anchor": [free[0].x, free[0].y]})


func _affords(type: String) -> bool:
	var cost: Dictionary = sim.data.building_type(type).get("cost", {})
	return (sim.system(&"economy") as EconomySystem).can_afford(int(cost.get("money", 0))) \
		and (sim.system(&"inventory") as InventorySystem).has_all(cost.get("items", {}))


func _buy_land() -> bool:
	var world: WorldSystem = sim.system(&"world")
	var land: LandSystem = sim.system(&"land")
	if not world.buildable_cells().is_empty():
		return false
	if not (sim.system(&"economy") as EconomySystem).can_afford(land.next_cost()):
		return false
	var spots := land.suggested()
	return not spots.is_empty() and _do("buy land", {"type": "land.buy", "cell": [spots[0].x, spots[0].y]})


## Nothing building, working or cooling, no research under way.
func _nothing_working() -> bool:
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		if bs.get_building(id)["state"] != BuildingSystem.IDLE:
			return false
	return (sim.system(&"research") as ResearchSystem).active.is_empty()


# --- what the player sees -------------------------------------------------------------------

func _on_event(type: StringName, p: Dictionary) -> void:
	if type == &"task_completed":
		var action := String(p.get("stage", "")).rstrip("0123456789")
		_mark("first " + action)
		var worker := int(p.get("worker", 0))
		jobs["momo" if worker > 0 else ("hand" if worker == 0 else "auto")] += 1
		if worker > 0:
			_mark("first Momo work")
	if not FEEDBACK.has(type):
		return
	var detail := ""
	match type:
		&"exp_gained":
			detail = "+%d EXP (%s)" % [int(p.get("amount", 0)), String(p.get("reason", ""))]
		&"sold":
			detail = "$%d" % int(p.get("money", 0))
			_mark("first sale")
			var total := (sim.system(&"economy") as EconomySystem).lifetime_income()
			for goal: int in [50, 100, 250, 500, 1000, 2500, 5000, 10000]:
				if total >= goal:
					_mark("earned $%d" % goal)
		&"level_up":
			detail = "Lv %d" % int(p.get("level", 0))
			_mark("level %d" % int(p.get("level", 0)))
		&"building_built":
			detail = String(p.get("type", ""))
			_mark("built " + detail)
		&"land_bought":
			_mark("first land")
		&"momo_hired":
			_mark("first hire")
		&"research_completed":
			detail = String(p.get("id", ""))
			_mark("first research")
			_mark("researched " + detail)
		&"letter_written":
			_mark("first letter")
		&"tier_promoted":
			detail = str(p.get("tier", ""))
			_mark("tier " + detail)
		&"settlement_sold":
			_mark("first sale of an island")
		&"mastery_up":
			# The pennant on the building changes at these levels: visible.
			if int(p.get("level", 0)) in [3, 5, 8]:
				_mark("%s mastery %d" % [String(p.get("type", "")), int(p.get("level", 0))])
	var now := _now()
	if events.is_empty() or int(events[-1]["active_ms"]) != now or String(events[-1]["kind"]) != String(type):
		events.append({"active_ms": now, "island": island, "kind": String(type), "detail": detail})
	if events.size() == 1:
		_mark("first reward")


func _k(key: String) -> String:
	return "%s (island %d)" % [key, island] if island > 1 else key


func _mark(key: String) -> void:
	var k := _k(key)
	if not milestones.has(k):
		milestones[k] = {"active_ms": _now(), "wall_ms": wall_ms(), "offline_ms": offline_ms, "island": island}


## Longest stretch without any feedback between `from_ms` and `to_ms` of
## active play (on every island, or island `on`): {"gap_ms", "at_ms"}.
func longest_quiet(from_ms: int, to_ms: int, on: int = 0) -> Dictionary:
	var last := from_ms
	var gap := 0
	var at := from_ms
	for e: Dictionary in events:
		var t := int(e["active_ms"])
		if (on != 0 and int(e["island"]) != on) or t < from_ms:
			continue
		if t > to_ms:
			break
		if t - last > gap:
			gap = t - last
			at = last
		last = t
	if to_ms - last > gap and last < to_ms:
		gap = to_ms - last
		at = last
	return {"gap_ms": gap, "at_ms": at}


## The firsts (milestones) of island `on` in order of active time, and the
## longest wait between two of them within [from_ms, to_ms].
func milestone_times(on: int = 0) -> Array[int]:
	var out: Array[int] = []
	for k: String in milestones:
		if on == 0 or int(milestones[k]["island"]) == on:
			out.append(int(milestones[k]["active_ms"]))
	out.sort()
	return out


func longest_between_milestones(from_ms: int, to_ms: int, on: int = 0) -> Dictionary:
	var last := from_ms
	var gap := 0
	var at := from_ms
	for t: int in milestone_times(on):
		if t < from_ms:
			continue
		if t > to_ms:
			break
		if t - last > gap:
			gap = t - last
			at = last
		last = t
	return {"gap_ms": gap, "at_ms": at, "count": milestone_times(on).filter(func(t: int) -> bool: return t >= from_ms and t <= to_ms).size()}


func first(key: String) -> int:
	return int(milestones[key]["active_ms"]) if milestones.has(key) else -1
