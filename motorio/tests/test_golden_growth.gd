extends SceneTree

## The canonical 5~10 minutes, as contracts: the ladder's second rung costs six,
## the third circle holds two more cats on every world, the edge cat stays just
## past it, and a torch frees the ground without thawing the animal.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_base_lv3_cost_is_six()
	_test_second_ring_guarantees_two_cats()
	_test_edge_cat_remains_outside_heat_11()
	_test_torch_only_releases_ground_ice()
	if failures == 0:
		print("PASS test_golden_growth")
	else:
		print("FAIL test_golden_growth (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- test_base_lv3_cost_is_six ------------------------------------------------

func _test_base_lv3_cost_is_six() -> void:
	_assert(Defs.BASE_LEVEL_STEPS[0] == 3, "Lv1→Lv2 는 열석 3")
	_assert(Defs.BASE_LEVEL_STEPS[1] == 6, "Lv2→Lv3 는 열석 6 — 느린 고양이 한 마리 몫")
	_assert(int(Defs.BASE_LEVELS[2]["stones"]) == 9, "누적표도 같은 말을 한다 (9)")
	_assert(is_equal_approx(float(Defs.BASE_LEVELS[2]["radius"]), 11.0), "그리고 반경 11")
	# The ladder stays a ladder: every later step still climbs.
	for index in range(1, Defs.BASE_LEVEL_STEPS.size()):
		_assert(Defs.BASE_LEVEL_STEPS[index] > Defs.BASE_LEVEL_STEPS[index - 1],
			"칸값이 계속 오른다 (%d)" % index)

# --- test_second_ring_guarantees_two_cats --------------------------------------

func _test_second_ring_guarantees_two_cats() -> void:
	var short := 0
	var early := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(83000 + index)
		sim.begin_crash()
		sim.search_kit()
		# At Lv2 (radius 9) the pair is still out of reach...
		sim.stones_in = int(Defs.BASE_LEVELS[1]["stones"])
		sim._refresh_radius()
		var at9 := 0
		for cell: Vector2i in sim.frozen_cats:
			if sim.is_warm(cell):
				at9 += 1
		# ...one cat -- the starter -- and no more.
		if at9 > 1:
			early += 1
		# At Lv3 (radius 11) the circle holds the starter plus the pair.
		sim.stones_in = int(Defs.BASE_LEVELS[2]["stones"])
		sim._refresh_radius()
		var at11 := 0
		for cell: Vector2i in sim.frozen_cats:
			if sim.is_warm(cell) and sim.can_lift(cell):
				at11 += 1
		if at11 < 3:
			short += 1
		sim.free()
	_assert(early == 0, "반경 9에서는 시작 고양이 하나뿐이다 (%d회 실패)" % early)
	_assert(short == 0, "반경 11에는 셋이 있다 — 시작 하나 + 보장 둘 (%d회 실패)" % short)

# --- test_edge_cat_remains_outside_heat_11 --------------------------------------

func _test_edge_cat_remains_outside_heat_11() -> void:
	var inside := 0
	var missing := 0
	for index in 100:
		var sim := Sim.new()
		sim.setup(84000 + index)
		sim.begin_crash()
		sim.search_kit()
		sim.stones_in = int(Defs.BASE_LEVELS[2]["stones"])
		sim._refresh_radius()
		if sim.edge_frozen == Vector2i(9999, 9999):
			missing += 1
		elif sim.is_warm(sim.edge_frozen):
			inside += 1
		sim.free()
	_assert(missing == 0, "경계 고양이가 늘 있다 (%d회 실패)" % missing)
	_assert(inside == 0, "그리고 반경 11 바깥에 있다 — 닿을 뻔해야 한다 (%d회 실패)" % inside)

# --- test_torch_only_releases_ground_ice ----------------------------------------

func _test_torch_only_releases_ground_ice() -> void:
	var sim := Sim.new()
	sim.setup(85000)
	sim.begin_crash()
	sim.search_kit()
	var cell: Vector2i = sim.edge_frozen
	_assert(not sim.can_lift(cell), "온기 밖의 것은 들 수 없다")
	# The torch melts the ground under it, one frame at a time...
	var spent := 0.0
	while not sim.thaw_ground(cell, 1.0 / 30.0):
		spent += 1.0 / 30.0
		if spent > Defs.THAW_GROUND_SECONDS + 1.0:
			break
	_assert(absf(spent - Defs.THAW_GROUND_SECONDS) < 0.2,
		"바닥 얼음은 %.0f초 가열이다 (%.1f)" % [Defs.THAW_GROUND_SECONDS, spent])
	_assert(sim.can_lift(cell), "그러면 들 수 있게 된다")
	# ...but the animal itself is still frozen: only the fire's heat thaws it.
	_assert(sim.frozen_cats.has(cell), "고양이는 여전히 얼음 속이다")
	_assert(sim.cats.is_empty(), "토치만으로 깨어나는 고양이는 없다")
	_assert(not sim.can_thaw(cell), "그 자리에서는 해동도 시작되지 않는다")
	_assert(sim.pick_up_frozen(cell), "안아 들고")
	var home: Vector2i = sim.core_cell + Vector2i(1, 1)
	sim.machines.erase(home)
	sim.ore.erase(home)
	_assert(sim.put_down_frozen(home), "기지 곁에 내려놓으면")
	_assert(sim.can_thaw(home), "그때에야 녹기 시작한다")
	sim.free()
