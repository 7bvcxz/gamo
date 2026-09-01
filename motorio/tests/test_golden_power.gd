extends SceneTree

## The canonical 14~18 minutes, as contracts: the first wreck lives past the
## Lv5 circle and answers only to a torch, its core is guaranteed and *spent*
## on the generator, the [B] lesson waits for the core, and the belt waits for
## the first watt -- mining improved, floor piling up, power built, and then
## logistics. The splitter never walks ahead of the belt.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	_run()

func _run() -> void:
	_test_first_debris_is_outside_heat_15()
	_test_first_debris_needs_a_torch()
	_test_debris_search_time()
	_test_generator_cost_consumes_energy_core()
	_test_build_menu_tutorial_waits_for_the_core()
	_test_conveyor_waits_for_power()
	_test_splitter_does_not_precede_conveyor()
	if failures == 0:
		print("PASS test_golden_power")
	else:
		print("FAIL test_golden_power (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _crash() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()

# --- test_first_debris_is_outside_heat_15 --------------------------------------

func _test_first_debris_is_outside_heat_15() -> void:
	var inside := 0
	var missing := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(87000 + index)
		sim.begin_crash()
		sim.search_kit()
		sim.stones_in = int(Defs.BASE_LEVELS[4]["stones"])   # display Lv5, radius 15
		sim._refresh_radius()
		var nearest := 1e9
		for cell: Vector2i in sim.debris:
			nearest = minf(nearest, Vector2(cell - sim.core_cell).length())
			if sim.is_warm(cell):
				inside += 1
				break
		if nearest > Defs.DEBRIS_FIRST_RING + 1.0:
			missing += 1
		sim.free()
	_assert(inside == 0, "반경 15 안에는 잔해가 없다 (%d회 실패)" % inside)
	_assert(missing == 0,
		"그리고 첫 조각은 %d칸 고리에 보장된다 (%d회 실패)" % [int(Defs.DEBRIS_FIRST_RING), missing])

# --- test_first_debris_needs_a_torch -------------------------------------------

func _test_first_debris_needs_a_torch() -> void:
	_crash()
	var sim = main.sim
	sim.stones_in = int(Defs.BASE_LEVELS[4]["stones"])
	sim._refresh_radius()
	var wreck := Vector2i(9999, 9999)
	var nearest := 1e9
	for cell: Vector2i in sim.debris:
		var d: float = Vector2(cell - sim.core_cell).length()
		if d < nearest:
			nearest = d
			wreck = cell
	_assert(wreck != Vector2i(9999, 9999), "잔해가 있다")
	_assert(not sim.can_touch(wreck), "토치 없이는 닿지 않는다")
	_assert(not sim.search_debris(wreck, 1.0), "그래서 뜯을 수도 없다")
	_assert(sim.open_debris(wreck).is_empty(), "열리지도 않는다")
	# A lit torch is carried heat: the same cell answers.
	sim.torch_lit = true
	_assert(sim.can_touch(wreck), "횃불을 켜면 닿는다 — 고양이에서 배운 그 규칙이다")
	sim.torch_lit = false

# --- test_debris_search_time ----------------------------------------------------

func _test_debris_search_time() -> void:
	_assert(is_equal_approx(Defs.DEBRIS_SEARCH_SECONDS, 5.0),
		"잔해 조사는 5초다 (%.1f)" % Defs.DEBRIS_SEARCH_SECONDS)
	# And the first one still guarantees the core (test_debris walks 60 seeds;
	# here one is enough to keep the promise wired through the new ring).
	_crash()
	var sim = main.sim
	var wreck := Vector2i(9999, 9999)
	var nearest := 1e9
	for cell: Vector2i in sim.debris:
		var d: float = Vector2(cell - sim.core_cell).length()
		if d < nearest:
			nearest = d
			wreck = cell
	sim.torch_lit = true
	var out: Dictionary = sim.open_debris(wreck)
	sim.torch_lit = false
	_assert(int(out.get(Defs.ITEM_ENERGY_CORE, 0)) == 1,
		"첫 잔해는 에너지 코어 1개를 보장한다")

# --- test_generator_cost_consumes_energy_core -----------------------------------

func _test_generator_cost_consumes_energy_core() -> void:
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_GENERATOR]
	_assert(int(cost.get(Defs.ITEM_COPPER, 0)) == 5, "발전기는 구리 5")
	_assert(int(cost.get(Defs.ITEM_ENERGY_CORE, 0)) == 1,
		"그리고 에너지 코어 1 — 열쇠가 아니라 재료다")
	_crash()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	_assert(sim.is_unlocked(Defs.M_GENERATOR), "구리와 코어가 발전기를 연다 — 그대로다")
	sim.stock[Defs.ITEM_COPPER] = 5
	sim.stock[Defs.ITEM_ENERGY_CORE] = 1
	var spot: Vector2i = sim.core_cell + Vector2i(3, 3)
	sim.ore.erase(spot)
	sim.machines.erase(spot)
	sim.debris.erase(spot)
	_assert(sim.build(Defs.M_GENERATOR, spot, Vector2i.RIGHT), "지을 수 있다")
	_assert(int(sim.stock.get(Defs.ITEM_ENERGY_CORE, 0)) == 0,
		"코어가 실제로 소비된다 — 두 번째 발전기는 두 번째 잔해다")
	_assert(not sim.can_afford(Defs.M_GENERATOR), "그래서 바로 둘째를 지을 수 없다")

# --- test_build_menu_tutorial_waits_for_generator --------------------------------

func _test_build_menu_tutorial_waits_for_the_core() -> void:
	_crash()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	main.craft_selected(_craft_index("gun"))
	var left := 3.4
	while left > 0.0:
		main._process_play(1.0 / 30.0)
		left -= 1.0 / 30.0
	_assert(sim.has_gun and sim.is_unlocked(Defs.M_MINER), "총과 채굴기가 있다")
	var judged: Dictionary = main._prompt_status("BUILD")
	_assert(not bool(judged["want"]), "그래도 [B] 안내는 아직이다 — 목록이 한 줄뿐이다")
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	judged = main._prompt_status("BUILD")
	_assert(bool(judged["want"]), "첫 에너지 코어가 [B] 를 가르칠 순간이다")
	# And the generator wears NEW the first time the list opens on it.
	main.toggle_build_menu()
	_assert(main.new_in_menu.has(Defs.M_GENERATOR), "발전기 줄에 NEW 가 붙는다")
	main.toggle_build_menu()
	main.toggle_build_menu()
	_assert(not main.new_in_menu.has(Defs.M_GENERATOR), "두 번째 열람부터는 그냥 줄이다")
	main.toggle_build_menu()

# --- test_conveyor_waits_for_power ----------------------------------------------

func _test_conveyor_waits_for_power() -> void:
	_crash()
	var sim = main.sim
	# Copper alone no longer opens logistics: the exact assertion the old
	# test_progression pinned, inverted on purpose.
	var opened: Array[int] = sim.note_resource_seen(Defs.ITEM_COPPER)
	_assert(not opened.has(Defs.M_BELT), "첫 구리는 벨트를 열지 않는다")
	_assert(not sim.is_unlocked(Defs.M_BELT), "목록에도 없다")
	sim.note_resource_seen(Defs.ITEM_ENERGY_CORE)
	_assert(not sim.is_unlocked(Defs.M_BELT), "코어를 쥐어도 아직이다 — 물건이 아니라 사건이 연다")
	# A fuelled generator: the first watt is the event.
	sim.stock[Defs.ITEM_COPPER] = 5
	sim.stock[Defs.ITEM_ENERGY_CORE] = 1
	var spot: Vector2i = sim.core_cell + Vector2i(3, 3)
	sim.ore.erase(spot)
	sim.machines.erase(spot)
	sim.debris.erase(spot)
	sim.build(Defs.M_GENERATOR, spot, Vector2i.RIGHT)
	_assert(not sim.power_ever, "빈 발전기는 아직 사건이 아니다")
	sim.tick(0.05)
	_assert(not sim.is_unlocked(Defs.M_BELT), "그래서 벨트도 아직이다")
	sim.machine_at(spot).buffer[Defs.GENERATOR_FUEL] = 2
	sim.tick(0.05)
	_assert(sim.power_ever, "연료가 들어가 전력이 흐른 순간이 사건이다")
	_assert(sim.is_unlocked(Defs.M_BELT), "그 순간 벨트가 열린다")
	_assert(sim.take_unlocks().has(Defs.M_BELT), "그리고 말해 준다")
	# Latched: a grid that later runs dry does not re-lock logistics.
	sim.machine_at(spot).buffer.clear()
	sim.tick(0.05)
	_assert(sim.is_unlocked(Defs.M_BELT), "연료가 떨어져도 배운 것은 남는다")
	# And it survives the save.
	var save: Dictionary = sim.to_save()
	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(save)
	_assert(fresh.power_ever, "전력이 흘렀다는 사실이 세이브를 왕복한다")
	fresh.free()

# --- test_splitter_does_not_precede_conveyor ------------------------------------

func _test_splitter_does_not_precede_conveyor() -> void:
	_crash()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	_assert(not sim.is_unlocked(Defs.M_SPLITTER), "구리 시점에 분배기는 목록에 없다")
	# The two open on the same event; the splitter never walks ahead.
	_assert(Defs.MACHINE_UNLOCK_ITEMS[Defs.M_SPLITTER] == Defs.MACHINE_UNLOCK_ITEMS[Defs.M_BELT],
		"분배기는 벨트와 같은 문으로 들어온다")

# --- Helpers ------------------------------------------------------------------

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1
