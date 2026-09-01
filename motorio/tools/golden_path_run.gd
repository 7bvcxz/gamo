extends SceneTree

## Twenty fresh worlds, played by the rules a new player has: the case, the
## fire's window, the prompts, the build list. No debug keys, no granted cats,
## no stocked purses -- every stone is mined, every cat is carried, every craft
## goes through the menu. One line per milestone, timestamped, plus a WAIT
## ledger: seconds spent with nothing actionable versus actions taken.
##
##   godot --headless --path motorio --script res://tools/golden_path_run.gd -- 4207
##
## The one seam of unrealism: walking is a straight line with a wall-slide, so
## the wall-clock cost of a run is minutes rather than a person's half hour.

const MainScene := preload("res://scenes/Main.tscn")
const STEP := 1.0 / 30.0
const CAP_MINUTES := 32.0

var main: Node2D
var sim
var clock := 0.0
var wait_s := 0.0
var improve := 0
var marks: Array[String] = []
var stalls: Array[String] = []
var seedv := 0

func _init() -> void:
	call_deferred("_boot")

func _boot() -> void:
	await process_frame
	seedv = 4200
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			seedv = int(arg)
	main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.clear_save()
	main._start_run()
	main.run_seed = seedv
	main.sim.setup(seedv)
	main.sim.begin_crash()
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(0, 1))
	main.player.warmth = Defs.CRASH_WARMTH
	main.state = main.State.PLAY
	sim = main.sim
	_play()
	print("RESULT seed=%d done=%s clock=%s wait=%.0fs improve=%d" %
		[seedv, "yes" if _has("first_iron") else "no", _mmss(clock), wait_s, improve])
	for line in marks:
		print("MARK " + line)
	for line in stalls:
		print("STALL " + line)
	quit(0)

func _mark(id: String) -> void:
	if _has(id):
		return
	marks.append("%s,%s,seed=%d" % [id, _mmss(clock), seedv])

func _has(id: String) -> bool:
	for line in marks:
		if line.begins_with(id + ","):
			return true
	return false

# --- The run ------------------------------------------------------------------

func _play() -> void:
	_mark("opening_end")
	# 1. The case. The card points at it; hold Z beside it.
	_walk_to(sim.cell_centre(sim.kit_cell + Vector2i(0, 1)), 30.0)
	main.player.facing = Vector2i(0, -1)
	var held := 0.0
	while not sim.base_placed and held < 8.0:
		main.mine_held = true
		_run(0.25)
		held += 0.25
	main.mine_held = false
	if not sim.base_placed:
		stalls.append("상자가 기지가 되지 않았다 seed=%d" % seedv)
		return
	_mark("base_deployed")

	# 2. The fire's window offers exactly one thing: the shelter.
	if not _craft("shelter"):
		stalls.append("숙소 제작 실패 seed=%d" % seedv)
	_collect_drops()
	_place_shelter()
	if sim.shelter_placed:
		_mark("shelter_placed")

	# 3. The pickaxe row appears; make it, it lands in hand.
	if _craft("pickaxe") and sim.has_pickaxe:
		_mark("pickaxe_acquired")

	# 4. Three stones into the fire.
	while sim.base_level < 1 and clock < CAP_MINUTES * 60.0:
		if not _mine_one(Defs.ITEM_HEATSTONE):
			stalls.append("첫 열석을 못 캔다 seed=%d" % seedv)
			return
		_feed_fire()
	if sim.base_level >= 1:
		_mark("base_lv2")

	# 5. The circle reaches the starter cat.
	var cell: Vector2i = _nearest_frozen()
	if cell != Vector2i(9999, 9999) and sim.is_warm(cell):
		_mark("first_cat_found")
	if _rescue(cell) and _put_cat_to_work():
		_mark("first_cat_automating")

	# 6. Grow to Lv3: six more stones. Mine alongside the cat.
	_grow_to_level(2)
	if sim.base_level >= 2:
		_mark("base_lv3")
	# Two more cats are promised inside eleven.
	for _extra in 2:
		var next_cat: Vector2i = _nearest_frozen()
		if next_cat != Vector2i(9999, 9999) and sim.is_warm(next_cat):
			_rescue(next_cat)
			_put_cat_to_work()

	# 7. The edge cat teaches the torch.
	var edge: Vector2i = sim.edge_frozen
	if edge != Vector2i(9999, 9999) and not sim.can_lift(edge):
		if _craft("torch") and _light_torch():
			_mark("torch_used")
			_walk_to(sim.cell_centre(edge) + Vector2(0, 30), 60.0)
			main.player.facing = Vector2i(0, -1)
			var spent := 0.0
			while not sim.can_lift(edge) and spent < 10.0:
				main.mine_held = true
				_run(0.25)
				spent += 0.25
			main.mine_held = false
			if _rescue(edge):
				_put_cat_to_work()

	# 8. Lv4 opens copper.
	_grow_to_level(3)
	if sim.base_level >= 3:
		_mark("base_lv4")
	if _mine_one(Defs.ITEM_COPPER):
		_mark("first_copper")
	# The base wears a "!": the gun row opened.
	if _craft("gun") and sim.has_gun:
		_mark("construction_gun_acquired")
	# The gun arrives loaded with the rig: put it on a bare stone seam.
	var seam: Vector2i = _bare_seam(Defs.ITEM_HEATSTONE)
	while int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) < 5 and clock < CAP_MINUTES * 60.0:
		if not _mine_one(Defs.ITEM_HEATSTONE):
			break
	if seam != Vector2i(9999, 9999) and _build(Defs.M_MINER, seam, Vector2i(0, -1)):
		_mark("first_mining_rig")
		improve += 1
		_move_cat_onto(seam)

	# 9. The wreck past fifteen: torch out, five seconds, the core.
	_grow_to_level(4)
	var wreck: Vector2i = _nearest_debris()
	if wreck != Vector2i(9999, 9999):
		var tries := 0
		while sim.torches <= 0 and tries < 4:
			tries += 1
			while int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) < 3:
				if not _mine_one(Defs.ITEM_HEATSTONE):
					break
			_craft("torch")
		if sim.torches <= 0:
			stalls.append("횃불을 만들 열석이 안 모인다 seed=%d" % seedv)
		if _light_torch():
			_walk_to(sim.cell_centre(wreck) + Vector2(0, 30), 120.0)
			main.player.facing = Vector2i(0, -1)
			var dug := 0.0
			while sim.debris.has(wreck) and dug < 12.0:
				main.mine_held = true
				_run(0.25)
				dug += 0.25
			main.mine_held = false
			_collect_drops()
			if int(sim.collected.get(Defs.ITEM_ENERGY_CORE, 0)) > 0:
				_mark("first_energy_core")

	# 10. The generator: copper five, the core itself.
	while int(sim.stock.get(Defs.ITEM_COPPER, 0)) < 5 and clock < CAP_MINUTES * 60.0:
		if not _mine_one(Defs.ITEM_COPPER):
			break
	var pad: Vector2i = _free_pad()
	if not sim.is_unlocked(Defs.M_GENERATOR):
		stalls.append("발전기가 잠겨 있다(코어 %d) seed=%d"
			% [int(sim.collected.get(Defs.ITEM_ENERGY_CORE, 0)), seedv])
	if _build(Defs.M_GENERATOR, pad, Vector2i(1, 0)):
		_mark("first_generator")
		improve += 1
		# Fuel it by hand: stones go in through its face.
		while int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) < 2:
			if not _mine_one(Defs.ITEM_HEATSTONE):
				break
		for _load in 2:
			if int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) > 0 \
					and sim._accept_into(pad, Defs.ITEM_HEATSTONE, pad + Vector2i(-1, 0)):
				sim.stock[Defs.ITEM_HEATSTONE] = int(sim.stock[Defs.ITEM_HEATSTONE]) - 1
		_run(0.2)
		if sim.power_ever:
			_mark("first_power")

	# 11. The belt the watt just opened: rig to fire.
	var rig: Vector2i = _my_rig()
	while int(sim.stock.get(Defs.ITEM_COPPER, 0)) < 9 and clock < CAP_MINUTES * 60.0:
		if not _mine_one(Defs.ITEM_COPPER):
			break
	if rig != Vector2i(9999, 9999) and sim.is_unlocked(Defs.M_BELT):
		if _belt_home(rig):
			_mark("first_conveyor")
			improve += 1

	# 12. Grow out to iron: Lv7 then Lv8, riding the factory.
	_grow_to_level(6)
	if sim.base_level >= 6:
		_mark("heat_19")
	_grow_to_level(7)
	if sim.base_level >= 7:
		_mark("heat_21")
	if _mine_one(Defs.ITEM_IRON):
		_mark("first_iron")

# --- Player verbs --------------------------------------------------------------

## The improvement loop while the fire is hungry: more rigs when affordable,
## idle cats onto posts, stones into the fire, and hand-mining as the fallback
## every player always has.
func _grow_to_level(want_internal: int) -> void:
	var stuck := 0.0
	var last: int = sim.stones_in
	while sim.base_level < want_internal and clock < CAP_MINUTES * 60.0:
		var acted := false
		# A rig on a fresh seam when a worker -- a cat, or the grid -- can run
		# it. "I would rather improve than wait" is the behaviour under test.
		var can_run: bool = _idle_cat() != null or sim.power_capacity > 0.0
		if sim.is_unlocked(Defs.M_MINER) and can_run:
			if not sim.can_afford(Defs.M_MINER) \
					and int(sim.stock.get(Defs.ITEM_COPPER, 0)) < 1 \
					and int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) >= 5:
				# The rig is copper technology: the missing piece is a trip.
				if _mine_one(Defs.ITEM_COPPER):
					improve += 1
					acted = true
			if sim.can_afford(Defs.M_MINER):
				var seam: Vector2i = _bare_seam(Defs.ITEM_HEATSTONE)
				if seam != Vector2i(9999, 9999) and _build(Defs.M_MINER, seam, Vector2i(0, -1)):
					improve += 1
					_move_cat_onto(seam)
					acted = true
		# The grid dies without stones in the drum.
		if _refuel_generator():
			acted = true
		# Ground stone home, then the fire.
		_sweep_ground()
		if _feed_fire():
			acted = true
		if not acted:
			# Nothing structural: swing the pickaxe rather than stand.
			if _mine_one(Defs.ITEM_HEATSTONE):
				acted = true
			else:
				wait_s += 2.0
				_run(2.0)
		if sim.stones_in == last:
			stuck += 1.0
			if stuck > 240.0:
				stalls.append("불이 4분째 그대로다 lv%d seed=%d" % [sim.base_level, seedv])
				return
		else:
			stuck = 0.0
			last = sim.stones_in

func _refuel_generator() -> bool:
	for cell: Vector2i in sim.machines:
		var machine = sim.machines[cell]
		if machine.type != Defs.M_GENERATOR:
			continue
		if int(machine.buffer.get(Defs.GENERATOR_FUEL, 0)) >= 2:
			return false
		if int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) <= 2:
			return false
		_walk_to(sim.cell_centre(cell + Vector2i(-1, 0)), 40.0)
		var fed := false
		while int(machine.buffer.get(Defs.GENERATOR_FUEL, 0)) < 4 \
				and int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) > 2:
			if not sim._accept_into(cell, Defs.ITEM_HEATSTONE, cell + Vector2i(-1, 0)):
				break
			sim.stock[Defs.ITEM_HEATSTONE] = int(sim.stock[Defs.ITEM_HEATSTONE]) - 1
			fed = true
		return fed
	return false

func _craft(id: String) -> bool:
	# Through the window: walk to the fire, open, pick the row by what it says.
	_walk_to(sim.cell_centre(sim.core_cell + Vector2i(-1, 0)), 40.0)
	main.player.facing = Vector2i(1, 0)
	main._open_base_menu()
	var rows: Array[Dictionary] = main.base_rows()
	var found := -1
	for index in rows.size():
		if String(rows[index]["kind"]) == "craft" \
				and String(Defs.BASE_CRAFTS[int(rows[index]["craft"])]["id"]) == id:
			found = index
	if found < 0:
		main.close_base_menu()
		return false
	main.menu_index = found
	main._base_menu_confirm()
	main.close_base_menu()
	_run(float(Defs.BASE_CRAFTS[_craft_row(id)].get("seconds", 0.0)) + 0.4)
	return true

func _craft_row(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return 0

func _feed_fire() -> bool:
	if not sim.can_feed_base():
		return false
	_walk_to(sim.cell_centre(sim.core_cell + Vector2i(-1, 0)), 40.0)
	main.player.facing = Vector2i(1, 0)
	main._open_base_menu()
	main.menu_index = 0
	main._base_menu_confirm()
	main.close_base_menu()
	return true

func _place_shelter() -> void:
	if sim.carried_kit != Defs.KIT_SHELTER:
		return
	for radius in range(int(Defs.SHELTER_CLEARANCE) + 1, 8):
		for stepi in 12:
			var angle: float = TAU * float(stepi) / 12.0
			var spot: Vector2i = sim.core_cell + Vector2i(
				roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
			_walk_to(sim.cell_centre(spot + Vector2i(-1, 0)), 20.0)
			main.player.facing = Vector2i(1, 0)
			main._primary_action()
			_run(0.2)
			if sim.shelter_placed:
				return

func _mine_one(item_type: int) -> bool:
	for attempt in 2:
		if _mine_at(_nth_ore(item_type, attempt)):
			return true
	return false

func _mine_at(seam: Vector2i) -> bool:
	if seam == Vector2i(9999, 9999):
		return false
	var item_type: int = int(sim.ore.get(seam, -1))
	main.tool_index = 0
	_walk_to(sim.cell_centre(seam) + Vector2(0, 26), 45.0)
	main.player.facing = Vector2i(0, -1)
	var before: int = int(sim.collected.get(item_type, 0))
	var spent := 0.0
	while int(sim.collected.get(item_type, 0)) == before and spent < 16.0:
		main.mine_held = true
		_run(0.25)
		spent += 0.25
	main.mine_held = false
	_collect_drops()
	if int(sim.collected.get(Defs.ITEM_COPPER, 0)) > 0:
		_mark("first_copper")
	if int(sim.collected.get(Defs.ITEM_IRON, 0)) > 0:
		_mark("first_iron")
	if sim.has_gun:
		main.tool_index = 1
	return int(sim.collected.get(item_type, 0)) > before

func _rescue(cell: Vector2i) -> bool:
	if cell == Vector2i(9999, 9999) or not sim.frozen_cats.has(cell):
		return false
	if not sim.can_lift(cell):
		return false
	_walk_to(sim.cell_centre(cell) + Vector2(0, 26), 30.0)
	main.player.facing = Vector2i(0, -1)
	main._primary_action()
	_run(0.2)
	if not sim.carried_frozen:
		stalls.append("얼음까지 길이 막혔다 %s seed=%d" % [str(cell), seedv])
		return false
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1),
			Vector2i(-1, -1)]:
		var spot: Vector2i = sim.core_cell + offset
		_walk_to(sim.cell_centre(spot - offset), 18.0)
		main.player.facing = offset
		main._primary_action()
		_run(0.2)
		if not sim.carried_frozen:
			break
	var before: int = sim.cats.size()
	_run(Defs.THAW_SECONDS + 2.0)
	return sim.cats.size() > before

func _put_cat_to_work() -> bool:
	var cat = _idle_cat()
	if cat == null:
		return false
	var post: Vector2i = _bare_seam(Defs.ITEM_HEATSTONE)
	if post == Vector2i(9999, 9999):
		return false
	_walk_to(cat.pos, 30.0)
	if not sim.pick_up_cat(sim.cell_of(cat.pos)):
		return false
	_walk_to(sim.cell_centre(post + Vector2i(0, 1)), 45.0)
	main.player.facing = Vector2i(0, -1)
	if not sim.place_cat(post):
		sim.drop_cat(main.player.position)
		return false
	improve += 1
	return true

func _move_cat_onto(machine_cell: Vector2i) -> void:
	# A rig on the seam a cat was digging: the cat keeps its post through the
	# build. Otherwise walk an idle one over.
	for cat in sim.cats:
		if cat.assigned == machine_cell:
			return
	var cat = _idle_cat()
	if cat == null:
		return
	_walk_to(cat.pos, 60.0)
	if sim.pick_up_cat(sim.cell_of(cat.pos)):
		_walk_to(sim.cell_centre(machine_cell + Vector2i(0, 1)), 90.0)
		main.player.facing = Vector2i(0, -1)
		if not sim.place_cat(machine_cell):
			sim.drop_cat(main.player.position)

func _light_torch() -> bool:
	if sim.torches <= 0:
		return false
	var slot: int = main.TOOLS.find(main.TOOL_TORCH)
	main.tool_index = slot
	main._primary_action()
	_run(0.2)
	return sim.torch_left > 0.0

func _build(type: int, cell: Vector2i, dir: Vector2i) -> bool:
	# Through the list the player sees: offered, affordable, placeable.
	if not sim.is_unlocked(type) or not sim.can_afford(type):
		return false
	var listed := false
	for index: int in main.build_list():
		if Defs.BUILDABLE[index] == type:
			listed = true
			main.selected_index = index
	if not listed:
		return false
	if sim.can_build(type, cell) != "":
		return false
	_walk_to(sim.cell_centre(cell + Vector2i(0, 1)), 90.0)
	main.player.facing = Vector2i(0, -1)
	return sim.build(type, cell, dir)

func _belt_home(from: Vector2i) -> bool:
	var at: Vector2i = from
	var guard := 0
	var laid := 0
	sim.machines[from].dir = Vector2i(signi(sim.core_cell.x - from.x), 0) \
		if absi(sim.core_cell.x - from.x) >= absi(sim.core_cell.y - from.y) \
		else Vector2i(0, signi(sim.core_cell.y - from.y))
	while at != sim.core_cell and guard < 40:
		guard += 1
		var delta: Vector2i = sim.core_cell - at
		var stepv := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) \
			else Vector2i(0, signi(delta.y))
		var next: Vector2i = at + stepv
		if next == sim.core_cell:
			break
		if not sim.machines.has(next):
			if not _build(Defs.M_BELT, next, stepv):
				return laid > 0
			laid += 1
		at = next
	return laid > 0

func _sweep_ground() -> void:
	var picked := 0
	for cell: Vector2i in sim.ground.keys():
		if picked >= 4:
			break
		if not sim.is_warm(cell):
			continue
		_walk_to(sim.cell_centre(cell), 30.0)
		_run(0.1)
		picked += 1

func _collect_drops() -> void:
	for _round in 6:
		if sim.drops.is_empty():
			return
		var target: Vector2i = sim.drops.keys()[0]
		_walk_to(sim.cell_centre(target), 25.0)
		_run(0.2)

# --- Reading the world ---------------------------------------------------------

func _nth_ore(item_type: int, skip: int) -> Vector2i:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) != item_type or sim.machines.has(cell):
			continue
		if not sim.can_touch(cell):
			continue
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - main.player.cell()).length_squared() \
			< Vector2(b - main.player.cell()).length_squared())
	if cells.size() <= skip:
		return Vector2i(9999, 9999)
	return cells[skip]

func _bare_seam(item_type: int) -> Vector2i:
	var best := Vector2i(9999, 9999)
	var dist := 1e9
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) != item_type or sim.machines.has(cell):
			continue
		if not sim.can_touch(cell):
			continue
		var taken := false
		for cat in sim.cats:
			if cat.assigned == cell:
				taken = true
		if taken:
			continue
		var d: float = Vector2(cell - sim.core_cell).length()
		if d < dist:
			dist = d
			best = cell
	return best

func _nearest_frozen() -> Vector2i:
	var best := Vector2i(9999, 9999)
	var dist := 1e9
	for cell: Vector2i in sim.frozen_cats:
		var d: float = Vector2(cell - sim.core_cell).length()
		if d < dist:
			dist = d
			best = cell
	return best

func _nearest_debris() -> Vector2i:
	var best := Vector2i(9999, 9999)
	var dist := 1e9
	for cell: Vector2i in sim.debris:
		var d: float = Vector2(cell - sim.core_cell).length()
		if d < dist:
			dist = d
			best = cell
	return best

func _free_pad() -> Vector2i:
	for radius in range(2, 8):
		for stepi in 16:
			var angle: float = TAU * float(stepi) / 16.0
			var cell: Vector2i = sim.core_cell + Vector2i(
				roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
			if sim.can_build(Defs.M_GENERATOR, cell) == "":
				return cell
	return sim.core_cell + Vector2i(3, 3)

func _idle_cat():
	for cat in sim.cats:
		if cat != sim.carried_cat and not cat.has_job() \
				and cat.state != Defs.CAT_ASLEEP and cat.state != Defs.CAT_TO_SHELTER:
			return cat
	return null

func _my_rig() -> Vector2i:
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type == Defs.M_MINER:
			return cell
	return Vector2i(9999, 9999)

# --- Clockwork -----------------------------------------------------------------

func _run(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(STEP, left)
		main.player._physics_process(dt)
		main._process(dt)
		clock += dt
		left -= dt

func _walk_to(target: Vector2, limit: float) -> void:
	var spent := 0.0
	var was: Vector2 = main.player.position
	var stuck := 0.0
	var detour := Vector2.ZERO
	var detour_left := 0.0
	var side := 1.0
	while spent < limit and main.player.position.distance_to(target) > 12.0:
		var want: Vector2 = (target - main.player.position).normalized()
		if detour_left > 0.0:
			want = detour
			detour_left -= STEP
		main.player.touch_direction = want
		main.player.touch_sprint = true
		main.player._physics_process(STEP)
		main._process(STEP)
		clock += STEP
		spent += STEP
		if main.player.position.distance_to(was) < 0.2 and detour_left <= 0.0:
			stuck += STEP
			if stuck > 0.15:
				detour = Vector2(-want.y, want.x) * side
				detour_left = 0.35
				side = -side
				stuck = 0.0
		else:
			stuck = 0.0
		was = main.player.position
	main.player.touch_direction = Vector2.ZERO
	main.player.touch_sprint = false

func _mmss(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
