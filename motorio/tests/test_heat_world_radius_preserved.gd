extends SceneTree

## The warm circle is the same ground at every rung of the ladder.
##
## Its radius is written in tiles and measured in world pixels from the middle
## of the base, and Grid v2 changed neither: at every level, a point one pixel
## inside the old circle is warm and one pixel outside is not, in every
## direction, and the cells counted warm cover the circle's area.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_every_level()
	_test_cells_cover_the_circle()
	_test_before_the_fire()
	if failures == 0:
		print("PASS test_heat_world_radius_preserved")
	else:
		print("FAIL test_heat_world_radius_preserved (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_every_level() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var centre: Vector2 = sim.core_centre()
	_assert(centre == Vector2(16.0, 16.0), "원의 중심은 옛 코어 칸의 가운데다")
	var wrong := 0
	for level in Defs.BASE_LEVELS.size():
		var row: Dictionary = Defs.BASE_LEVELS[level]
		sim.stones_in = int(row["stones"])
		sim._refresh_radius()
		var tiles: float = float(row["radius"])
		if not is_equal_approx(sim.warm_radius, tiles):
			wrong += 1
			print("    Lv%d: %.2f vs %.2f" % [level + 1, sim.warm_radius, tiles])
		# In pixels, written against the old 32-pixel cell by hand.
		var edge: float = tiles * 32.0
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5, PI * 0.25, PI * 1.3]:
			var heading := Vector2.from_angle(angle)
			if not sim.is_warm_at(centre + heading * (edge - 1.0)):
				wrong += 1
			if sim.is_warm_at(centre + heading * (edge + 1.0)):
				wrong += 1
		if not is_equal_approx(Defs.warm_radius_cells(int(row["stones"])), tiles * 2.0):
			wrong += 1
	_assert(wrong == 0, "%d단계 모두 온기 반경이 옛 픽셀 그대로다 (%d건 어긋남)"
		% [Defs.BASE_LEVELS.size(), wrong])
	_assert(is_equal_approx(Grid.px(Defs.WARM_BASE), 224.0), "첫 원은 224px")
	_assert(is_equal_approx(Grid.px(Defs.warm_radius(int(Defs.BASE_LEVELS[-1]["stones"]))), 3200.0),
		"마지막 원은 3200px (100칸)")
	sim.free()

## Warm cells, each a quarter of the old cell's area: together they cover the
## circle's area, and none of them lies outside it.
func _test_cells_cover_the_circle() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	for level: int in [0, 4, 9]:
		sim.stones_in = int(Defs.BASE_LEVELS[level]["stones"])
		sim._refresh_radius()
		var radius_px: float = Grid.px(sim.warm_radius)
		var reach: int = int(ceil(Defs.warm_radius_cells(sim.stones_in))) + 2
		var warm := 0
		var outside := 0
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell: Vector2i = sim.core_cell + Vector2i(dx, dy)
				if not sim.is_warm(cell):
					continue
				warm += 1
				if Grid.centre(cell).distance_to(sim.core_centre()) > radius_px:
					outside += 1
		var area: float = float(warm) * float(Grid.CELL * Grid.CELL)
		var circle: float = PI * radius_px * radius_px
		_assert(absf(area - circle) / circle < 0.04,
			"Lv%d: 따뜻한 칸의 넓이가 원의 넓이다 (%.0f vs %.0f px²)" % [level + 1, area, circle])
		_assert(outside == 0, "Lv%d: 원 밖의 칸은 따뜻하지 않다" % (level + 1))
	sim.free()

## Before the case unfolds there is no fire: what she can see is CRASH_SIGHT
## tiles around where she is, in the same pixels as before.
func _test_before_the_fire() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.begin_crash()
	_assert(is_equal_approx(sim.warm_radius, Defs.CRASH_SIGHT), "추락 직후 시야는 CRASH_SIGHT 칸이다")
	_assert(not sim.is_warm_at(sim.core_centre()), "불이 없으니 따뜻한 곳도 없다")
	sim.search_kit()
	_assert(sim.is_warm_at(sim.core_centre()), "상자가 펼쳐지면 불이 선다")
	_assert(is_equal_approx(sim.warm_radius, Defs.WARM_BASE), "첫 원 7칸")
	sim.free()
