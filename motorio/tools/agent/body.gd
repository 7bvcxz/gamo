extends RefCounted

## The agent's hands: every verb it has, each one the player's own input path,
## each one returning a verdict rather than hoping. No teleports, no debug
## grants -- the body walks with `touch_direction`, holds with `mine_held`, and
## presses Z through `_primary_action`, exactly the wires the pad uses.

const Nav := preload("res://tools/agent/nav.gd")

const OK := "OK"
const FAILED := "FAILED"
const BLOCKED := "BLOCKED"
const TIMEOUT := "TIMEOUT"
const INVALID := "INVALID"

const STEP := 1.0 / 30.0

var main: Node2D
var sim
var nav
var telemetry
## Wall-of-simulation clock, owned here because every second passes through _run.
var clock := 0.0
var replans := 0
var interaction_failures := 0
## What the body is doing right now, for the behaviour time buckets.
var activity := "idle"

func _init(main_ref: Node2D, telemetry_ref) -> void:
	main = main_ref
	sim = main.sim
	nav = Nav.new(sim)
	telemetry = telemetry_ref

# --- Time ----------------------------------------------------------------------

func run(seconds: float, doing: String = "") -> void:
	var was: String = activity
	if doing != "":
		activity = doing
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(STEP, left)
		main.player._physics_process(dt)
		main._process(dt)
		clock += dt
		if telemetry != null:
			telemetry.tick(activity, dt)
		left -= dt
	activity = was

# --- Movement ------------------------------------------------------------------

## Walk to a walkable cell along an A* path, one cell at a time. Replans when
## the world changes underfoot; BLOCKED when no route exists at all.
func move_to(cell: Vector2i, budget: float = 60.0) -> String:
	if not nav.walkable(cell):
		return INVALID
	var start: float = clock
	var attempt := 0
	while main.player.cell() != cell:
		if clock - start >= budget:
			return TIMEOUT
		var route: Array[Vector2i] = nav.path(main.player.cell(), cell)
		if route.is_empty():
			return BLOCKED
		attempt += 1
		if attempt > 1:
			replans += 1
		var verdict: String = _follow(route, budget - (clock - start))
		if verdict == OK or verdict == "REPLAN":
			continue
		return verdict
	return OK

## Walk to a standing cell beside `target` and face it. The answer to "the
## object's own cell is solid", which is most objects in this game.
func move_near(target: Vector2i, budget: float = 60.0) -> String:
	if main.player.cell() == target:
		return OK
	var plan: Dictionary = nav.interaction(main.player.cell(), target)
	if plan.is_empty():
		return BLOCKED
	var stand: Vector2i = plan["stand"]
	if main.player.cell() != stand:
		var verdict: String = move_to(stand, budget)
		if verdict != OK:
			return verdict
	face(target)
	return OK

func face(target: Vector2i) -> void:
	var delta: Vector2i = target - main.player.cell()
	if delta == Vector2i.ZERO:
		return
	if absi(delta.x) >= absi(delta.y):
		main.player.facing = Vector2i(signi(delta.x), 0)
	else:
		main.player.facing = Vector2i(0, signi(delta.y))

## One leg of a path, driven through the player's own mover. Never sets the
## position: a cell that will not be entered by walking is a replan, not a nudge.
func _follow(route: Array[Vector2i], budget: float) -> String:
	var spent := 0.0
	for next: Vector2i in route:
		var target: Vector2 = sim.cell_centre(next)
		var stuck := 0.0
		while main.player.position.distance_to(target) > 10.0:
			if spent >= budget:
				main.player.touch_direction = Vector2.ZERO
				return TIMEOUT
			var before: Vector2 = main.player.position
			main.player.touch_direction = (target - main.player.position).normalized()
			main.player.touch_sprint = true
			run(STEP, "moving")
			spent += STEP
			if main.player.position.distance_to(before) < 0.2:
				stuck += STEP
				if stuck > 0.5:
					# The world changed under the plan; hand it back up.
					main.player.touch_direction = Vector2.ZERO
					main.player.touch_sprint = false
					return "REPLAN"
			else:
				stuck = 0.0
	main.player.touch_direction = Vector2.ZERO
	main.player.touch_sprint = false
	return OK

# --- Interaction ---------------------------------------------------------------

## A press of Z at whatever is on `target`, from a legal standing cell.
func interact(target: Vector2i, budget: float = 60.0) -> String:
	var verdict: String = move_near(target, budget)
	if verdict != OK:
		interaction_failures += 1
		return verdict
	main._primary_action()
	run(0.15, "interacting")
	return OK

## Z held at `target` until `done` answers true or the patience runs out.
func hold_interact(target: Vector2i, done: Callable, patience: float = 12.0) -> String:
	var verdict: String = move_near(target, 60.0)
	if verdict != OK:
		interaction_failures += 1
		return verdict
	var spent := 0.0
	while not done.call():
		if spent >= patience:
			main.mine_held = false
			return TIMEOUT
		main.mine_held = true
		run(0.25, "interacting")
		spent += 0.25
	main.mine_held = false
	return OK

## Swing at a seam until one more of its ore is in the ledger.
func mine(seam: Vector2i, patience: float = 18.0) -> String:
	if not sim.ore.has(seam):
		return INVALID
	if not sim.can_touch(seam):
		return BLOCKED
	var item_type: int = int(sim.ore[seam])
	equip_tool(main.TOOL_PICKAXE)
	var verdict: String = move_near(seam, 60.0)
	if verdict != OK:
		interaction_failures += 1
		return verdict
	var before: int = int(sim.collected.get(item_type, 0))
	var spent := 0.0
	while int(sim.collected.get(item_type, 0)) == before:
		if spent >= patience:
			main.mine_held = false
			return TIMEOUT
		main.mine_held = true
		run(0.25, "mining")
		spent += 0.25
	main.mine_held = false
	collect_loose()
	return OK

## Pick up whatever answers Z on that cell (a frozen cat, a live cat, a drop).
func pick_up(target: Vector2i) -> String:
	return interact(target)

## Put down what is carried, onto `cell`, standing beside it.
func put_down(cell: Vector2i) -> String:
	return interact(cell)

## Walk over the loose things nearby (drops and warm-ground items).
func collect_loose(rounds: int = 6) -> void:
	for _round in rounds:
		if sim.drops.is_empty():
			return
		var target: Vector2i = sim.drops.keys()[0]
		if move_to(target, 25.0) != OK:
			return
		run(0.15, "moving")

# --- The fire's window -----------------------------------------------------------

func open_base(budget: float = 45.0) -> String:
	var verdict: String = move_near(sim.core_cell, budget)
	if verdict != OK:
		return verdict
	main._open_base_menu()
	return OK

## Make a craft row by its id, through the window, and wait out its seconds.
func craft(id: String) -> String:
	if open_base() != OK:
		return BLOCKED
	var rows: Array[Dictionary] = main.base_rows()
	var found := -1
	for index in rows.size():
		if String(rows[index]["kind"]) == "craft" \
				and String(Defs.BASE_CRAFTS[int(rows[index]["craft"])]["id"]) == id:
			found = index
	if found < 0:
		main.close_base_menu()
		return INVALID
	main.menu_index = found
	main._base_menu_confirm()
	main.close_base_menu()
	var seconds := 0.0
	for row: Dictionary in Defs.BASE_CRAFTS:
		if String(row["id"]) == id:
			seconds = float(row.get("seconds", 0.0))
	run(seconds + 0.4, "crafting")
	return OK

## Tip the pack's heat stone into the fire, through the fuel row.
func feed_fire() -> String:
	if not sim.can_feed_base():
		return INVALID
	if open_base() != OK:
		return BLOCKED
	main.menu_index = 0
	main._base_menu_confirm()
	main.close_base_menu()
	run(0.1, "interacting")
	return OK

# --- Building --------------------------------------------------------------------

func open_build_menu() -> String:
	return OK if main.toggle_build_menu() else FAILED

func select_build(type: int) -> String:
	var listed := false
	for index: int in main.build_list():
		if Defs.BUILDABLE[index] == type:
			listed = true
			main.selected_index = index
	return OK if listed else INVALID

## Stand beside `cell`, face it, and put the loaded machine down -- the same
## gate the Z press runs (offered, unlocked, affordable, placeable).
func place_machine(type: int, cell: Vector2i, dir: Vector2i) -> String:
	if select_build(type) != OK:
		return INVALID
	if not sim.is_unlocked(type) or not sim.can_afford(type):
		return FAILED
	if sim.can_build(type, cell) != "":
		return BLOCKED
	var verdict: String = move_near(cell, 60.0)
	if verdict != OK:
		interaction_failures += 1
		return verdict
	equip_tool(main.TOOL_BUILD_GUN)
	if not sim.build(type, cell, dir):
		return FAILED
	run(0.15, "building")
	return OK

func select_recipe(machine_cell: Vector2i, key: String) -> String:
	var machine = sim.machine_at(machine_cell)
	if machine == null:
		return INVALID
	if move_near(machine_cell, 60.0) != OK:
		return BLOCKED
	return OK if sim.set_recipe(machine, key) else FAILED

# --- Tools -----------------------------------------------------------------------

func equip_tool(tool: int) -> String:
	var index: int = main.TOOLS.find(tool)
	if index < 0 or not main.tool_unlocked(tool):
		return INVALID
	main.tool_index = index
	return OK

## Take the torch out and put a match to it: two acts, like the game teaches.
func light_torch() -> String:
	if sim.torches <= 0:
		return INVALID
	if equip_tool(main.TOOL_TORCH) != OK:
		return INVALID
	main._primary_action()
	run(0.15, "interacting")
	return OK if sim.torch_left > 0.0 else FAILED

func wait(seconds: float, reason: String) -> void:
	if telemetry != null:
		telemetry.wait(reason, seconds)
	run(seconds, "waiting")
