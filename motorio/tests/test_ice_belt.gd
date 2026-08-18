extends SceneTree

## A block of ice on a conveyor rides it.
##
## Grim slides on a belt and so does everything a belt carries; the ice block was
## the exception, which reads as the belt running underneath it rather than as
## the belt being unable to shift it. It is the heaviest thing the player can put
## down, so it moves at the same speed as everything else -- and stops dead when
## the next cell is taken, because a belt that pushes a block through a wall is
## worse than one that cannot lift it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_it_rides()
	_test_it_stops()
	_test_it_stays_put_off_a_belt()
	if failures == 0:
		print("ICE_BELT: PASS")
	else:
		print("ICE_BELT: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _world() -> Sim:
	var sim := Sim.new()
	sim.setup(31337)
	sim.frozen_cats.clear()
	sim.debris.clear()
	return sim

## A short belt heading east, on cells cleared of everything the generator left.
func _belt(sim: Sim, from: Vector2i, length: int) -> void:
	for step in length:
		var cell: Vector2i = from + Vector2i(step, 0)
		sim.ore.erase(cell)
		sim.mined_rocks[cell] = true
		var belt := Sim.Machine.new()
		belt.type = Defs.M_BELT
		belt.cell = cell
		belt.dir = Vector2i.RIGHT
		sim.machines[cell] = belt

func _test_it_rides() -> void:
	var sim := _world()
	var start: Vector2i = sim.core_cell + Vector2i(4, 4)
	_belt(sim, start, 4)
	sim.frozen_cats[start] = 0.0
	# Long enough to cross a tile at the carrying speed, and no longer: a block
	# that arrives too early is one that skipped a cell.
	var seconds: float = float(Defs.TILE) / Defs.belt_carry_speed()
	var moved := false
	var elapsed := 0.0
	while elapsed < seconds * 1.2:
		sim._tick_frozen_drift(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if sim.frozen_cats.has(start + Vector2i(1, 0)):
			moved = true
			break
	_assert(moved, "벨트 위의 얼음이 한 칸 옮겨졌다 (%.2f초)" % elapsed)
	_assert(elapsed > seconds * 0.7, "그리고 순간이동이 아니다 (%.2f초 걸림)" % elapsed)
	# Between cells it is drawn between cells rather than snapped to the grid.
	var here: Vector2i = start + Vector2i(1, 0)
	sim._tick_frozen_drift(0.2)
	_assert(sim.frozen_at(here) != sim.cell_centre(here),
		"칸 사이에서는 칸 사이에 그려진다")
	sim.free()

func _test_it_stops() -> void:
	var sim := _world()
	var start: Vector2i = sim.core_cell + Vector2i(4, -4)
	_belt(sim, start, 3)
	sim.frozen_cats[start] = 0.0
	# A piece of the ship in the way, which is a thing that does not move -- a
	# second ice block would simply ride on ahead of this one, which is the belt
	# working rather than a test of what happens when it cannot.
	sim.debris[start + Vector2i(1, 0)] = 0
	for tick in 600:
		sim._tick_frozen_drift(1.0 / 60.0)
	_assert(sim.frozen_cats.has(start), "막히면 제자리에 선다")
	_assert(sim.frozen_cats.size() == 1 and sim.debris.size() == 1,
		"그리고 막은 것을 지우지 않는다")
	_assert(sim.frozen_at(start) == sim.cell_centre(start), "밀리다 만 자리에 걸치지도 않는다")

	# And the same when the thing in the way is another block that cannot move
	# either, which is what a queue on a belt actually looks like.
	sim.debris.clear()
	var tail: Vector2i = start + Vector2i(1, 0)
	sim.frozen_cats[tail] = 0.0
	sim.ore[start + Vector2i(2, 0)] = Defs.ITEM_HEATSTONE
	for tick in 600:
		sim._tick_frozen_drift(1.0 / 60.0)
	_assert(sim.frozen_cats.has(start) and sim.frozen_cats.has(tail),
		"줄줄이 막히면 둘 다 선다")
	_assert(sim.frozen_cats.size() == 2, "그리고 아무도 사라지지 않는다")
	sim.free()

func _test_it_stays_put_off_a_belt() -> void:
	var sim := _world()
	var cell: Vector2i = sim.core_cell + Vector2i(-4, 3)
	sim.frozen_cats[cell] = 0.0
	for tick in 300:
		sim._tick_frozen_drift(1.0 / 60.0)
	_assert(sim.frozen_cats.has(cell), "벨트가 없으면 움직이지 않는다")
	_assert(sim.frozen_at(cell) == sim.cell_centre(cell), "그리고 칸 한가운데 있다")
	sim.free()
