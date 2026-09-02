extends RefCounted

## The agent's head: OBSERVE -> NEED -> GOAL -> PLAN -> ACT, never a clock.
##
## Each pass reads the world, names the current need from progression state
## (never from game_time), picks one goal, and runs one bounded action through
## the body. Failure comes back as a verdict and feeds the stuck ladder:
## replan, another interaction cell, another goal, and finally a snapshot and a
## clean death -- an agent must never loop forever.
##
## The factory policy is deliberately modest (section 9 of the brief): notice a
## shortage, find its source, put a rig or a generator or a belt on it. What it
## must be good at is the WAIT-vs-IMPROVE question, because that question is
## the game's whole thesis and the ledger of it is the point of this harness.

const Body := preload("res://tools/agent/body.gd")
const Observe := preload("res://tools/agent/observe.gd")

var main: Node2D
var sim
var body
var eyes
var telemetry
var mode := "qa"
var until := "first_iron"
var cap_seconds := 35.0 * 60.0

var goal := ""
var goal_fail_count: Dictionary = {}
var last_positions: Array[Vector2] = []
var result := "incomplete"
var failure_kind := ""
var failure_reason := ""
var no_goal_since := -1.0

func _init(main_ref: Node2D, body_ref, eyes_ref, telemetry_ref,
		mode_v: String, until_v: String, cap: float) -> void:
	main = main_ref
	sim = main.sim
	body = body_ref
	eyes = eyes_ref
	telemetry = telemetry_ref
	mode = mode_v
	until = until_v
	cap_seconds = cap

# --- The loop ------------------------------------------------------------------

func play() -> void:
	while body.clock < cap_seconds:
		_note_milestones()
		if telemetry.milestones.has(until):
			result = "completed"
			return
		var next_goal: String = _choose_goal()
		if next_goal == "":
			_confused_tick()
			body.wait(2.0, "no_goal")
			continue
		no_goal_since = -1.0
		goal = next_goal
		var verdict: String = _pursue(goal)
		if verdict == Body.OK:
			goal_fail_count.erase(goal)
			continue
		# The stuck ladder. Level 1 (replan) lives inside the body already;
		# level 2 (other interaction cell) inside nav.interaction. Here are
		# levels 3 and 4: re-evaluate, then die loudly.
		goal_fail_count[goal] = int(goal_fail_count.get(goal, 0)) + 1
		telemetry.stuck(3, "%s -> %s (%d회)" % [goal, verdict, int(goal_fail_count[goal])])
		if int(goal_fail_count[goal]) >= 4:
			result = "failed"
			failure_kind = _classify_failure(goal, verdict)
			failure_reason = "%s repeatedly %s" % [goal, verdict]
			telemetry.stuck(4, failure_reason)
			return
		body.run(1.0, "idle")
	result = "timeout"
	failure_kind = "HARNESS_FAILURE" if _timeout_is_harness() else "GAME_FAILURE"
	failure_reason = "cap %d분 도달 · 마지막 goal=%s" % [int(cap_seconds / 60.0), goal]

## GAME vs HARNESS, decided by what the world says. A goal the map cannot
## satisfy (nothing reachable) is the game's problem; a goal the body could not
## execute (walk timeouts, interaction misses) is ours.
func _classify_failure(which: String, verdict: String) -> String:
	if verdict == Body.INVALID:
		return "GAME_FAILURE"
	if verdict == Body.BLOCKED:
		# Blocked is the map saying no route: check with fresh eyes.
		return "GAME_FAILURE"
	return "HARNESS_FAILURE"

func _timeout_is_harness() -> bool:
	# A timeout with healthy production is pacing (game balance data, not a
	# failure of either kind, but the run must still be classified): if the
	# factory is producing and milestones kept arriving, call it the game's
	# pacing; a dead factory with a wandering agent is ours.
	return float(sim.gain_rate.get(Defs.ITEM_HEATSTONE, 0.0)) <= 0.1 and sim.cats.size() == 0

# --- Goals ---------------------------------------------------------------------

## The need ladder, read from state alone. Ordered: survival first, then the
## golden path's own dependency order -- which is not a script, because every
## line asks "is this already true" before wanting anything.
func _choose_goal() -> String:
	if not sim.base_placed:
		return "open_survival_kit"
	if not sim.shelter_placed:
		return "craft_and_place_shelter"
	if not sim.has_pickaxe:
		return "craft_pickaxe"
	if sim.base_level < 1:
		return "feed_fire"
	if sim.cats.is_empty() and not _liftable_frozen().is_empty():
		return "rescue_cat"
	if not sim.cats.is_empty() and _idle_cat() != null and _free_post() != Vector2i(9999, 9999):
		return "assign_cat"
	# The gun arrives loaded with the rig; the first rig comes before anything
	# else the gun era wants -- it is what the loaded gun is *for*.
	if sim.has_gun and sim.machine_count(Defs.M_MINER) == 0 and _worth_another_rig():
		return "build_rig"
	# The torch beats for the edge cat and, later, the wreck.
	if _wants_energy_core():
		if sim.torches <= 0 and sim.torch_left <= 0.0:
			return "craft_torch"
		return "open_wreck"
	if sim.held_items.has(Defs.ITEM_ENERGY_CORE) and not _has_machine(Defs.M_GENERATOR) \
			and sim.is_unlocked(Defs.M_GENERATOR):
		return "build_generator"
	if _has_machine(Defs.M_GENERATOR) and not sim.power_ever:
		return "fuel_generator"
	if sim.held_items.has(Defs.ITEM_COPPER) and not sim.has_gun:
		return "craft_gun"
	if sim.has_gun and sim.is_unlocked(Defs.M_MINER) and _worth_another_rig():
		return "build_rig"
	if sim.is_unlocked(Defs.M_BELT) and _rig_without_belt() != Vector2i(9999, 9999) \
			and int(sim.stock.get(Defs.ITEM_COPPER, 0)) >= 6:
		return "lay_belt"
	# Not holding copper yet: the circle decides whether that is mining or
	# growing. (In PLAYER mode, "is there copper" is asked of explored ground.)
	if not sim.held_items.has(Defs.ITEM_COPPER):
		if _nearest_reachable_ore(Defs.ITEM_COPPER) != Vector2i(9999, 9999):
			return "mine_copper"
		return "grow_fire"
	if until in ["first_iron", "manufacturer", "iron_plate", "wire", "assembler",
			"motor", "mining_rig_mk2"] and not sim.held_items.has(Defs.ITEM_IRON):
		if _nearest_reachable_ore(Defs.ITEM_IRON) != Vector2i(9999, 9999):
			return "mine_iron"
		return "grow_fire"
	if until != "first_iron" and sim.held_items.has(Defs.ITEM_IRON):
		return "factory_ladder"
	return "grow_fire"

func _pursue(which: String) -> String:
	telemetry.note("GOAL " + which)
	match which:
		"open_survival_kit":
			return body.hold_interact(sim.kit_cell,
				func() -> bool: return sim.base_placed, 10.0)
		"craft_and_place_shelter":
			if sim.carried_kit != Defs.KIT_SHELTER and not _drop_exists(main.sim.DROP_KIT_SHELTER):
				var made: String = body.craft("shelter")
				if made != Body.OK:
					return made
			body.collect_loose()
			if sim.carried_kit != Defs.KIT_SHELTER:
				return Body.FAILED
			return _place_shelter()
		"craft_pickaxe":
			return body.craft("pickaxe")
		"feed_fire", "grow_fire":
			return _grow_step()
		"rescue_cat":
			return _rescue_nearest()
		"assign_cat":
			return _assign_idle_cat()
		"craft_torch":
			if int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) < 2:
				var mined: String = _mine_nearest(Defs.ITEM_HEATSTONE)
				if mined != Body.OK:
					return mined
				if int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) < 2:
					return Body.FAILED
			return body.craft("torch")
		"open_wreck":
			return _open_wreck()
		"craft_gun":
			return body.craft("gun")
		"build_generator":
			return _build_generator()
		"fuel_generator":
			return _fuel_generator()
		"build_rig":
			return _build_rig()
		"lay_belt":
			return _lay_belt()
		"mine_copper":
			return _mine_nearest(Defs.ITEM_COPPER)
		"mine_iron":
			return _mine_nearest(Defs.ITEM_IRON)
		"factory_ladder":
			return _factory_ladder()
	return Body.INVALID

# --- The fire, and WAIT vs IMPROVE ----------------------------------------------

## One step of feeding the fire, with the harness's most important question
## asked out loud every time production would make her wait: is there a cheap
## improvement that beats waiting?
func _grow_step() -> String:
	body.collect_loose(2)
	_sweep_warm_ground()
	if sim.can_feed_base():
		return body.feed_fire()
	var need: int = sim.stones_to_next() - int(sim.stock.get(Defs.ITEM_HEATSTONE, 0))
	var rate: float = float(sim.gain_rate.get(Defs.ITEM_HEATSTONE, 0.0))
	var expected: float = 999.0 if rate <= 0.05 else float(need) / rate * 60.0
	# The improvement question first.
	if _worth_another_rig() and sim.has_gun:
		telemetry.improvements += 1
		return _build_rig()
	if _idle_cat() != null and _free_post() != Vector2i(9999, 9999):
		telemetry.improvements += 1
		return _assign_idle_cat()
	if not _liftable_frozen().is_empty() and sim.cats.size() < 6:
		return _rescue_nearest()
	# No structural answer: mine alongside the factory, and if even that is
	# saturated, wait -- but say so, and say what was missed if anything.
	var seam: Vector2i = _nearest_reachable_ore(Defs.ITEM_HEATSTONE)
	if seam != Vector2i(9999, 9999):
		return _mine_nearest(Defs.ITEM_HEATSTONE)
	if expected > 60.0 and sim.has_gun and sim.is_unlocked(Defs.M_MINER) \
			and not sim.can_afford(Defs.M_MINER):
		telemetry.wait("production", 4.0, false,
			"need=%d rate=%.1f/min" % [need, rate])
		telemetry.mark_missed_automation("채굴기 지을 구리/열석 부족, 대기 %.0f초 예상" % expected)
	else:
		telemetry.wait("production", 4.0, false, "need=%d rate=%.1f/min" % [need, rate])
	body.run(4.0, "waiting")
	return Body.OK

func _sweep_warm_ground() -> void:
	var picked := 0
	for cell: Vector2i in sim.ground.keys():
		if picked >= 3:
			return
		if not sim.is_warm(cell):
			continue
		if body.move_to(cell, 20.0) == Body.OK:
			body.run(0.1, "moving")
			picked += 1

# --- Verbs built from primitives -------------------------------------------------

func _place_shelter() -> String:
	for radius in range(int(Defs.SHELTER_CLEARANCE) + 1, 8):
		for step in 12:
			var angle: float = TAU * float(step) / 12.0
			var spot: Vector2i = sim.core_cell + Vector2i(
				roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
			if sim.shelter_too_close(spot) or sim.blocks_player(spot):
				continue
			if body.put_down(spot) == Body.OK and sim.shelter_placed:
				return Body.OK
	return Body.FAILED

func _rescue_nearest() -> String:
	var liftable: Array[Vector2i] = _liftable_frozen()
	var cell: Vector2i = Observe.nearest(sim.core_cell, liftable)
	if cell == Vector2i(9999, 9999):
		return Body.INVALID
	if body.pick_up(cell) != Body.OK or not sim.carried_frozen:
		return Body.FAILED
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var spot: Vector2i = sim.core_cell + offset
		if sim.blocks_player(spot):
			continue
		if body.put_down(spot) == Body.OK and not sim.carried_frozen:
			var before: int = sim.cats.size()
			body.run(Defs.THAW_SECONDS + 2.0, "waiting")
			return Body.OK if sim.cats.size() > before else Body.FAILED
	return Body.FAILED

func _assign_idle_cat() -> String:
	var cat = _idle_cat()
	var post: Vector2i = _free_post()
	if cat == null or post == Vector2i(9999, 9999):
		return Body.INVALID
	if body.move_to(sim.cell_of(cat.pos), 45.0) not in [Body.OK, Body.INVALID]:
		return Body.FAILED
	# Standing on or beside it: the lift is the Z verb's own function.
	if not sim.pick_up_cat(sim.cell_of(cat.pos)):
		if body.move_near(sim.cell_of(cat.pos), 20.0) != Body.OK \
				or not sim.pick_up_cat(main.player.facing_cell()):
			return Body.FAILED
	if body.move_near(post, 60.0) != Body.OK:
		sim.drop_cat(main.player.position)
		return Body.FAILED
	if not sim.place_cat(post):
		sim.drop_cat(main.player.position)
		return Body.FAILED
	return Body.OK

func _mine_nearest(item_type: int) -> String:
	var seam: Vector2i = _nearest_reachable_ore(item_type)
	if seam == Vector2i(9999, 9999):
		return Body.INVALID
	var verdict: String = body.mine(seam)
	if verdict == Body.OK and sim.has_gun:
		body.equip_tool(main.TOOL_BUILD_GUN)
	return verdict

func _open_wreck() -> String:
	var cells: Array[Vector2i] = eyes.debris_cells()
	var wreck: Vector2i = Observe.nearest(sim.core_cell, cells)
	if wreck == Vector2i(9999, 9999):
		# PLAYER mode has not seen one yet: push the frontier instead.
		return _explore_frontier()
	if not sim.can_touch(wreck) and sim.torch_left <= 0.0:
		var lit: String = body.light_torch()
		if lit != Body.OK:
			return lit
	var verdict: String = body.hold_interact(wreck,
		func() -> bool: return not sim.debris.has(wreck), 14.0)
	body.collect_loose()
	return verdict

func _build_generator() -> String:
	# Beside a stone seam's rig if one exists, so the rig can pour straight in;
	# otherwise any clear pad near the fire.
	if int(sim.stock.get(Defs.ITEM_COPPER, 0)) < 5:
		return _mine_nearest(Defs.ITEM_COPPER)
	var rig: Vector2i = _rig_on(Defs.ITEM_HEATSTONE)
	if rig != Vector2i(9999, 9999):
		var machine = sim.machine_at(rig)
		var mouth: Vector2i = rig + machine.dir
		if sim.can_build(Defs.M_GENERATOR, mouth) == "":
			var placed: String = body.place_machine(Defs.M_GENERATOR, mouth, Vector2i(1, 0))
			if placed == Body.OK:
				return Body.OK
	# No rig yet, or its mouth is taken: stand the generator beside a stone
	# seam, so `fuel_generator` can put a rig on that seam pointing in. This is
	# the beltless feeding grammar -- machine pours into machine -- and a
	# generator built in the open is a machine that starves.
	var best_pad := Vector2i(9999, 9999)
	var best_d := 1e18
	for seam: Vector2i in eyes.ore_cells(Defs.ITEM_HEATSTONE):
		if not sim.can_touch(seam):
			continue
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var pad: Vector2i = seam + dir
			if sim.can_build(Defs.M_GENERATOR, pad) != "":
				continue
			var d: float = Vector2(pad - sim.core_cell).length_squared()
			if d < best_d:
				best_d = d
				best_pad = pad
	if best_pad != Vector2i(9999, 9999):
		return body.place_machine(Defs.M_GENERATOR, best_pad, Vector2i(1, 0))
	telemetry.confusion("FACTORY", "발전기를 세울 광맥 인접 자리가 없다")
	return Body.BLOCKED

## Fuelling without belts is the discovered grammar: a stone rig pointed at the
## generator pours into it -- the same mouth a belt would feed. If no such pair
## exists yet, make one: retarget an existing rig by building the generator in
## front of it was handled above; here we build a rig facing the generator.
func _fuel_generator() -> String:
	var generator: Vector2i = _machine_cell(Defs.M_GENERATOR)
	if generator == Vector2i(9999, 9999):
		return Body.INVALID
	# A stone seam adjacent to the generator, rig on it, facing in.
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var seam: Vector2i = generator + dir
		if int(sim.ore.get(seam, -1)) != Defs.ITEM_HEATSTONE:
			continue
		if sim.machines.has(seam):
			var rig = sim.machine_at(seam)
			if Defs.machine_mines(rig.type) and rig.dir != -dir:
				rig.dir = -dir   # R turns it; the verb exists on the keyboard
				telemetry.note("ROTATE rig -> generator")
			return _ensure_rig_worker(seam)
		if not sim.is_unlocked(Defs.M_MINER):
			continue
		if not sim.can_afford(Defs.M_MINER):
			# The rig for this seam is one trip away, not a wall: go and get
			# what is missing rather than declaring the generator unfeedable.
			var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MINER]
			for item_id: int in cost:
				if int(sim.stock.get(item_id, 0)) < int(cost[item_id]):
					return _mine_nearest(item_id)
		if body.place_machine(Defs.M_MINER, seam, -dir) == Body.OK:
			telemetry.improvements += 1
			return _ensure_rig_worker(seam)
	# No adjacent seam: nothing here can be fed yet -- the generator stands in
	# the wrong place for a beltless world. Report loudly; this is the exact
	# UX finding the harness exists to record.
	telemetry.confusion("FACTORY",
		"발전기에 연료를 넣을 방법이 없다 — 손 투입 동사 부재, 채굴기 인접 배치 필요")
	return Body.BLOCKED

func _ensure_rig_worker(rig: Vector2i) -> String:
	for cat in sim.cats:
		if cat.assigned == rig:
			return Body.OK
	var idle = _idle_cat()
	if idle == null:
		# Steal from a bare seam: a rig beats a paw.
		for cat in sim.cats:
			if cat.has_job() and not sim.machines.has(cat.assigned):
				idle = cat
				break
	if idle == null:
		return Body.FAILED
	if body.move_to(sim.cell_of(idle.pos), 45.0) not in [Body.OK, Body.INVALID]:
		return Body.FAILED
	if not sim.pick_up_cat(sim.cell_of(idle.pos)):
		return Body.FAILED
	if body.move_near(rig, 60.0) != Body.OK or not sim.place_cat(rig):
		sim.drop_cat(main.player.position)
		return Body.FAILED
	return Body.OK

func _build_rig() -> String:
	if not sim.can_afford(Defs.M_MINER):
		if int(sim.stock.get(Defs.ITEM_COPPER, 0)) < 1:
			return _mine_nearest(Defs.ITEM_COPPER)
		return _mine_nearest(Defs.ITEM_HEATSTONE)
	var seam: Vector2i = _best_bare_seam(Defs.ITEM_HEATSTONE)
	if seam == Vector2i(9999, 9999):
		return Body.INVALID
	var verdict: String = body.place_machine(Defs.M_MINER, seam, _emit_dir(seam))
	if verdict == Body.OK:
		telemetry.improvements += 1
		_ensure_rig_worker(seam)
	return verdict

func _lay_belt() -> String:
	var rig: Vector2i = _rig_without_belt()
	if rig == Vector2i(9999, 9999):
		return Body.INVALID
	var machine = sim.machine_at(rig)
	var at: Vector2i = rig + machine.dir
	var laid := 0
	var guard := 0
	while at != sim.core_cell and guard < 30:
		guard += 1
		var delta: Vector2i = sim.core_cell - at
		var step := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) \
			else Vector2i(0, signi(delta.y))
		if at + step == sim.core_cell:
			step = step   # the last belt faces the core's mouth
		if not sim.machines.has(at):
			if not sim.can_afford(Defs.M_BELT):
				break
			if body.place_machine(Defs.M_BELT, at, step) != Body.OK:
				break
			laid += 1
		at += step
	if laid > 0:
		telemetry.improvements += 1
		telemetry.milestone("conveyor")
		return Body.OK
	return Body.FAILED

## After iron: the foundation ladder, kept simple -- one manufacturer on
## plates, fed by hand-mined iron, far enough for `until` targets past iron.
func _factory_ladder() -> String:
	if not _has_machine(Defs.M_MANUFACTURER) and sim.is_unlocked(Defs.M_MANUFACTURER):
		if not sim.can_afford(Defs.M_MANUFACTURER):
			var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MANUFACTURER]
			for item_id: int in cost:
				if int(sim.stock.get(item_id, 0)) < int(cost[item_id]):
					return _mine_nearest(item_id)
		for radius in range(3, 9):
			for step in 12:
				var angle: float = TAU * float(step) / 12.0
				var cell: Vector2i = sim.core_cell + Vector2i(
					roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
				if sim.can_build(Defs.M_MANUFACTURER, cell) == "":
					var placed: String = body.place_machine(Defs.M_MANUFACTURER, cell, Vector2i(1, 0))
					if placed == Body.OK:
						telemetry.milestone("manufacturer")
					return placed
		return Body.BLOCKED
	return _grow_step()

func _explore_frontier() -> String:
	var edge: Vector2i = eyes.frontier(sim.core_cell, sim.warm_radius)
	if edge == Vector2i(9999, 9999):
		return Body.FAILED
	var verdict: String = body.move_to(edge, 40.0)
	body.run(1.0, "exploring")
	return verdict

# --- Confusion ------------------------------------------------------------------

func _confused_tick() -> void:
	if no_goal_since < 0.0:
		no_goal_since = body.clock
		return
	if body.clock - no_goal_since > 30.0:
		telemetry.confusion("UNKNOWN", "30초 이상 의미 있는 goal 없음")
		no_goal_since = body.clock

# --- Reading the world (through the mode's eyes) ---------------------------------

func _wants_energy_core() -> bool:
	if sim.held_items.has(Defs.ITEM_ENERGY_CORE):
		return false
	# The wreck matters once the gun era is near: copper held, or the edge of
	# the circle has crossed the wreck ring in QA's knowledge.
	return sim.held_items.has(Defs.ITEM_COPPER) and sim.has_gun

func _liftable_frozen() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in eyes.frozen_cells():
		if sim.can_lift(cell):
			out.append(cell)
	return out

func _idle_cat():
	for cat in sim.cats:
		if cat != sim.carried_cat and not cat.has_job() \
				and cat.state != Defs.CAT_ASLEEP and cat.state != Defs.CAT_TO_SHELTER:
			return cat
	return null

func _free_post() -> Vector2i:
	# A standing rig without a worker first, then a bare stone seam.
	for cell: Vector2i in sim.machines:
		if Defs.machine_mines(sim.machines[cell].type) and sim.worker_at(cell) == null \
				and not sim.miner_on_power(cell):
			return cell
	return _best_bare_seam(Defs.ITEM_HEATSTONE)

func _best_bare_seam(item_type: int) -> Vector2i:
	var best := Vector2i(9999, 9999)
	var dist := 1e18
	for cell: Vector2i in eyes.ore_cells(item_type):
		if sim.machines.has(cell) or not sim.can_touch(cell):
			continue
		var taken := false
		for cat in sim.cats:
			if cat.assigned == cell:
				taken = true
		if taken:
			continue
		var d: float = Vector2(cell - sim.core_cell).length_squared()
		if d < dist:
			dist = d
			best = cell
	return best

func _nearest_reachable_ore(item_type: int) -> Vector2i:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in eyes.ore_cells(item_type):
		if sim.can_touch(cell) and not sim.machines.has(cell):
			cells.append(cell)
	return Observe.nearest(main.player.cell(), cells)

func _worth_another_rig() -> bool:
	if not sim.is_unlocked(Defs.M_MINER):
		return false
	var seats: int = sim.cats.size() + int(sim.power_capacity / maxf(Defs.MINER_POWER_DRAW, 0.1))
	if sim.machine_count(Defs.M_MINER) >= seats:
		return false
	if _best_bare_seam(Defs.ITEM_HEATSTONE) == Vector2i(9999, 9999):
		return false
	return sim.can_afford(Defs.M_MINER) \
		or int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) >= 5

func _rig_without_belt() -> Vector2i:
	for cell: Vector2i in sim.machines:
		if not Defs.machine_mines(sim.machines[cell].type):
			continue
		var mouth: Vector2i = cell + sim.machines[cell].dir
		var target = sim.machine_at(mouth)
		if target == null:
			return cell
	return Vector2i(9999, 9999)

func _rig_on(item_type: int) -> Vector2i:
	for cell: Vector2i in sim.machines:
		if Defs.machine_mines(sim.machines[cell].type) \
				and int(sim.ore.get(cell, -1)) == item_type:
			return cell
	return Vector2i(9999, 9999)

func _machine_cell(type: int) -> Vector2i:
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type == type:
			return cell
	return Vector2i(9999, 9999)

func _has_machine(type: int) -> bool:
	return _machine_cell(type) != Vector2i(9999, 9999)

func _drop_exists(kind: int) -> bool:
	for cell: Vector2i in sim.drops:
		if int(sim.drops[cell]) == kind:
			return true
	return false

## Where a new rig should pour: toward the fire when a belt could follow,
## otherwise any open side.
func _emit_dir(seam: Vector2i) -> Vector2i:
	var toward: Vector2i = sim.core_cell - seam
	var dir := Vector2i(signi(toward.x), 0) if absi(toward.x) >= absi(toward.y) \
		else Vector2i(0, signi(toward.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(0, -1)
	return dir

# --- Milestones ------------------------------------------------------------------

func _note_milestones() -> void:
	var t = telemetry
	if sim.base_placed: t.milestone("base_deployed")
	if sim.shelter_placed: t.milestone("shelter")
	if sim.has_pickaxe: t.milestone("pickaxe")
	if sim.base_level >= 1: t.milestone("base_lv2")
	if not sim.cats.is_empty(): t.milestone("first_cat")
	for cat in sim.cats:
		if cat.has_job():
			t.milestone("first_automation")
			break
	if sim.base_level >= 2: t.milestone("base_lv3")
	if sim.has_learned("TORCH") or sim.torch_left > 0.0 or bool(sim.thawed.size() > 0):
		t.milestone("torch")
	if sim.base_level >= 3: t.milestone("base_lv4")
	if sim.held_items.has(Defs.ITEM_COPPER): t.milestone("copper")
	if sim.has_gun: t.milestone("construction_gun")
	if sim.machine_count(Defs.M_MINER) > 0: t.milestone("mining_rig")
	if sim.held_items.has(Defs.ITEM_ENERGY_CORE): t.milestone("energy_core")
	if _has_machine(Defs.M_GENERATOR): t.milestone("generator")
	if sim.power_ever: t.milestone("power")
	if sim.machine_count(Defs.M_BELT) > 0: t.milestone("conveyor")
	if sim.base_level >= 6: t.milestone("heat19")
	if sim.base_level >= 7: t.milestone("heat21")
	if sim.held_items.has(Defs.ITEM_IRON): t.milestone("first_iron")
	if _has_machine(Defs.M_MANUFACTURER): t.milestone("manufacturer")
	if sim.held_items.has(Defs.ITEM_IRON_PLATE): t.milestone("iron_plate")
	if sim.held_items.has(Defs.ITEM_COPPER_WIRE): t.milestone("wire")
	if _has_machine(Defs.M_ASSEMBLER): t.milestone("assembler")
	if sim.held_items.has(Defs.ITEM_ELECTRIC_MOTOR): t.milestone("motor")
	if sim.machine_count(Defs.M_MINER_MK2) > 0: t.milestone("mining_rig_mk2")
