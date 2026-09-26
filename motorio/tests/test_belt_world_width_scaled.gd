extends SceneTree

## A belt is half as wide in the world as it was -- a cell, sixteen pixels --
## and everything it does is measured in the world, so none of that changed.
##
## An item crosses ten tiles in the time it always did, items ride as far apart
## as they always did, a line carries as many a second as it always did, and she
## is carried at the speed she always was. What the belt is drawn at is the one
## thing that halves.

const MachineLayerScript := preload("res://scripts/MachineLayer.gd")

var failures := 0

const SITE := Vector2i(36, -20)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_drawn_a_cell_across()
	_test_crossing_time()
	_test_throughput()
	if failures == 0:
		print("PASS test_belt_world_width_scaled")
	else:
		print("FAIL test_belt_world_width_scaled (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.unlocked[Defs.M_BELT] = true
	sim.stock[Defs.ITEM_COPPER] = 5000
	# Warm ground: a belt out in the cold runs at a fraction of its speed, which
	# is a rule about the fire, not about the grid.
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	return sim

## Clears a row and lays `length` belts from the base's east wall outward, all
## pointing home. Returns the tail cell.
func _line(sim: Sim, length: int) -> Vector2i:
	var base: Rect2i = sim.base_rect()
	var mouth := Vector2i(base.end.x, sim.core_cell.y)
	var rect := Rect2i(mouth - Vector2i(0, 2), Vector2i(length + 2, 5))
	for cell: Vector2i in Grid.cells_in(rect):
		sim.ore.erase(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	for index in length:
		sim.build(Defs.M_BELT, mouth + Vector2i(index, 0), Vector2i.LEFT)
	return mouth + Vector2i(length - 1, 0)

func _test_drawn_a_cell_across() -> void:
	var sim := _sim()
	var tail: Vector2i = _line(sim, 1)
	var span: Rect2 = Grid.rect_px(sim.machine_rect(sim.machine_at(tail)))
	_assert(span.size == Vector2(16.0, 16.0), "벨트는 월드에서 16px — 옛 32px 의 절반이다: %s" % span.size)
	_assert(is_equal_approx(MachineLayerScript._k(span.size.x), 0.5),
		"그림은 그 크기에 맞춰 절반 배율로 그려진다")
	sim.free()

## Ten tiles of belt -- twenty cells -- crossed at BELT_SPEED tiles a second.
func _test_crossing_time() -> void:
	var sim := _sim()
	var length: int = 10 * Grid.SCALE
	var tail: Vector2i = _line(sim, length)
	var before: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0))
	sim._push_into(tail, Defs.ITEM_HEATSTONE)
	var step := 0.02
	var elapsed := 0.0
	while int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) == before and elapsed < 120.0:
		sim.tick(step)
		elapsed += step
	var expected: float = 10.0 / Defs.BELT_SPEED
	_assert(absf(elapsed - expected) < 0.5,
		"열 칸(타일)을 %.1f초에 건넌다 — 옛날과 같다 (%.1f초)" % [expected, elapsed])
	sim.free()

## A full line delivers BELT_SPEED / BELT_GAP items a second, both written in
## tiles -- the rate it always had.
func _test_throughput() -> void:
	var sim := _sim()
	var tail: Vector2i = _line(sim, 8 * Grid.SCALE)
	var step := 0.02
	# Fill it, then count.
	for _tick in int(40.0 / step):
		sim._push_into(tail, Defs.ITEM_HEATSTONE)
		sim.tick(step)
	var before: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0))
	var window := 60.0
	for _tick in int(window / step):
		sim._push_into(tail, Defs.ITEM_HEATSTONE)
		sim.tick(step)
	var rate: float = float(int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) - before) / window
	var expected: float = Defs.BELT_SPEED / Defs.BELT_GAP
	_assert(absf(rate - expected) / expected < 0.08,
		"가득 찬 줄은 초당 %.2f개를 나른다 — 옛날과 같다 (%.2f개)" % [expected, rate])
	# Spacing, in pixels, between neighbours on the line.
	var positions: Array[float] = []
	for cell: Vector2i in Grid.cells_in(Rect2i(Vector2i(sim.base_rect().end.x, sim.core_cell.y),
			Vector2i(8 * Grid.SCALE, 1))):
		var belt: Sim.Machine = sim.machine_at(cell)
		for item: Dictionary in belt.items:
			# The belt runs west: t = 0 at the east edge of its cell.
			positions.append(Grid.origin(cell).x + float(Grid.CELL) * (1.0 - float(item["t"])))
	positions.sort()
	var tightest: float = 1e9
	for index in range(1, positions.size()):
		tightest = minf(tightest, positions[index] - positions[index - 1])
	_assert(positions.size() > 4, "줄 위에 물건이 여럿 있다 (%d)" % positions.size())
	_assert(tightest >= Grid.px(Defs.BELT_GAP) - 0.5,
		"물건 사이는 %.1fpx 이상 — 옛 간격 그대로 (%.1fpx)" % [Grid.px(Defs.BELT_GAP), tightest])
	sim.free()
