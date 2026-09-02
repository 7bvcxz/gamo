extends SceneTree

## The canonical 0~5 minutes, as contracts.
##
## Each function here is one sentence of the golden path: the case unfolds into
## the base, the shelter and the pickaxe come out of the fire, the thought waits
## for a breath and then points home, and the first cat is inside nine tiles.
## These are the assertions Step 1's audit said were missing -- the ones that,
## absent, let the flow regress to "things fall out of a box" without a single
## test going red.

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
	_test_base_deploys_on_first_search()
	_test_shelter_is_crafted_not_found()
	_test_pickaxe_is_crafted_not_found()
	_test_crafted_pickaxe_auto_equips()
	_test_third_motivation_points_to_base()
	_test_base_upgrade_progress_shows_0_of_3()
	_test_first_cat_is_reachable_at_heat_9()
	_test_the_picture_follows_the_heat()
	_test_the_case_is_one_walk_away()
	_test_a_new_recipe_raises_the_alert()
	if failures == 0:
		print("PASS test_golden_opening")
	else:
		print("FAIL test_golden_opening (%d)" % failures)
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

## Ticks the world the way play does, craft queue and all.
func _run_seconds(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(1.0 / 30.0, left)
		main._process_play(step)
		left -= step

# --- test_base_deploys_on_first_search ---------------------------------------

func _test_base_deploys_on_first_search() -> void:
	_crash()
	var sim = main.sim
	var anchor: Vector2i = sim.kit_cell
	_assert(not sim.base_placed, "조사 전에는 기지가 없다")
	_assert(sim.core_cell != anchor, "펼치기 전의 코어는 그녀가 선 자리다")
	sim.search_kit()
	_assert(sim.base_placed, "첫 조사가 끝나면 기지가 저절로 선다")
	# On the case's own cell, which is the world anchor: every ring promise out
	# there is measured from where the fire ends up, and a base two cells off it
	# put the Lv2 cat inside the first circle in two hundred seeds out of two
	# hundred.
	_assert(sim.core_cell == anchor, "상자가 있던 그 칸에서 펼쳐진다")
	_assert(sim.machine_at(anchor) != null, "코어가 실제로 그 칸에 있다")
	_assert(sim.kit_cell == Vector2i(9999, 9999), "상자는 사라진다 — 기지가 되었으니까")
	_assert(not sim.is_structure(anchor + Vector2i(2, 1)),
		"상자가 서 있던 자리에 막는 것이 남지 않는다")
	_assert(sim.carried_kit == Defs.KIT_NONE, "기지 키트를 드는 일은 없다")
	_assert(sim.drops.is_empty(), "눈 위에 떨어지는 것도 없다")
	_assert(sim.is_warm(anchor), "그 순간 그 자리가 따뜻하다")
	_assert(absf(sim.warm_radius - Defs.WARM_BASE) < 0.01,
		"온기 반경 %.0f이 즉시 열린다 — 연출이 규칙을 늦추지 않는다" % Defs.WARM_BASE)
	_assert(not sim.can_search_kit(), "상자의 역할은 그것으로 끝난다")
	_assert(sim.search_kit().is_empty(), "두 번째 조사는 없다")
	# 200 worlds: the case must never fail to become the fire.
	var broken := 0
	for index in 200:
		var world := Sim.new()
		world.setup(81000 + index)
		world.begin_crash()
		world.search_kit()
		if not world.base_placed or world.machine_at(world.core_cell) == null:
			broken += 1
		world.free()
	_assert(broken == 0, "200시드 모두에서 펼쳐진다 (%d회 실패)" % broken)

# --- test_shelter_is_crafted_not_found ---------------------------------------

func _test_shelter_is_crafted_not_found() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	# The fire's window opens with the shelter on it, free.
	var names: Array[String] = []
	for row: Dictionary in main.base_rows():
		if String(row["kind"]) == "craft":
			names.append(String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]))
	_assert(names.has("shelter"), "기지 창에 숙소 키트가 있다: %s" % str(names))
	_assert(not names.has("pickaxe"), "곡괭이는 아직 보이지 않는다 — 한 번에 한 문장")
	var shelter_row: Dictionary = {}
	for row: Dictionary in Defs.BASE_CRAFTS:
		if String(row["id"]) == "shelter":
			shelter_row = row
	_assert((shelter_row["cost"] as Dictionary).is_empty(), "그리고 공짜다")
	# Craft it: three seconds, then a kit on the snow beside the fire.
	main.menu_index = 0
	main.craft_selected(_craft_index("shelter"))
	_assert(main.craft_making == "shelter", "만드는 데 시간이 걸린다")
	_run_seconds(float(shelter_row["seconds"]) + 0.2)
	var dropped := Vector2i(9999, 9999)
	for cell: Vector2i in sim.drops:
		if int(sim.drops[cell]) == Sim.DROP_KIT_SHELTER:
			dropped = cell
	_assert(dropped != Vector2i(9999, 9999), "끝나면 키트가 기지 옆에 떨어진다")
	_assert(Vector2(dropped - sim.core_cell).length() <= 5.0,
		"기지 곁이다: %s" % str(dropped))
	# Pick it up and place it by hand -- the first hand-placed building.
	_assert(sim.collect_drop(dropped) == Sim.DROP_KIT_SHELTER, "밟아서 줍는다")
	_assert(sim.carried_kit == Defs.KIT_SHELTER, "이제 손에 들려 있다")
	_assert(not sim.place_shelter(sim.core_cell + Vector2i(1, 0)),
		"기지에 붙여서는 안 되고")
	var spot: Vector2i = _clear_spot(sim)
	_assert(sim.place_shelter(spot), "고른 자리에는 선다")
	# Once standing, the row retires.
	var again: Array[String] = []
	for row: Dictionary in main.base_rows():
		if String(row["kind"]) == "craft":
			again.append(String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]))
	_assert(not again.has("shelter"), "서고 나면 창에서 사라진다")

# --- test_pickaxe_is_crafted_not_found ---------------------------------------

func _test_pickaxe_is_crafted_not_found() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	_assert(not sim.has_pickaxe, "곡괭이를 들고 시작하지 않는다")
	# Nothing on the snow will ever be a pickaxe.
	for cell: Vector2i in sim.drops:
		_assert(int(sim.drops[cell]) != Sim.DROP_PICKAXE, "눈 위에 곡괭이는 없다")
	# The row waits for the shelter.
	_assert(_craft_offered("pickaxe") == false, "숙소 전에는 곡괭이 줄이 없다")
	sim.shelter_placed = true
	sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
	_assert(_craft_offered("pickaxe"), "숙소가 서면 곡괭이 줄이 열린다")
	main.craft_selected(_craft_index("pickaxe"))
	_run_seconds(3.2)
	_assert(sim.has_pickaxe, "만들면 생긴다 — 줍는 단계가 없다")
	_assert(sim.drops.is_empty() or not _drop_kind_exists(sim, Sim.DROP_PICKAXE),
		"이번에도 눈 위에는 아무것도 없다")
	_assert(_craft_offered("pickaxe") == false, "가진 뒤에는 줄이 사라진다")

# --- test_crafted_pickaxe_auto_equips ----------------------------------------

func _test_crafted_pickaxe_auto_equips() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	sim.shelter_placed = true
	sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
	main.tool_index = 0
	main.craft_selected(_craft_index("pickaxe"))
	_run_seconds(3.2)
	_assert(main.TOOLS[main.tool_index] == main.TOOL_PICKAXE, "만든 곡괭이가 손에 들린다")
	_assert(main.holding_pickaxe(), "술어도 그렇게 답한다")
	_assert(main.tool_unlocked(main.TOOL_PICKAXE), "슬롯 1이 열려 있다")

# --- test_third_motivation_points_to_base ------------------------------------

func _test_third_motivation_points_to_base() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	sim.shelter_placed = true
	sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
	main._update_missions()
	_assert(main.open_missions().is_empty(), "숙소 직후에는 아직 조용하다 — 짧은 자유")
	# The pickaxe row has just appeared, so the fire is wearing its "!" for that.
	# She looks, as a player must -- crafting happens through this window.
	_assert(main.base_alert(), "숙소를 세우면 곡괭이 줄이 ! 를 세운다")
	main._open_base_menu()
	main.close_base_menu()
	_assert(not main.base_alert(), "기지의 ! 도 아직이다")
	_run_seconds(Defs.THOUGHT_DELAY + 0.5)
	main._update_missions()
	var ids: Array[String] = []
	for row: Dictionary in main.open_missions():
		ids.append(String(row["id"]))
	_assert(ids.has("BASE2"), "한 박자 뒤에 생각이 열린다: %s" % str(ids))
	_assert(main.base_alert(), "그리고 기지 위에 ! 가 선다")
	# Looking at the fire answers the "!"; the rung itself stays until level 1.
	main._open_base_menu()
	main.close_base_menu()
	_assert(not main.base_alert(), "기지 창을 열면 ! 는 내려간다")
	main._update_missions()
	_assert(not main.open_missions().is_empty(), "생각 자체는 강화 전까지 남는다")
	sim.stones_in = Defs.OPENING_STONES
	sim._refresh_radius()
	main._update_missions()
	_assert(main.open_missions().is_empty(), "첫 강화가 그 생각을 끝낸다")

# --- test_base_upgrade_progress_shows_0_of_3 ----------------------------------

func _test_base_upgrade_progress_shows_0_of_3() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	_assert(main.fuel_progress() == [0, Defs.OPENING_STONES],
		"기지 창의 강화 줄이 0/%d 로 읽힌다: %s"
		% [Defs.OPENING_STONES, str(main.fuel_progress())])
	sim.stock[Defs.ITEM_HEATSTONE] = 2
	_assert(main.fuel_progress() == [2, Defs.OPENING_STONES],
		"두 개를 캐면 2/%d — 보유가 앞자리다" % Defs.OPENING_STONES)

# --- test_first_cat_is_reachable_at_heat_9 ------------------------------------

func _test_first_cat_is_reachable_at_heat_9() -> void:
	var short := 0
	var early := 0
	for index in 200:
		var world := Sim.new()
		world.setup(82000 + index)
		world.begin_crash()
		world.search_kit()
		# At radius 7, the starter cat is out of reach on purpose.
		var visible7 := 0
		for cell: Vector2i in world.frozen_cats:
			if world.is_warm(cell):
				visible7 += 1
		if visible7 > 0:
			early += 1
		# Feed the fire its three stones: radius 9 must reach one.
		world.stones_in = Defs.OPENING_STONES
		world._refresh_radius()
		var visible9 := 0
		for cell: Vector2i in world.frozen_cats:
			if world.is_warm(cell) and world.can_lift(cell):
				visible9 += 1
		if visible9 < 1:
			short += 1
		world.free()
	_assert(early == 0, "반경 7에서는 아무 고양이도 닿지 않는다 (%d회 실패)" % early)
	_assert(short == 0, "반경 9에서는 첫 고양이가 반드시 닿는다 (%d회 실패)" % short)

# --- The painted circle trails the real one -----------------------------------

func _test_the_picture_follows_the_heat() -> void:
	_crash()
	var sim = main.sim
	_assert(is_equal_approx(sim.shown_radius, sim.warm_radius),
		"불시착 직후에는 그림과 규칙이 같다")
	sim.search_kit()
	_assert(sim.warm_radius > sim.shown_radius,
		"펼쳐진 순간 규칙은 앞서고 그림은 뒤에 있다 (%.1f < %.1f)"
		% [sim.shown_radius, sim.warm_radius])
	_assert(sim.is_warm(sim.core_cell), "그래도 그녀는 이미 안전하다 — 규칙이 먼저다")
	for _step in 300:
		sim.tick(1.0 / 30.0)
	_assert(absf(sim.shown_radius - sim.warm_radius) < 0.05,
		"몇 초 안에 그림이 따라잡는다 (%.2f)" % sim.shown_radius)
	# And a loaded game does not re-spread an old fire.
	var save: Dictionary = sim.to_save()
	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(save)
	_assert(is_equal_approx(fresh.shown_radius, fresh.warm_radius),
		"불러온 불은 다시 퍼지지 않는다")
	fresh.free()

# --- Helpers ------------------------------------------------------------------

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

# --- test_the_case_is_one_walk_away ------------------------------------------

## The case became the base, so the case's cell is the world anchor -- and she
## has to land somewhere else, or the opening is a game that begins with the
## player standing on the only object in it.
##
## Two hundred worlds, because "she can reach it" is the sort of promise that
## holds in every seed but the one a player opens.
func _test_the_case_is_one_walk_away() -> void:
	var far := 0
	var blocked := 0
	var moved := 0
	for index in 200:
		var world := Sim.new()
		world.setup(84000 + index)
		world.begin_crash()
		var land: Vector2i = world.core_cell
		var case_cell: Vector2i = world.kit_cell
		if Vector2(case_cell - land).length() > Defs.CRASH_SIGHT:
			far += 1
		if world.blocks_player(land):
			blocked += 1
		world.search_kit()
		if world.core_cell != case_cell:
			moved += 1
		world.free()
	_assert(far == 0, "상자는 언제나 첫 화면 안에 있다 (%d회 벗어남)" % far)
	_assert(blocked == 0, "착륙 지점은 언제나 설 수 있는 칸이다 (%d회 막힘)" % blocked)
	_assert(moved == 0, "기지는 언제나 상자의 칸에 선다 (%d회 어긋남)" % moved)
	# And the walk itself is unchanged: the same two-and-a-bit tiles the opening
	# has always budgeted, just measured from the other end.
	_assert(absf(Vector2(Defs.KIT_OFFSET).length() - sqrt(5.0)) < 0.01,
		"걷는 거리는 그대로다")

# --- test_a_new_recipe_raises_the_alert ---------------------------------------

## Every recipe the fire grows announces itself on the fire.
##
## Nothing here names shelter or pickaxe: the rule is the ledger, so a row added
## to `BASE_CRAFTS` next year is covered by this test without anyone editing it.
## Before this, the window quietly grew a shelter kit, then a pickaxe, then a
## torch, and the only way to find out was to walk over and press Z.
func _test_a_new_recipe_raises_the_alert() -> void:
	_crash()
	var sim = main.sim
	sim.search_kit()
	_assert(main.base_alert(), "기지가 서면 첫 제작법이 ! 를 세운다")
	var offered: Array[String] = main.base_offers()
	_assert(not offered.is_empty(), "창이 실제로 무언가를 들고 있다: %s" % str(offered))
	main._open_base_menu()
	main.close_base_menu()
	_assert(not main.base_alert(), "열어 보면 내려간다")
	# The next row appears; the "!" comes back on its own.
	sim.shelter_placed = true
	sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
	_assert(_craft_offered("pickaxe"), "숙소를 세우면 곡괭이 줄이 생긴다")
	_assert(main.base_alert(), "새 줄이 생기면 ! 가 다시 선다")
	main._open_base_menu()
	main.close_base_menu()
	_assert(not main.base_alert(), "그것도 열어 보면 내려간다")
	# A row she has already looked at never raises it twice, and neither does one
	# whose conditions merely stayed true for another frame.
	_run_seconds(1.0)
	_assert(not main.base_alert(), "같은 줄이 ! 를 두 번 세우지는 않는다")
	# And the ledger survives a save: reloading used to re-announce every recipe
	# in the window, which is the same lie as never announcing them.
	_assert(main.save_game(false), "저장된다")
	var seen_before: int = main.base_seen.size()
	main.base_seen.clear()
	_assert(main.load_game(), "다시 불러온다")
	_assert(main.base_seen.size() == seen_before,
		"본 것의 목록은 세이브를 건너온다 (%d/%d)" % [main.base_seen.size(), seen_before])
	_assert(not main.base_alert(), "불러와도 ! 가 되살아나지 않는다")
	main.clear_save()

func _craft_offered(id: String) -> bool:
	for row: Dictionary in main.base_rows():
		if String(row["kind"]) == "craft" \
				and String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]) == id:
			return true
	return false

func _drop_kind_exists(sim, kind: int) -> bool:
	for cell: Vector2i in sim.drops:
		if int(sim.drops[cell]) == kind:
			return true
	return false

func _clear_spot(sim) -> Vector2i:
	for radius in range(int(Defs.SHELTER_CLEARANCE) + 1, 7):
		for step in 16:
			var angle: float = TAU * float(step) / 16.0
			var cell: Vector2i = sim.core_cell + Vector2i(
				roundi(cos(angle) * float(radius)), roundi(sin(angle) * float(radius)))
			if sim.ore.has(cell) or sim.machines.has(cell) or sim.debris.has(cell):
				continue
			if Vector2(cell - sim.core_cell).length() <= Defs.SHELTER_CLEARANCE:
				continue
			return cell
	return sim.core_cell + Vector2i(-4, 0)
