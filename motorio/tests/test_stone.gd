extends SceneTree

## Rock, which stopped being scenery.
##
## The boulder field is a pure function of the coordinates -- one clump seeded
## per block, grown to fill its own concavities -- and it always was. What
## changed is that the simulation can now answer "is one standing here", which
## it could not while the generator lived inside a drawing layer, and that a
## broken one is remembered rather than removed: there is nothing to remove from,
## because the field is regenerated from the coordinates every time it is asked.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_field()
	_test_breaking_one()
	_test_belt_spill()
	_test_belt_pickup()
	if failures == 0:
		print("PASS test_stone")
	else:
		print("FAIL test_stone (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _find_rock(sim: Sim) -> Vector2i:
	for y in range(-30, 30):
		for x in range(-30, 30):
			var cell := Vector2i(x, y)
			if sim.has_rock(cell):
				return cell
	return Vector2i(9999, 9999)

# --- The field --------------------------------------------------------------

func _test_field() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	# About a twentieth of the ground. Counted rather than trusted, because the
	# generator moved between files and a move is where a field quietly empties.
	var rocks := 0
	for y in range(-25, 25):
		for x in range(-25, 25):
			if sim.has_rock(Vector2i(x, y)):
				rocks += 1
	var share: float = float(rocks) / 2500.0
	_assert(share > 0.02 and share < 0.12, "바닥의 %.1f%%가 바위다" % (share * 100.0))
	# Same answer every time it is asked, from the coordinates alone -- there is
	# no stored field to disagree with.
	var other := Sim.new()
	other.setup(99999)
	var same := true
	for y in range(-8, 8):
		for x in range(-8, 8):
			if sim.has_rock(Vector2i(x, y)) != other.has_rock(Vector2i(x, y)):
				same = false
	_assert(same, "바위 자리는 시드와 무관하게 좌표로 정해진다")
	# And never under a seam or a machine, which would be a boulder nobody can
	# reach standing on a resource nobody can mine.
	var clash := 0
	for cell: Vector2i in sim.ore:
		if sim.has_rock(cell):
			clash += 1
	_assert(clash == 0, "광맥 위에는 바위가 없다")
	sim.free()
	other.free()

# --- Breaking one -----------------------------------------------------------

func _test_breaking_one() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var rock: Vector2i = _find_rock(sim)
	_assert(rock != Vector2i(9999, 9999), "바위를 찾았다")
	_assert(sim.can_hand_mine(rock), "곡괭이로 칠 수 있다")
	# Slower than a seam. A rock is a rock, and the gap is what makes walking to
	# a seam worth the walk.
	_assert(sim.hand_period(rock) > sim.hand_period(sim.core_cell + Sim.STARTER_PATCH[0]),
		"바위가 광맥보다 오래 걸린다")

	_assert(sim.hand_mine(rock, sim.hand_period(rock) * 0.5) < 0, "반쯤은 아무것도 안 나온다")
	_assert(sim.hand_fraction() > 0.3 and sim.hand_fraction() < 0.7,
		"진행 고리가 절반쯤이다 (%.2f)" % sim.hand_fraction())
	_assert(sim.hand_mine(rock, sim.hand_period(rock) * 0.6) == Defs.ITEM_STONE,
		"한 번 다 치면 돌이 나온다")
	# And it is gone -- unlike a seam, which stays.
	_assert(not sim.has_rock(rock), "바위는 사라진다")
	_assert(not sim.can_hand_mine(rock), "그리고 더 칠 수 없다")
	_assert(sim.mined_rocks.has(rock), "깬 자리로 기억된다")
	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 1.1)
	_assert(sim.ore.has(seam), "광맥은 캐도 남는다")
	sim.free()

# --- A belt that ends in the open -------------------------------------------

func _test_belt_spill() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_COPPER] = 500
	var at := Vector2i(18, 18)
	var ahead: Vector2i = at + Vector2i.RIGHT
	sim.ore.erase(ahead)
	sim.mined_rocks[ahead] = true
	_assert(sim.build(Defs.M_BELT, at, Vector2i.RIGHT), "벨트를 놓는다")
	var belt: Sim.Machine = sim.machine_at(at)
	for index in 3:
		belt.items.append({"type": Defs.ITEM_STONE, "t": 1.0 - float(index) * 0.34})
	for _step in 60:
		sim.tick(0.1)
	_assert(sim.ground.has(ahead), "끝이 열려 있으면 앞 칸에 쏟는다")
	_assert(int(sim.ground[ahead]) == Defs.ITEM_STONE, "쏟은 것이 실려 있던 것이다")
	_assert(sim.ground_count(ahead) > 1, "그리고 쌓인다 (%d개)" % sim.ground_count(ahead))
	# Walking over a heap takes the heap. Picking up one of nine and walking off
	# and back on eight more times is not a mechanic.
	var piled: int = sim.ground_count(ahead)
	var before: int = int(sim.stock.get(Defs.ITEM_STONE, 0))
	_assert(sim.collect_ground_at(ahead) == Defs.ITEM_STONE, "밟으면 주워진다")
	_assert(int(sim.stock.get(Defs.ITEM_STONE, 0)) == before + piled,
		"한 번에 무더기째 (%d개)" % piled)
	_assert(not sim.ground.has(ahead), "자리는 비워진다")
	sim.free()

# --- The cargo under her feet -----------------------------------------------

func _test_belt_pickup() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_COPPER] = 500
	var at := Vector2i(-18, -18)
	_assert(sim.build(Defs.M_BELT, at, Vector2i.RIGHT), "벨트를 놓는다")
	var belt: Sim.Machine = sim.machine_at(at)
	belt.items.append({"type": Defs.ITEM_STONE, "t": 0.2})
	belt.items.append({"type": Defs.ITEM_STONE, "t": 0.6})
	var before: int = int(sim.stock.get(Defs.ITEM_STONE, 0))
	_assert(sim.collect_belt_at(at) == Defs.ITEM_STONE, "벨트 위의 것도 주워진다")
	_assert(int(sim.stock.get(Defs.ITEM_STONE, 0)) == before + 2, "실려 있던 만큼")
	_assert(belt.items.is_empty(), "벨트가 비워진다")
	_assert(sim.collect_belt_at(at) == -1, "빈 벨트에서는 아무것도 안 나온다")
	_assert(sim.collect_belt_at(sim.core_cell) == -1, "벨트가 아닌 곳에서도")
	sim.free()
