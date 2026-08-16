extends SceneTree

## The fire is fed by hand.
##
## The core used to burn everything that reached it. A heat stone a cat carried
## in was added to the stores *and* fed to the fire in the same call, so the same
## stone counted twice -- once on arrival, and again when the player pressed Z at
## the core and the stores went into the flames.
##
## The visible half of that was worse than the arithmetic: the circle grew while
## the player was somewhere else, doing something else. The one thing the whole
## game is about happened as a background event with a number attached, and by
## the time it was noticed there was nothing to do about it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_delivery_banks()
	_test_hand_feeds()
	_test_no_double_count()
	_test_picking_up_is_not_feeding()
	if failures == 0:
		print("FIRE: PASS")
	else:
		print("FIRE: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _lit() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.carried_kit = Defs.KIT_BASE
	sim.place_base(sim.core_cell)
	return sim

# --- What arrives is stored ---------------------------------------------------

func _test_delivery_banks() -> void:
	var sim := _lit()
	var heat_before: int = sim.total_heat
	var radius_before: float = sim.warm_radius
	# Enough to cross two thresholds if any of it burned on arrival.
	for index in 40:
		sim._deliver(Defs.ITEM_HEATSTONE, sim.core_cell)
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 40, "코어에 도착한 것은 창고에 쌓인다")
	_assert(sim.total_heat == heat_before, "그리고 불에 들어가지 않는다: %d" % sim.total_heat)
	_assert(is_equal_approx(sim.warm_radius, radius_before),
		"원은 그대로다: %.1f칸" % sim.warm_radius)
	# Ticking does not change its mind. The upgrade used to be re-derived every
	# frame, so anything that raised the total raised the circle on the next one.
	for _step in 60:
		sim.tick(0.1)
	_assert(is_equal_approx(sim.warm_radius, radius_before),
		"몇 초가 지나도 그대로다: %.1f칸" % sim.warm_radius)
	_assert(sim.base_level == 0, "기지 단계도 그대로다: %d" % sim.base_level)
	sim.free()

# --- Until she puts it in -----------------------------------------------------

func _test_hand_feeds() -> void:
	var sim := _lit()
	var radius_before: float = sim.warm_radius
	for index in 40:
		sim._deliver(Defs.ITEM_HEATSTONE, sim.core_cell)
	var moved: Dictionary = sim.deposit_fuel()
	_assert(int(moved.get(Defs.ITEM_HEATSTONE, 0)) == 40, "Z 한 번에 창고가 통째로 들어간다")
	_assert(sim.total_heat == 40 * Defs.ITEM_VALUES[Defs.ITEM_HEATSTONE],
		"열이 그때 오른다: %d" % sim.total_heat)
	_assert(sim.warm_radius > radius_before,
		"그리고 그때 원이 커진다: %.1f → %.1f칸" % [radius_before, sim.warm_radius])
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 0, "창고는 비워진다")
	_assert(sim.deposit_fuel().is_empty(), "빈 창고로 누르면 아무 일도 없다")
	sim.free()

# --- And only once ------------------------------------------------------------

func _test_no_double_count() -> void:
	var sim := _lit()
	sim._deliver(Defs.ITEM_HEATSTONE, sim.core_cell)
	sim.deposit_fuel()
	_assert(sim.total_heat == Defs.ITEM_VALUES[Defs.ITEM_HEATSTONE],
		"고양이가 나른 열석 하나는 열 %d다: %d"
			% [Defs.ITEM_VALUES[Defs.ITEM_HEATSTONE], sim.total_heat])
	sim.free()

# --- Bending down is not feeding either ---------------------------------------

func _test_picking_up_is_not_feeding() -> void:
	var sim := _lit()
	var cell: Vector2i = sim.core_cell + Vector2i(4, 4)
	sim.ore.erase(cell)
	sim.drop_item(cell, Defs.ITEM_ENERGY)
	sim.drop_item(cell, Defs.ITEM_ENERGY)
	var before: int = sim.total_heat
	_assert(sim.collect_ground_at(cell) == Defs.ITEM_ENERGY, "바닥의 에너지결정을 줍는다")
	_assert(sim.total_heat == before, "줍는 것으로는 불이 커지지 않는다: %d" % sim.total_heat)
	_assert(int(sim.stock.get(Defs.ITEM_ENERGY, 0)) == 2, "가방에 들어간다")
	sim.free()
