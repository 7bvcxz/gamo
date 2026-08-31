extends SceneTree

## Rock, which stopped being scenery and then stopped being.
##
## The boulder field was a pure function of the coordinates -- one clump seeded
## per block, grown to fill its own concavities. It is off as of 1.0.28 and
## stone with it, so what this file holds now is the *absence*: that the field
## is empty, and that a material with no source has no way to appear.
##
## The belt tests below never had anything to do with boulders. They carried
## stone because stone was the cheapest thing to put on a belt; they carry heat
## stone now and are unchanged otherwise.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_no_boulders()
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

# --- The field that is not there ---------------------------------------------

## Two independent systems grow the field: the simulation, which answers
## collision and mining, and the ground layer, which draws it. Both read
## `Defs.rock_clump`, so that one function is what this checks -- an assertion
## against `has_rock` alone would pass with boulders still painted on the snow.
func _test_no_boulders() -> void:
	var sim := Sim.new()
	sim.setup(4242)

	var clumped := 0
	for by in range(-6, 7):
		for bx in range(-6, 7):
			clumped += Defs.rock_clump(Vector2i(bx, by)).size()
	_assert(clumped == 0, "169개 블록 어디에도 바위 덩어리가 없다 (%d칸)" % clumped)

	var rocks := 0
	for y in range(-25, 25):
		for x in range(-25, 25):
			if sim.has_rock(Vector2i(x, y)):
				rocks += 1
	_assert(rocks == 0, "2500칸 어디에도 바위가 서 있지 않다 (%d칸)" % rocks)

	# And the material cannot arrive by the one route that made it. A seam still
	# yields its own ore, so this is "stone has no source" rather than "mining is
	# broken" -- the difference the seam assertion below is here to tell.
	var mined := 0
	for y in range(-12, 12):
		for x in range(-12, 12):
			var cell: Vector2i = sim.core_cell + Vector2i(x, y)
			if sim.ore.has(cell):
				continue
			if sim.hand_mine(cell, 99.0) == Defs.ITEM_STONE:
				mined += 1
	_assert(mined == 0, "곡괭이를 아무 데나 휘둘러도 돌은 나오지 않는다 (%d개)" % mined)

	var seam: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	_assert(sim.hand_mine(seam, Defs.HAND_MINE_PERIOD * 1.1) == int(sim.ore[seam]),
		"광맥은 그대로 자기 자원을 낸다")
	_assert(sim.ore.has(seam), "그리고 캐도 남는다")

	# Stone keeps its number even though nothing produces it: a save writes
	# materials by number and closing the gap would rename what old runs hold.
	_assert(Defs.ITEM_STONE == 3, "돌의 항목 번호는 그대로다")
	_assert(not Defs.COUNTED_ITEMS.has(Defs.ITEM_STONE), "다만 좌측 상단에서 세지 않는다")
	sim.free()

# --- A belt that ends in the open -------------------------------------------

func _test_belt_spill() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_COPPER] = 500
	var at: Vector2i = sim.core_cell + Vector2i(3, 3)
	var ahead: Vector2i = at + Vector2i.RIGHT
	sim.ore.erase(ahead)
	_assert(sim.build(Defs.M_BELT, at, Vector2i.RIGHT), "벨트를 놓는다")
	var belt: Sim.Machine = sim.machine_at(at)
	for index in 3:
		belt.items.append({"type": Defs.ITEM_HEATSTONE, "t": 1.0 - float(index) * 0.34})
	for _step in 60:
		sim.tick(0.1)
	_assert(sim.ground.has(ahead), "끝이 열려 있으면 앞 칸에 쏟는다")
	_assert(int(sim.ground[ahead]) == Defs.ITEM_HEATSTONE, "쏟은 것이 실려 있던 것이다")
	_assert(sim.ground_count(ahead) > 1, "그리고 쌓인다 (%d개)" % sim.ground_count(ahead))
	# Walking over a heap takes the heap. Picking up one of nine and walking off
	# and back on eight more times is not a mechanic.
	var piled: int = sim.ground_count(ahead)
	var before: int = int(sim.stock.get(Defs.ITEM_HEATSTONE, 0))
	_assert(sim.collect_ground_at(ahead) == Defs.ITEM_HEATSTONE, "밟으면 주워진다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == before + piled,
		"한 번에 무더기째 (%d개)" % piled)
	_assert(not sim.ground.has(ahead), "자리는 비워진다")
	sim.free()

# --- The cargo under her feet -----------------------------------------------

func _test_belt_pickup() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.stock[Defs.ITEM_COPPER] = 500
	var at: Vector2i = sim.core_cell + Vector2i(-3, -3)
	_assert(sim.build(Defs.M_BELT, at, Vector2i.RIGHT), "벨트를 놓는다")
	var belt: Sim.Machine = sim.machine_at(at)
	belt.items.append({"type": Defs.ITEM_HEATSTONE, "t": 0.2})
	belt.items.append({"type": Defs.ITEM_HEATSTONE, "t": 0.6})
	var before: int = int(sim.stock.get(Defs.ITEM_HEATSTONE, 0))
	_assert(sim.collect_belt_at(at) == Defs.ITEM_HEATSTONE, "벨트 위의 것도 주워진다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == before + 2, "실려 있던 만큼")
	_assert(belt.items.is_empty(), "벨트가 비워진다")
	_assert(sim.collect_belt_at(at) == -1, "빈 벨트에서는 아무것도 안 나온다")
	_assert(sim.collect_belt_at(sim.core_cell) == -1, "벨트가 아닌 곳에서도")
	sim.free()
