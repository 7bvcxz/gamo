extends SceneTree

## The canonical 10~14 minutes, as contracts: copper is under the Lv4 circle and
## not the Lv3 one, the first copper is what opens the build gun, the crafted
## gun lands in slot 2 already pointed at the mining rig, and the rig is copper
## technology at four times a bare cat's pace.

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
	_test_copper_is_reachable_at_heat_13()
	_test_construction_gun_unlocks_on_first_copper()
	_test_crafted_gun_auto_equips_slot_2()
	_test_mining_rig_cost_includes_copper()
	_test_mining_rig_cat_period_is_five_seconds()
	if failures == 0:
		print("PASS test_golden_copper")
	else:
		print("FAIL test_golden_copper (%d)" % failures)
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

func _run_seconds(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(1.0 / 30.0, left)
		main._process_play(step)
		left -= step

# --- test_copper_is_reachable_at_heat_13 / not at heat 11 ----------------------

func _test_copper_is_reachable_at_heat_13() -> void:
	var missing := 0
	var early := 0
	var short_of_belt := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(86000 + index)
		sim.begin_crash()
		sim.search_kit()
		# Lv3 (radius 11): no copper may be touchable yet.
		sim.stones_in = int(Defs.BASE_LEVELS[2]["stones"])
		sim._refresh_radius()
		for cell: Vector2i in sim.ore:
			if int(sim.ore[cell]) == Defs.ITEM_COPPER and sim.can_touch(cell):
				early += 1
				break
		# Lv4 (radius 13): the first patch is inside, whole.
		sim.stones_in = int(Defs.BASE_LEVELS[3]["stones"])
		sim._refresh_radius()
		var reachable := 0
		for cell: Vector2i in sim.ore:
			if int(sim.ore[cell]) == Defs.ITEM_COPPER and sim.can_touch(cell):
				reachable += 1
		if reachable < 1:
			missing += 1
		# And enough of it that a belt is ever buildable from this patch alone.
		if reachable < Defs.FIRST_COPPER_SIZE:
			short_of_belt += 1
		sim.free()
	_assert(early == 0, "반경 11에서는 구리에 닿지 않는다 (%d회 실패)" % early)
	_assert(missing == 0, "반경 13에는 구리가 반드시 있다 (%d회 실패)" % missing)
	_assert(short_of_belt == 0,
		"그리고 패치 전체(%d칸)가 안에 있다 (%d회 실패)" % [Defs.FIRST_COPPER_SIZE, short_of_belt])
	# Warm is not walkable: ore is structure, and a copper patch pocketed by
	# heat-stone seams would be a promise the map breaks. BFS from the core over
	# non-structure cells, because that is the question her legs actually ask.
	var pocketed := 0
	for index in 200:
		var world := Sim.new()
		world.setup(86000 + index)
		world.begin_crash()
		world.search_kit()
		world.stones_in = int(Defs.BASE_LEVELS[3]["stones"])
		world._refresh_radius()
		var seen: Dictionary = {}
		var queue: Array[Vector2i] = [world.core_cell]
		seen[world.core_cell] = true
		var beside := false
		while not queue.is_empty() and not beside:
			var at: Vector2i = queue.pop_front()
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = at + dir
				if seen.has(next) or Vector2(next - world.core_cell).length() > 14.0:
					continue
				if int(world.ore.get(next, -1)) == Defs.ITEM_COPPER and world.can_touch(next):
					beside = true
					break
				if world.is_structure(next) or world.machines.has(next):
					continue
				seen[next] = true
				queue.push_back(next)
		if not beside:
			pocketed += 1
		world.free()
	_assert(pocketed == 0, "걸어서도 닿는다 — 광맥 벽에 갇힌 구리가 없다 (%d회)" % pocketed)

# --- test_construction_gun_unlocks_on_first_copper -----------------------------

func _test_construction_gun_unlocks_on_first_copper() -> void:
	_crash()
	var sim = main.sim
	# Before copper: no gun, no gun row, and upgrading the fire changes nothing.
	_assert(not sim.has_gun, "총 없이 시작한다")
	_assert(not _craft_offered("gun"), "총 줄도 없다")
	sim.stock[Defs.ITEM_HEATSTONE] = Defs.OPENING_STONES
	sim.deposit_fuel()
	_assert(sim.base_level >= 1, "기지가 한 단계 올랐다")
	_assert(not sim.has_gun and not sim.gun_dropped, "그래도 총은 나오지 않는다 — 옛 문이 닫혔다")
	_assert(not _craft_offered("gun"), "줄도 여전히 없다")
	_assert(not sim.is_unlocked(Defs.M_MINER), "채굴기도 잠겨 있다")

	# The first copper is the hinge.
	main._announce_unlocks(sim.note_resource_seen(Defs.ITEM_COPPER))
	sim.stock[Defs.ITEM_COPPER] = 1
	_assert(_craft_offered("gun"), "첫 구리가 총의 제작 줄을 연다")
	_assert(main.base_alert() or sim.base_level >= 1,
		"기지가 다시 볼 것이 있다고 말한다")

# --- test_crafted_gun_auto_equips_slot_2 ---------------------------------------

func _test_crafted_gun_auto_equips_slot_2() -> void:
	_crash()
	var sim = main.sim
	sim.note_resource_seen(Defs.ITEM_COPPER)
	main.craft_selected(_craft_index("gun"))
	_assert(main.craft_making == "gun", "3초 제작이다")
	_run_seconds(3.4)
	_assert(sim.has_gun, "만들면 총이 생긴다")
	_assert(sim.drops.is_empty(), "눈 위에 떨어지지 않는다 — 흡수다")
	_assert(main.TOOLS[main.tool_index] == main.TOOL_BUILD_GUN, "슬롯 2에 자동 장착된다")
	_assert(main.holding_build_gun(), "술어도 그렇게 답한다")
	# test_first_build_defaults_to_mining_rig
	_assert(sim.is_unlocked(Defs.M_MINER), "채굴기가 함께 열린다")
	_assert(Defs.BUILDABLE[main.selected_index] == Defs.M_MINER,
		"그리고 총에 이미 장전되어 있다")
	_assert(not _craft_offered("gun"), "가진 뒤에는 줄이 사라진다")

# --- test_mining_rig_cost_includes_copper --------------------------------------

func _test_mining_rig_cost_includes_copper() -> void:
	var cost: Dictionary = Defs.MACHINE_COSTS[Defs.M_MINER]
	_assert(int(cost.get(Defs.ITEM_HEATSTONE, 0)) == 5, "열석 5")
	_assert(int(cost.get(Defs.ITEM_COPPER, 0)) == 1, "구리 1 — 채굴기는 구리 기술이다")
	# And it still bootstraps: everything in it comes out of the ground by hand.
	for item_id: int in cost:
		_assert(Defs.recipes_producing_item(item_id).is_empty(),
			"%s 는 손으로 캘 수 있다" % Defs.item_short(item_id))

# --- test_mining_rig_cat_period_is_five_seconds --------------------------------

func _test_mining_rig_cat_period_is_five_seconds() -> void:
	_assert(is_equal_approx(Defs.MINER_PERIOD, 5.0), "채굴기 위 고양이는 5초에 하나")
	_assert(is_equal_approx(Defs.CAT_DIG_PERIOD, 20.0), "맨 광맥 고양이는 20초에 하나")
	_assert(is_equal_approx(Defs.CAT_DIG_PERIOD / Defs.MINER_PERIOD, 4.0),
		"정확히 네 배 — 두 번째 WOW 의 크기다")

# --- Helpers ------------------------------------------------------------------

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

func _craft_offered(id: String) -> bool:
	for row: Dictionary in main.base_rows():
		if String(row["kind"]) == "craft" \
				and String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]) == id:
			return true
	return false
