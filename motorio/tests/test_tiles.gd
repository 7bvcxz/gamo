extends SceneTree

## Tile attributes describe the terrain itself. STRUCTURE is the first one: it
## blocks the player's body and refuses to be picked up.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim := Sim.new()
	sim.setup(24680)

	# Ore is terrain, and terrain is walked over. A seam is a floor tile with a
	# crystal painted into it, not an obstacle standing on the floor, and the
	# player crosses it the way they cross snow.
	var ore_cell: Vector2i = sim.ore.keys()[0]
	_assert(not sim.is_structure(ore_cell), "광맥은 구조물이 아니다")
	_assert(not sim.has_attribute(ore_cell, Defs.ATTR_STRUCTURE), "구조물 비트가 없다")
	_assert(not sim.blocks_player(ore_cell), "광맥 위를 걸어갈 수 있다")

	# Bare ground north of the base, in the column the generator keeps clear
	# (Grid v2: the base covers eight cells round the core).
	var empty := Vector2i(1, -6)
	_assert(not sim.is_structure(empty), "bare ground is not a structure")
	_assert(not sim.blocks_player(empty), "bare ground does not block")

	# Every machine is a solid object except the two that are floor. A belt is
	# laid *along* a route -- the whole point of one is to run between places
	# rather than to stand between them -- and a splitter is a belt with a fork
	# in it. Everything else is a drill or a furnace, and walking through the
	# middle of a furnace is what a picture of one already forbids.
	#
	# Checked as a table over every buildable type rather than as the two cases
	# that were interesting today, because the rule is "which of these can I walk
	# on" and a machine added later has to answer it too.
	_open(sim)
	for kind: int in Defs.BUILDABLE:
		var spot: Vector2i = sim.core_cell + Vector2i(9, 9) * Grid.SCALE
		# The whole footprint cleared, since footprints are more than a cell now.
		var rect: Rect2i = Defs.machine_footprint(kind, spot)
		for covered: Vector2i in Grid.cells_in(rect):
			sim.remove_machine(covered)
			sim.ore.erase(covered)
		for props: Dictionary in [sim.frozen_cats, sim.debris]:
			for origin: Vector2i in props.keys():
				if sim.prop_rect(origin).intersects(rect):
					props.erase(origin)
		if Defs.machine_mines(kind):
			sim.ore[spot] = Defs.ITEM_CRYSTAL
		sim.unlocked[kind] = true
		_assert(sim.build(kind, spot, Vector2i.RIGHT), "%s를 세운다" % Defs.MACHINE_NAMES[kind])
		var walkable: bool = kind in Defs.WALKABLE_MACHINES
		# Every cell of the footprint answers the same way.
		for covered: Vector2i in Grid.cells_in(rect):
			_assert(sim.blocks_player(covered) != walkable,
				"%s %s: 통행 %s" % [Defs.MACHINE_NAMES[kind], str(covered - spot),
					"가능" if walkable else "불가"])
		sim.remove_machine(spot)
		sim.ore.erase(spot)
	_assert(Defs.M_BELT in Defs.WALKABLE_MACHINES and Defs.M_SPLITTER in Defs.WALKABLE_MACHINES,
		"걸어갈 수 있는 것은 벨트와 분배기뿐이다")
	_assert(Defs.WALKABLE_MACHINES.size() == 2, "그 둘뿐이다")
	sim.build(Defs.M_BELT, empty, Vector2i.RIGHT)
	_assert(not sim.blocks_player(empty), "a belt does not block the player")

	# The core is the exception: it is a building, so it stops the body.
	_assert(sim.is_structure(sim.core_cell), "the core is a structure")
	_assert(sim.blocks_player(sim.core_cell), "the core blocks the player")
	_assert(sim.tile_attributes(sim.core_cell) & Defs.ATTR_STRUCTURE,
		"the core carries the structure bit")
	_assert(not sim.demolish(sim.core_cell), "the core cannot be picked up")

	# And the miner takes over what the seam gave up. Building one is the game's
	# central placement, and once it is standing there the cell is a machine
	# rather than ground -- so the tile that was walkable a moment ago stops
	# being walkable, and picking the machine back up hands it over again.
	var seam: Vector2i = Vector2i(9999, 9999)
	sim.unlocked[Defs.M_MINER] = true
	for cell: Vector2i in sim.ore:
		if sim.machine_at(cell) == null and sim.can_build(Defs.M_MINER, cell, Vector2i(0, -1)) == "":
			seam = cell
			break
	_assert(seam != Vector2i(9999, 9999), "빈 광맥이 있다")
	_assert(not sim.blocks_player(seam), "설치 전에는 지나갈 수 있다")
	sim.unlocked[Defs.M_MINER] = true
	_assert(sim.build(Defs.M_MINER, seam, Vector2i(0, -1)), "광맥 위에 채굴기를 세운다")
	_assert(sim.blocks_player(seam), "채굴기가 선 칸은 지나갈 수 없다")
	_assert(sim.demolish(seam), "채굴기는 회수할 수 있다")
	_assert(not sim.blocks_player(seam), "회수하면 다시 지나갈 수 있다")
	_assert(sim.machine_at(sim.core_cell) != null, "the core survives the attempt")

	# The shelter is a building on the grid too, so it blocks and cannot be built
	# over. It also has to stay reachable: a hut you cannot stand next to is a hut
	# you can never sleep in.
	_assert(sim.is_structure(sim.shelter_cell), "the shelter is a structure")
	_assert(sim.blocks_player(sim.shelter_cell), "the shelter blocks the player")
	_assert(sim.shelter_cell != sim.core_cell, "and it is its own tile, not the core's")
	# Past each wall, in the anchor's line (Grid v2: the hut is six cells by eight).
	var open_sides := 0
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not sim.blocks_player(Grid.front_cell(sim.shelter_rect(), step, sim.shelter_cell)):
			open_sides += 1
	_assert(open_sides >= 2, "the shelter has approaches on at least two sides (%d)" % open_sides)

	# The food bin, for the same reason: it is a crate of fish standing in the
	# snow and the player used to walk straight through the picture of it. Cats
	# path by position rather than by this, so the bowl stays reachable to the
	# ones that actually eat from it -- checked, because a bin nobody can get to
	# starves the crew and looks like a pathing bug.
	#
	# It has to be built first. A run starts without one: a feeding station four
	# days before any cat is hungry is a solution parked next to a problem that
	# has not happened.
	_assert(not sim.food_placed, "새 세계에는 밥통이 없다")
	_assert(not sim.blocks_player(sim.food_cell), "없는 밥통은 길을 막지 않는다")
	sim.stock[Defs.ITEM_HEATSTONE] = 20
	_assert(sim.craft_food_bin(), "기지에서 만든다")
	var bin_at := Vector2i(9999, 9999)
	for drop_cell: Vector2i in sim.drops:
		if int(sim.drops[drop_cell]) == Sim.DROP_FOOD_BIN:
			bin_at = drop_cell
	_assert(sim.collect_drop(bin_at) == Sim.DROP_FOOD_BIN, "그리고 주워서")
	_assert(sim.place_food_bin(_bin_spot(sim)), "내려놓는다")
	_assert(sim.is_structure(sim.food_cell), "밥통은 구조물이다")
	_assert(sim.blocks_player(sim.food_cell), "밥통은 플레이어를 막는다")
	_assert(sim.food_cell != sim.shelter_cell and sim.food_cell != sim.core_cell,
		"밥통은 자기 칸을 가진다")
	var bin_sides := 0
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not sim.blocks_player(Grid.front_cell(sim.food_rect(), step, sim.food_cell)):
			bin_sides += 1
	_assert(bin_sides >= 2, "밥통에 두 방향 이상으로 접근할 수 있다 (%d)" % bin_sides)

	# Where each machine may go. The miner is the only one that may sit on ore,
	# and the only one that is required to.
	ore_cell = seam
	_assert(sim.can_build(Defs.M_MINER, ore_cell) == "", "a miner may be built on ore")
	_assert(sim.can_build(Defs.M_MINER, empty) != "", "a miner may not be built off ore")
	_assert(sim.can_build(Defs.M_BELT, ore_cell) != "", "a belt may not be built on ore")
	_assert(sim.can_build(Defs.M_GENERATOR, ore_cell) != "", "a furnace may not be built on ore")
	_assert(sim.can_build(Defs.M_BELT, sim.core_cell) != "", "nothing may be built on the core")

	# And the consequence of the two rules meeting: because a miner always sits
	# on ore, and ore is a structure, its tile keeps blocking the player.
	_assert(sim.build(Defs.M_MINER, ore_cell, Vector2i.RIGHT), "the miner is placed on the ore")
	_assert(sim.blocks_player(ore_cell), "a miner on ore still blocks the player")

	# Attributes are flags, so the system can carry more than one later.
	_assert(Defs.ATTR_NONE == 0, "the empty attribute set is zero")
	_assert(Defs.ATTR_STRUCTURE != 0, "structure is a real flag")
	_assert(sim.tile_attributes(empty) == Defs.ATTR_NONE, "bare ground has no attributes")
	_assert(sim.tile_attributes(ore_cell) & Defs.ATTR_STRUCTURE, "ore carries the structure bit")
	sim.free()

	# The player's body must not be able to enter a structure from any side.
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# A fixed seed, because the world is generated from a random one and this test
	# needs a seam with three clear tiles on all four sides. Most maps have one;
	# some do not, and the test failed about one run in ten on nothing but the
	# roll. A flaky test is worse than no test -- it teaches you to re-run.
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.sim.setup(4242)
	# Ore generates in clusters, so pick a seam whose approaches are clear or the
	# test would be starting the player inside a different structure.
	var target := Vector2i(9999, 9999)
	for cell: Vector2i in main.sim.ore:
		var clear := true
		for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for distance in [1, 2, 3]:
				var probe: Vector2i = cell - Vector2i(approach) * distance
				if main.sim.is_structure(probe):
					clear = false
		if clear:
			target = cell
			break
	_assert(target != Vector2i(9999, 9999), "the map has a seam with clear approaches")
	var centre: Vector2 = main.sim.cell_centre(target)
	for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		main.player.position = centre - approach * Grid.px(2.0)
		var before: Vector2 = main.player.position
		for step in 40:
			main.player._move(approach * 6.0)
		var cell: Vector2i = Grid.cell_at(main.player.position)
		_assert(cell != target, "the player cannot walk into a structure from %s" % approach)
		_assert(main.player.position.distance_to(before) > 1.0,
			"the player still moved toward it from %s" % approach)

	# Sliding: pushing diagonally into a wall should still travel along it.
	main.player.position = centre + Vector2(0, Grid.px(2.0))
	var start_x: float = main.player.position.x
	for step in 30:
		main.player._move(Vector2(4.0, -4.0))
	_assert(main.player.position.x > start_x + 5.0, "the player slides along a structure instead of sticking")

	# Walking into the core. The starting ore sits directly south of it, so the
	# approach has to be chosen from a side that is actually clear -- otherwise
	# the test would be proving that ore blocks, which it already knows.
	# Grid v2: the base is eight cells by eight, so an approach is the three cells
	# past one of its walls in the core's line, and "into the core" is into any
	# cell of it.
	var core: Vector2i = main.sim.core_cell
	var base: Rect2i = main.sim.base_rect()
	var lane := Vector2.ZERO
	var door := Vector2i.ZERO
	for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var outside: Vector2i = Grid.front_cell(base, -Vector2i(approach), core)
		var clear := true
		for distance in [0, 1, 2]:
			if main.sim.is_structure(outside - Vector2i(approach) * distance):
				clear = false
		if clear:
			lane = approach
			door = outside
			break
	_assert(lane != Vector2.ZERO, "the core has at least one clear approach")
	main.player.position = main.sim.cell_centre(door) - lane * Grid.px(2.0)
	var approached_from: Vector2 = main.player.position
	for step in 40:
		main.player._move(lane * 6.0)
	_assert(not base.has_point(main.player.cell()), "the player cannot walk into the core")
	_assert(main.player.position.distance_to(approached_from) > 1.0,
		"but does travel up to it")

	# Walking into the shelter. Same real-movement check as the core: the hut is a
	# building now, so the body has to stop at its wall.
	var hut: Vector2i = main.sim.shelter_cell
	var walls: Rect2i = main.sim.shelter_rect()
	var hut_lane := Vector2.ZERO
	var hut_door := Vector2i.ZERO
	for approach: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var outside: Vector2i = Grid.front_cell(walls, -Vector2i(approach), hut)
		var clear := true
		for distance in [0, 1, 2]:
			if main.sim.is_structure(outside - Vector2i(approach) * distance):
				clear = false
		if clear:
			hut_lane = approach
			hut_door = outside
			break
	_assert(hut_lane != Vector2.ZERO, "the shelter has a clear approach")
	main.player.position = main.sim.cell_centre(hut_door) - hut_lane * Grid.px(2.0)
	var walked_from: Vector2 = main.player.position
	for step in 40:
		main.player._move(hut_lane * 6.0)
	_assert(not walls.has_point(main.player.cell()), "the player cannot walk into the shelter")
	_assert(main.player.position.distance_to(walked_from) > 1.0, "but does walk up to its door")
	_assert(main.shelter_nearby(), "and standing at the wall is close enough to sleep")

	# A save written before a tile became a structure can drop the player inside
	# one. Collision must let them walk out rather than sealing them in.
	main.player.position = main.sim.cell_centre(main.sim.core_cell)
	_assert(main.sim.blocks_player(main.player.cell()), "the player starts inside the core")
	var trapped_at: Vector2 = main.player.position
	for step in 40:
		main.player._move(Vector2(0.0, 6.0))
	_assert(main.player.position.distance_to(trapped_at) > float(Grid.TILE),
		"a player inside a structure can walk back out")
	_assert(not main.sim.blocks_player(main.player.cell()), "and ends up on free ground")

	# Having escaped, normal collision applies again.
	var settled: Vector2 = main.player.position
	for step in 40:
		main.player._move(Vector2(0.0, -6.0))
	_assert(main.player.position.y < settled.y, "the player can move back toward the core")
	_assert(not main.sim.blocks_player(main.player.cell()),
		"but cannot re-enter it now that collision is live again")

	_test_reserved_tiles_across_seeds()

	if failures == 0:
		print("TILES_TEST: PASS")
	quit(failures)

## The shelter doorstep is where the player is put down every single morning, and
## the food bin is where cats queue. Ore is scattered from the seed, so a bad roll
## only ruins some worlds -- which is why this sweeps seeds rather than checking
## one. It was found as a sibling test failing about one run in five, the shape a
## seeded-world bug always takes: the map is different every run and most maps
## are fine.
##
## What is guarded is scatter landing where it must not, so the bin is checked
## for ore rather than for blocking: the bin blocks on purpose now -- it is a
## crate of fish standing in the snow -- and asserting it stays walkable would
## turn a deliberate rule into a permanent failure. Its approaches are what
## matter, since cats queue at it and the player has to get past it.
func _test_reserved_tiles_across_seeds() -> void:
	var blocked: Array[String] = []
	var walled: Array[String] = []
	for seed_value in range(300):
		var sim := Sim.new()
		sim.setup(seed_value)
		if sim.blocks_player(Grid.cell_at(sim.shelter_doorstep())):
			blocked.append("seed %d 문 앞" % seed_value)
		for covered: Vector2i in Grid.cells_in(sim.food_rect()):
			if sim.ore.has(covered):
				blocked.append("seed %d 밥통에 광맥" % seed_value)
				break
		var open_sides := 0
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not sim.blocks_player(Grid.front_cell(sim.food_rect(), step, sim.food_cell)):
				open_sides += 1
		if open_sides < 2:
			walled.append("seed %d (%d면)" % [seed_value, open_sides])
		sim.free()
	_assert(blocked.is_empty(),
		"문 앞은 걸을 수 있고 밥통 칸에 광맥이 없다. 위반 %d: %s"
		% [blocked.size(), ", ".join(blocked.slice(0, 4))])
	_assert(walled.is_empty(),
		"밥통은 어느 시드에서도 두 방향 이상 열려 있다. 위반 %d: %s"
		% [walled.size(), ", ".join(walled.slice(0, 4))])

## Somewhere near the base the bin can stand, asked of the bin's own rule: it is
## a tile across (Grid v2), so one free cell is not enough.
func _bin_spot(sim: Sim) -> Vector2i:
	for ring in range(5, 16):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell: Vector2i = sim.core_cell + Vector2i(dx, dy)
				if sim.food_problems(cell).is_empty():
					return cell
	return sim.core_cell

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TILES_TEST: FAIL - " + message)
		failures += 1

## Machines are bought with materials from an unlocked hotbar, so a test that
## wants to build has to open and fund the base first.
func _open(sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_CRYSTAL)
	sim.note_resource_seen(Defs.ITEM_COPPER)
	sim.power_ever = true
	sim._check_unlocks()
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	# Whatever the table asks for, rather than a purse written out by hand. This
	# loop builds one of everything, so a machine added later has to be payable
	# here -- and the version that named three materials turned every new machine
	# into a failure of this file.
	for type: int in Defs.BUILDABLE:
		for item_id: int in Defs.MACHINE_COSTS[type]:
			sim.note_resource_seen(item_id)
			sim.stock[item_id] = 500
