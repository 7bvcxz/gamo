extends SceneTree

## A belt is one cell. Four of them fit where one used to, a line can turn in
## half the room, and a belt is still floor: she walks on it and it carries her.

var failures := 0

const SITE := Vector2i(36, -20)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_size_is_data()
	_test_four_in_an_old_tile()
	_test_a_line_delivers()
	if failures == 0:
		print("PASS test_belt_is_1x1")
	else:
		print("FAIL test_belt_is_1x1 (%d)" % failures)
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
	sim.unlocked[Defs.M_SPLITTER] = true
	for item: int in [Defs.ITEM_CRYSTAL, Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 5000
	# Warm ground: a belt out in the cold runs at a fraction of its speed, which
	# is a rule about the fire, not about the grid.
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.ore.erase(cell)
		var machine: Sim.Machine = sim.machine_at(cell)
		if machine != null and machine.type != Defs.M_CORE:
			sim.remove_machine(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)

func _test_size_is_data() -> void:
	_assert(Defs.machine_size(Defs.M_BELT) == Vector2i.ONE, "벨트는 표에서 1x1 이다")
	_assert(Defs.machine_size(Defs.M_SPLITTER) == Vector2i.ONE, "분배기도 1x1 이다")
	_assert(Defs.machine_footprint(Defs.M_BELT, Vector2i(3, 4), Vector2i.UP) == Rect2i(3, 4, 1, 1),
		"어느 방향이든 자기 칸 하나다")

## A two-by-two loop of belts where one belt used to stand.
func _test_four_in_an_old_tile() -> void:
	var sim := _sim()
	var tile: Rect2i = Grid.tile_rect(Grid.tile_of(sim.core_cell + SITE))
	_clear(sim, tile.grow(4))
	var p: Vector2i = tile.position
	var loop: Array = [[p, Vector2i.RIGHT], [p + Vector2i(1, 0), Vector2i.DOWN],
		[p + Vector2i(1, 1), Vector2i.LEFT], [p + Vector2i(0, 1), Vector2i.UP]]
	for entry: Array in loop:
		_assert(sim.build(Defs.M_BELT, entry[0], entry[1]), "%s 에 벨트" % entry[0])
	var distinct: Dictionary = {}
	for cell: Vector2i in Grid.cells_in(tile):
		var belt: Sim.Machine = sim.machine_at(cell)
		if belt != null and belt.cell == cell:
			distinct[belt] = true
	_assert(distinct.size() == 4, "옛 한 칸 자리에 벨트 네 개가 각자 선다 (%d)" % distinct.size())
	for cell: Vector2i in Grid.cells_in(tile):
		_assert(not sim.blocks_player(cell), "벨트 칸 %s 은 밟고 지나간다" % cell)
		_assert(sim.belt_drift(cell).length() > 0.0, "그리고 발밑을 끈다 %s" % cell)
	_assert(sim.belt_drift(tile.position + Vector2i(2, 0)) == Vector2.ZERO, "벨트 바깥 칸은 끌지 않는다")
	# An item put on it goes round the loop, one cell at a time.
	var head: Sim.Machine = sim.machine_at(p)
	head.items.append({"type": Defs.ITEM_HEATSTONE, "t": 0.0})
	var visited: Dictionary = {}
	for _tick in 200:
		sim.tick(0.05)
		for entry: Array in loop:
			if not sim.machine_at(entry[0]).items.is_empty():
				visited[entry[0]] = true
	_assert(visited.size() == 4, "물건이 네 칸을 차례로 돈다 (%d)" % visited.size())
	sim.free()

## A straight line of belts into the base delivers what is put on its tail,
## and holds no more per cell than fits at the item spacing.
func _test_a_line_delivers() -> void:
	var sim := _sim()
	var base: Rect2i = sim.base_rect()
	var mouth := Vector2i(base.end.x, sim.core_cell.y)
	var length := 20
	_clear(sim, Rect2i(mouth - Vector2i(0, 2), Vector2i(length + 2, 5)))
	for index in length:
		sim.build(Defs.M_BELT, mouth + Vector2i(index, 0), Vector2i.LEFT)
	var tail: Sim.Machine = sim.machine_at(mouth + Vector2i(length - 1, 0))
	_assert(tail != null and tail.type == Defs.M_BELT, "스무 칸 줄이 선다")
	var before: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0))
	var fed := 0
	var most := 0
	for _tick in 1200:
		if sim._push_into(tail.cell, Defs.ITEM_HEATSTONE):
			fed += 1
		sim.tick(0.05)
		for index in length:
			most = maxi(most, sim.machine_at(mouth + Vector2i(index, 0)).items.size())
	var arrived: int = int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) - before
	_assert(arrived > 0, "끝에서 넣은 열석이 기지에 닿는다 (%d개)" % arrived)
	_assert(fed - arrived <= length * Defs.belt_cell_capacity(), "벨트 위에 남은 것 말고는 모두 닿는다")
	_assert(most <= Defs.belt_cell_capacity(), "한 칸에 %d개를 넘게 싣지 않는다 (%d)"
		% [Defs.belt_cell_capacity(), most])
	sim.free()
